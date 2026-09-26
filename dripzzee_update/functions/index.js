/**
 * Dripzzee backend (Cloud Functions for Firebase, 2nd gen).
 *
 * Shared by the customer and retailer apps. Everything that touches money or
 * stock happens here, never on a phone:
 *   createOrder      validate cart, price it, reserve stock, open Razorpay order
 *   verifyPayment    check Razorpay signature, mark paid → PLACED
 *   paymentFailed    release stock after a failed/cancelled payment sheet
 *   cancelOrder      customer cancels before the store accepts
 *   onOrderWritten   status history, restock + refund on reject/cancel, FCM
 *   onReturnRequest* return/exchange lifecycle + notifications
 *   onReviewCreated  store rating aggregates
 *   onProductUpdated restock alerts for wishlisted products
 *   cleanupPendingPayments  resolve abandoned online payments every 15 min
 *
 * Requires the Blaze plan. Secrets (set once, see SETUP.md):
 *   firebase functions:secrets:set RAZORPAY_KEY_ID
 *   firebase functions:secrets:set RAZORPAY_KEY_SECRET
 * Use the value "not_configured" for both to run with Cash on Delivery only.
 */

'use strict';

const crypto = require('node:crypto');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const {
  onDocumentWritten,
  onDocumentCreated,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const {
  getFirestore,
  FieldValue,
  FieldPath,
  Timestamp,
} = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();
const db = getFirestore();

// Keep in sync with customer_app/lib/core/config/app_config.dart
const REGION = 'asia-south1';
setGlobalOptions({ region: REGION, maxInstances: 10 });

// Keep in sync with customer_app/lib/core/pricing.dart
const PRICING = {
  platformFee: 5,
  freeDeliveryThreshold: 999,
  defaultDeliveryFee: 49,
  codLimit: 5000,
};
const MAX_LINES = 20;
const MAX_QTY_PER_LINE = 10;
const PENDING_PAYMENT_TTL_MS = 30 * 60 * 1000;

const RAZORPAY_KEY_ID = defineSecret('RAZORPAY_KEY_ID');
const RAZORPAY_KEY_SECRET = defineSecret('RAZORPAY_KEY_SECRET');
const PAYMENT_SECRETS = [RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET];

const CANCELLABLE_BY_CUSTOMER = ['PAYMENT_PENDING', 'PLACED', 'RETAILER_CONFIRMING'];
const RELEASED_STATUSES = ['CANCELLED', 'REJECTED'];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const orders = () => db.collection('orders');
const now = () => FieldValue.serverTimestamp();

function str(v, max = 200) {
  return typeof v === 'string' ? v.trim().slice(0, max) : '';
}

function requireAuth(req) {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Please log in again.');
  return req.auth.uid;
}

function razorpayKeys() {
  let id = '';
  let secret = '';
  try {
    id = (RAZORPAY_KEY_ID.value() || '').trim();
    secret = (RAZORPAY_KEY_SECRET.value() || '').trim();
  } catch (_) {
    // secret not bound to this function
  }
  const configured = id.startsWith('rzp_') && secret.length >= 10;
  return { id, secret, configured };
}

async function razorpay(method, path, body) {
  const { id, secret, configured } = razorpayKeys();
  if (!configured) throw new Error('Razorpay is not configured');
  const res = await fetch(`https://api.razorpay.com/v1${path}`, {
    method,
    headers: {
      Authorization: 'Basic ' + Buffer.from(`${id}:${secret}`).toString('base64'),
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(json?.error?.description || `Razorpay HTTP ${res.status}`);
    err.status = res.status;
    throw err;
  }
  return json;
}

/** Returns the captured payment for a Razorpay order, or null. Throws on API errors. */
async function findCapturedPayment(razorpayOrderId) {
  if (!razorpayOrderId) return null;
  const list = await razorpay('GET', `/orders/${encodeURIComponent(razorpayOrderId)}/payments`);
  const items = Array.isArray(list.items) ? list.items : [];
  return items.find((p) => p.status === 'captured') || null;
}

function validateAddress(a) {
  if (!a || typeof a !== 'object') {
    throw new HttpsError('invalid-argument', 'Add a delivery address.');
  }
  const out = {
    label: str(a.label, 20) || 'Home',
    name: str(a.name, 60),
    phone: str(a.phone, 15).replace(/\D/g, '').slice(-10),
    line1: str(a.line1, 120),
    line2: str(a.line2, 160),
    landmark: str(a.landmark, 80),
    city: str(a.city, 60),
    state: str(a.state, 60),
    pincode: str(a.pincode, 6),
    lat: Number.isFinite(a.lat) ? a.lat : null,
    lng: Number.isFinite(a.lng) ? a.lng : null,
  };
  if (out.name.length < 2) throw new HttpsError('invalid-argument', 'Add the receiver\'s name.');
  if (!/^[6-9]\d{9}$/.test(out.phone)) {
    throw new HttpsError('invalid-argument', 'Add a valid 10-digit mobile number to the address.');
  }
  if (!out.line1 || !out.city) throw new HttpsError('invalid-argument', 'The address is incomplete.');
  if (!/^[1-9]\d{5}$/.test(out.pincode)) {
    throw new HttpsError('invalid-argument', 'The address pincode is invalid.');
  }
  return out;
}

function parseItems(raw) {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new HttpsError('invalid-argument', 'Your cart is empty.');
  }
  if (raw.length > MAX_LINES) {
    throw new HttpsError('invalid-argument', `A single order can have at most ${MAX_LINES} items.`);
  }
  const merged = new Map();
  for (const it of raw) {
    const productId = str(it?.productId, 128);
    const size = str(it?.size, 20);
    const color = str(it?.color, 40) || null;
    const quantity = Number(it?.quantity);
    if (!productId || !size || !Number.isInteger(quantity) || quantity < 1 || quantity > MAX_QTY_PER_LINE) {
      throw new HttpsError('invalid-argument', 'One of the cart items is invalid.');
    }
    const key = `${productId}|${size}|${color || ''}`;
    const prev = merged.get(key);
    merged.set(key, { productId, size, color, quantity: (prev?.quantity || 0) + quantity });
  }
  return [...merged.values()];
}

/** Adds back stock for [items] inside a transaction. Reads first, then writes. */
async function restockInTx(tx, items) {
  const perProduct = new Map();
  for (const it of items || []) {
    if (!it?.productId || !it?.size || !(it.quantity > 0)) continue;
    const sizes = perProduct.get(it.productId) || new Map();
    sizes.set(it.size, (sizes.get(it.size) || 0) + it.quantity);
    perProduct.set(it.productId, sizes);
  }
  if (perProduct.size === 0) return () => {};
  const refs = [...perProduct.keys()].map((id) => db.collection('products').doc(id));
  const snaps = await tx.getAll(...refs);
  // Return a writer so callers can finish all reads before any write.
  return () => {
    snaps.forEach((snap) => {
      if (!snap.exists) return; // product deleted — nothing to restock
      const sizes = perProduct.get(snap.id);
      const args = [];
      for (const [size, qty] of sizes) {
        args.push(new FieldPath('sizes', size), FieldValue.increment(qty));
      }
      args.push('updatedAt', now());
      tx.update(snap.ref, ...args);
    });
  };
}

/**
 * Cancels an order and restores its stock exactly once.
 * [allowedFrom] limits which statuses may be cancelled (null = any non-final).
 */
async function cancelAndRestock(ref, reason, { allowedFrom = null, paymentStatus = null } = {}) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const o = snap.data();
    if (RELEASED_STATUSES.includes(o.status) || o.status === 'DELIVERED') return o.status;
    if (allowedFrom && !allowedFrom.includes(o.status)) return o.status;
    const write = o.stockRestored ? () => {} : await restockInTx(tx, o.items);
    write();
    const updates = {
      status: 'CANCELLED',
      cancelReason: reason,
      stockRestored: true,
      updatedAt: now(),
    };
    if (paymentStatus && o.payment?.status !== 'paid') updates['payment.status'] = paymentStatus;
    tx.update(ref, updates);
    return 'CANCELLED';
  });
}

/** Marks an online order as paid. PAYMENT_PENDING → PLACED. */
async function markPaid(ref, paymentId) {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const o = snap.data();
    if (o.payment?.status === 'paid') return o.status;
    const updates = {
      'payment.status': 'paid',
      'payment.razorpayPaymentId': paymentId,
      'payment.paidAt': now(),
      updatedAt: now(),
    };
    if (o.status === 'PAYMENT_PENDING') updates.status = 'PLACED';
    // If it was cancelled meanwhile, onOrderWritten sees paid + CANCELLED and refunds.
    tx.update(ref, updates);
    return updates.status || o.status;
  });
}

/** Full refund for a paid online order; idempotent via a claim on refundStatus. */
async function refundOrder(ref) {
  const claim = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return null;
    const o = snap.data();
    const p = o.payment || {};
    if (p.method !== 'razorpay' || p.status !== 'paid' || p.refundStatus) return null;
    tx.update(ref, { 'payment.refundStatus': 'processing', updatedAt: now() });
    return { paymentId: p.razorpayPaymentId, amount: Math.round(o.pricing.total * 100), orderId: snap.id };
  });
  if (!claim) return;
  try {
    if (!claim.paymentId) throw new Error('missing payment id');
    const refund = await razorpay('POST', `/payments/${encodeURIComponent(claim.paymentId)}/refund`, {
      amount: claim.amount,
      speed: 'normal',
      notes: { orderId: claim.orderId },
    });
    await ref.update({
      'payment.status': 'refunded',
      'payment.refundStatus': 'initiated',
      'payment.refundId': refund.id || null,
      updatedAt: now(),
    });
  } catch (e) {
    logger.error('Refund failed — needs manual action', { orderId: claim.orderId, error: e.message });
    await ref.update({ 'payment.refundStatus': 'failed', updatedAt: now() });
  }
}

function summary(orderId, o) {
  return { orderId, total: o.pricing?.total ?? 0, status: o.status };
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
  'messaging/invalid-argument',
]);

async function sendToTokens(docRef, tokens, title, body, data) {
  const unique = [...new Set((tokens || []).filter((t) => typeof t === 'string' && t))].slice(0, 500);
  if (unique.length === 0) return;
  const res = await getMessaging().sendEachForMulticast({
    tokens: unique,
    notification: { title, body },
    data: Object.fromEntries(Object.entries(data || {}).map(([k, v]) => [k, String(v)])),
    android: { priority: 'high' },
  });
  const dead = [];
  res.responses.forEach((r, i) => {
    if (!r.success && INVALID_TOKEN_CODES.has(r.error?.code)) dead.push(unique[i]);
  });
  if (dead.length) {
    await docRef.update({ fcmTokens: FieldValue.arrayRemove(...dead) }).catch(() => {});
  }
}

async function notifyUser(uid, title, body, data) {
  if (!uid) return;
  const ref = db.collection('users').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) return;
  await sendToTokens(ref, snap.get('fcmTokens'), title, body, data);
}

async function notifyStore(storeId, title, body, data) {
  if (!storeId) return;
  const ref = db.collection('stores').doc(storeId);
  const snap = await ref.get();
  if (!snap.exists) return;
  await sendToTokens(ref, snap.get('fcmTokens'), title, body, data);
}

function customerMessage(o) {
  const store = o.storeName || 'The store';
  switch (o.status) {
    case 'RETAILER_CONFIRMING':
      return ['Confirming your order', `${store} is checking your items.`];
    case 'ACCEPTED':
      return ['Order accepted', `${store} accepted your order.`];
    case 'PREPARING':
      return ['Being packed', `${store} is packing your order.`];
    case 'READY_FOR_PICKUP':
      return ['Packed and ready', 'Your order is ready for pickup by the rider.'];
    case 'PICKED_UP':
      return ['Picked up', 'Your order has left the store.'];
    case 'OUT_FOR_DELIVERY':
      return ['Out for delivery', 'Your order is on its way — arriving soon.'];
    case 'DELIVERED':
      return ['Delivered', 'Enjoy your new look! Rate your order in the app.'];
    case 'REJECTED':
      return [
        'Order not accepted',
        `${store} couldn't take your order.` +
          (o.payment?.status === 'paid' ? ' Your refund is on its way.' : ''),
      ];
    case 'CANCELLED':
      return ['Order cancelled', o.cancelReason || 'Your order was cancelled.'];
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Callable: createOrder
// ---------------------------------------------------------------------------

exports.createOrder = onCall({ secrets: PAYMENT_SECRETS }, async (req) => {
  const uid = requireAuth(req);
  const d = req.data || {};
  const requestId = str(d.requestId, 80);
  if (!/^[A-Za-z0-9_-]{8,80}$/.test(requestId)) {
    throw new HttpsError('invalid-argument', 'Invalid checkout request.');
  }
  const storeId = str(d.storeId, 128);
  if (!storeId) throw new HttpsError('invalid-argument', 'Missing store.');
  const method = d.paymentMethod === 'cod' ? 'cod' : d.paymentMethod === 'razorpay' ? 'razorpay' : null;
  if (!method) throw new HttpsError('invalid-argument', 'Choose a payment method.');
  const items = parseItems(d.items);
  const address = validateAddress(d.address);
  const couponCode = str(d.couponCode, 40).toUpperCase() || null;
  if (couponCode && !/^[A-Z0-9_-]{2,40}$/.test(couponCode)) {
    throw new HttpsError('invalid-argument', 'That coupon code isn\'t valid.');
  }
  const keys = razorpayKeys();
  if (method === 'razorpay' && !keys.configured) {
    throw new HttpsError(
      'failed-precondition',
      'Online payments aren\'t set up yet. Please choose Cash on delivery.',
    );
  }

  const ref = orders().doc(requestId);

  // Idempotency: a retried request returns the order it already created.
  const existing = await ref.get();
  if (existing.exists) return respondExisting(existing, uid, keys);

  let created = null;
  await db.runTransaction(async (tx) => {
    created = null;
    const again = await tx.get(ref);
    if (again.exists) return;

    const storeSnap = await tx.get(db.collection('stores').doc(storeId));
    if (!storeSnap.exists || storeSnap.get('active') === false) {
      throw new HttpsError('failed-precondition', 'This store isn\'t taking orders right now.');
    }
    const store = storeSnap.data();

    const productIds = [...new Set(items.map((i) => i.productId))];
    const productSnaps = await tx.getAll(...productIds.map((id) => db.collection('products').doc(id)));
    const products = new Map(productSnaps.filter((s) => s.exists).map((s) => [s.id, s.data()]));

    // Coupon (read before any write in this transaction).
    let coupon = null;
    let couponAlreadyUsed = false;
    if (couponCode) {
      const couponSnap = await tx.get(db.collection('coupons').doc(couponCode));
      if (!couponSnap.exists) {
        throw new HttpsError('failed-precondition', 'That coupon code doesn\'t exist.');
      }
      coupon = couponSnap.data();
      if (coupon.oncePerUser) {
        const used = await tx.get(
          orders()
            .where('customerId', '==', uid)
            .where('couponCode', '==', couponCode)
            .limit(5),
        );
        couponAlreadyUsed = used.docs.some((o) => !RELEASED_STATUSES.includes(o.get('status')));
      }
    }

    // Total requested per product+size (colours share a size's stock).
    const requested = new Map();
    for (const it of items) {
      const k = `${it.productId}|${it.size}`;
      requested.set(k, (requested.get(k) || 0) + it.quantity);
    }

    let subtotal = 0;
    const orderItems = [];
    for (const it of items) {
      const p = products.get(it.productId);
      if (!p || p.active === false || p.storeId !== storeId) {
        throw new HttpsError('failed-precondition', `${p?.name || 'An item in your cart'} is no longer available.`);
      }
      const stock = Number((p.sizes || {})[it.size] || 0);
      const want = requested.get(`${it.productId}|${it.size}`);
      if (stock <= 0) {
        throw new HttpsError('failed-precondition', `${p.name} (size ${it.size}) just sold out.`);
      }
      if (stock < want) {
        throw new HttpsError('failed-precondition', `Only ${stock} left of ${p.name} (size ${it.size}).`);
      }
      if (it.color && Array.isArray(p.colors) && p.colors.length && !p.colors.includes(it.color)) {
        throw new HttpsError('invalid-argument', `${p.name} isn't available in ${it.color}.`);
      }
      const unitPrice = Math.round(Number(p.price));
      if (!(unitPrice > 0)) {
        throw new HttpsError('failed-precondition', `${p.name} can't be ordered right now.`);
      }
      subtotal += unitPrice * it.quantity;
      orderItems.push({
        productId: it.productId,
        name: p.name || 'Item',
        imageUrl: (Array.isArray(p.images) && p.images[0]) || null,
        size: it.size,
        color: it.color,
        quantity: it.quantity,
        unitPrice,
      });
    }

    const storeFee = Number.isFinite(store.deliveryFee) ? Math.max(0, Math.round(store.deliveryFee)) : PRICING.defaultDeliveryFee;
    const deliveryFee = subtotal >= PRICING.freeDeliveryThreshold ? 0 : storeFee;
    let discount = 0;
    if (coupon) {
      const expires = coupon.expiresAt instanceof Timestamp ? coupon.expiresAt.toMillis() : null;
      if (coupon.active === false || (expires && expires < Date.now())) {
        throw new HttpsError('failed-precondition', `${couponCode} has expired.`);
      }
      if (coupon.storeId && coupon.storeId !== storeId) {
        throw new HttpsError('failed-precondition', `${couponCode} isn't valid for this store.`);
      }
      if (subtotal < Number(coupon.minOrder || 0)) {
        throw new HttpsError('failed-precondition', `${couponCode} needs a minimum order of ₹${coupon.minOrder}.`);
      }
      if (couponAlreadyUsed) {
        throw new HttpsError('failed-precondition', `You've already used ${couponCode}.`);
      }
      const value = Number(coupon.value || 0);
      let off = coupon.type === 'percent' ? Math.floor((subtotal * value) / 100) : value;
      const cap = Number(coupon.maxDiscount || 0);
      if (coupon.type === 'percent' && cap > 0) off = Math.min(off, cap);
      discount = Math.max(0, Math.min(Math.round(off), subtotal));
    }

    const total = subtotal + deliveryFee + PRICING.platformFee - discount;
    if (method === 'cod' && total > PRICING.codLimit) {
      throw new HttpsError('failed-precondition', `Cash on delivery is available up to ₹${PRICING.codLimit}. Please pay online.`);
    }

    // Reserve stock.
    const perProduct = new Map();
    for (const [k, qty] of requested) {
      const [pid, size] = k.split('|');
      const list = perProduct.get(pid) || [];
      list.push([size, qty]);
      perProduct.set(pid, list);
    }
    for (const [pid, list] of perProduct) {
      const args = [];
      let units = 0;
      for (const [size, qty] of list) {
        args.push(new FieldPath('sizes', size), FieldValue.increment(-qty));
        units += qty;
      }
      args.push('trendingScore', FieldValue.increment(units), 'updatedAt', now());
      tx.update(db.collection('products').doc(pid), ...args);
    }

    const status = method === 'cod' ? 'PLACED' : 'PAYMENT_PENDING';
    created = {
      requestId,
      customerId: uid,
      storeId,
      storeName: store.name || 'Store',
      items: orderItems,
      itemCount: orderItems.reduce((s, i) => s + i.quantity, 0),
      pricing: { subtotal, deliveryFee, platformFee: PRICING.platformFee, discount, total },
      couponCode: coupon ? couponCode : null,
      address,
      payment: { method, status: method === 'cod' ? 'cod_pending' : 'pending' },
      status,
      statusHistory: [{ status, at: Timestamp.now() }],
      returnWindowDays: Number.isInteger(store.returnWindowDays) ? store.returnWindowDays : 7,
      reviewed: false,
      stockRestored: false,
      createdAt: now(),
      updatedAt: now(),
    };
    tx.create(ref, created);
  });

  if (!created) return respondExisting(await ref.get(), uid, keys);

  if (method === 'cod') return summary(requestId, created);

  try {
    const rzpOrder = await razorpay('POST', '/orders', {
      amount: created.pricing.total * 100,
      currency: 'INR',
      receipt: requestId.slice(0, 40),
      notes: { orderId: requestId, customerId: uid },
      payment_capture: 1,
    });
    await ref.update({ 'payment.razorpayOrderId': rzpOrder.id, updatedAt: now() });
    return {
      ...summary(requestId, created),
      razorpay: { keyId: keys.id, orderId: rzpOrder.id, amount: rzpOrder.amount },
    };
  } catch (e) {
    logger.error('Razorpay order creation failed', { orderId: requestId, error: e.message });
    await cancelAndRestock(ref, 'Payment could not be started', { paymentStatus: 'failed' });
    throw new HttpsError('unavailable', 'Couldn\'t start the payment. No money was taken — please try again.');
  }
});

function respondExisting(snap, uid, keys) {
  const o = snap.data();
  if (o.customerId !== uid) throw new HttpsError('permission-denied', 'Invalid checkout request.');
  if (RELEASED_STATUSES.includes(o.status)) {
    throw new HttpsError('failed-precondition', 'That checkout attempt has expired. Please place the order again.');
  }
  const out = summary(snap.id, o);
  if (o.status === 'PAYMENT_PENDING' && o.payment?.razorpayOrderId && keys.configured) {
    out.razorpay = { keyId: keys.id, orderId: o.payment.razorpayOrderId, amount: o.pricing.total * 100 };
  }
  return out;
}

// ---------------------------------------------------------------------------
// Callable: verifyPayment
// ---------------------------------------------------------------------------

exports.verifyPayment = onCall({ secrets: PAYMENT_SECRETS }, async (req) => {
  const uid = requireAuth(req);
  const orderId = str(req.data?.orderId, 80);
  const paymentId = str(req.data?.razorpayPaymentId, 80);
  const rzpOrderId = str(req.data?.razorpayOrderId, 80);
  const signature = str(req.data?.razorpaySignature, 200);
  if (!orderId || !paymentId || !rzpOrderId || !signature) {
    throw new HttpsError('invalid-argument', 'Incomplete payment details.');
  }
  const keys = razorpayKeys();
  if (!keys.configured) throw new HttpsError('failed-precondition', 'Online payments aren\'t set up.');

  const ref = orders().doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
  const o = snap.data();
  if (o.customerId !== uid) throw new HttpsError('permission-denied', 'Not your order.');
  if (o.payment?.razorpayOrderId !== rzpOrderId) {
    throw new HttpsError('permission-denied', 'Payment doesn\'t match this order.');
  }

  const expected = crypto
    .createHmac('sha256', keys.secret)
    .update(`${rzpOrderId}|${paymentId}`)
    .digest('hex');
  const a = Buffer.from(expected, 'utf8');
  const b = Buffer.from(signature, 'utf8');
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    logger.warn('Invalid Razorpay signature', { orderId });
    throw new HttpsError('permission-denied', 'We couldn\'t verify this payment.');
  }

  const status = await markPaid(ref, paymentId);
  return { status };
});

// ---------------------------------------------------------------------------
// Callable: paymentFailed
// ---------------------------------------------------------------------------

exports.paymentFailed = onCall({ secrets: PAYMENT_SECRETS }, async (req) => {
  const uid = requireAuth(req);
  const orderId = str(req.data?.orderId, 80);
  const reason = str(req.data?.reason, 40) === 'cancelled' ? 'Payment cancelled' : 'Payment failed';
  const ref = orders().doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
  const o = snap.data();
  if (o.customerId !== uid) throw new HttpsError('permission-denied', 'Not your order.');
  if (o.status !== 'PAYMENT_PENDING') return { status: o.status };

  // The payment sheet can report failure after money moved (e.g. app killed
  // mid-UPI). Ask Razorpay before releasing stock.
  let captured = null;
  try {
    captured = await findCapturedPayment(o.payment?.razorpayOrderId);
  } catch (e) {
    logger.warn('Razorpay lookup failed; leaving order for cleanup', { orderId, error: e.message });
    return { status: 'PAYMENT_PENDING' };
  }
  if (captured) return { status: await markPaid(ref, captured.id) };
  const status = await cancelAndRestock(ref, reason, {
    allowedFrom: ['PAYMENT_PENDING'],
    paymentStatus: 'failed',
  });
  return { status };
});

// ---------------------------------------------------------------------------
// Callable: cancelOrder (customer)
// ---------------------------------------------------------------------------

exports.cancelOrder = onCall(async (req) => {
  const uid = requireAuth(req);
  const orderId = str(req.data?.orderId, 80);
  const reason = str(req.data?.reason, 200) || 'Cancelled by customer';
  const ref = orders().doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError('not-found', 'Order not found.');
  if (snap.get('customerId') !== uid) throw new HttpsError('permission-denied', 'Not your order.');
  if (!CANCELLABLE_BY_CUSTOMER.includes(snap.get('status'))) {
    throw new HttpsError('failed-precondition', 'The store has already accepted this order, so it can\'t be cancelled.');
  }
  const status = await cancelAndRestock(ref, reason, { allowedFrom: CANCELLABLE_BY_CUSTOMER });
  if (status !== 'CANCELLED') {
    throw new HttpsError('failed-precondition', 'The store has already accepted this order, so it can\'t be cancelled.');
  }
  // Refund (if paid) is handled by onOrderWritten.
  return { status };
});

// ---------------------------------------------------------------------------
// Trigger: order lifecycle
// ---------------------------------------------------------------------------

exports.onOrderWritten = onDocumentWritten(
  { document: 'orders/{orderId}', secrets: PAYMENT_SECRETS },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after) return;
    const ref = event.data.after.ref;
    const orderId = event.params.orderId;
    const statusChanged = !before || before.status !== after.status;

    // 1. History + delivery bookkeeping (skip the create; createOrder wrote it).
    if (before && statusChanged) {
      const updates = {
        statusHistory: FieldValue.arrayUnion({ status: after.status, at: Timestamp.now() }),
        updatedAt: now(),
      };
      if (after.status === 'DELIVERED' && !after.deliveredAt) {
        updates.deliveredAt = now();
        if (after.payment?.method === 'cod' && after.payment?.status === 'cod_pending') {
          updates['payment.status'] = 'paid';
        }
      }
      await ref.update(updates);
    }

    // 2. Store rejected / order cancelled: give stock back exactly once.
    if (RELEASED_STATUSES.includes(after.status) && !after.stockRestored) {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists || snap.get('stockRestored')) return;
        const write = await restockInTx(tx, snap.get('items'));
        write();
        tx.update(ref, { stockRestored: true, updatedAt: now() });
      });
    }

    // 3. Refund paid online orders that won't be fulfilled.
    if (
      RELEASED_STATUSES.includes(after.status) &&
      after.payment?.method === 'razorpay' &&
      after.payment?.status === 'paid' &&
      !after.payment?.refundStatus
    ) {
      await refundOrder(ref);
    }

    if (!statusChanged) return;

    // 4. Notifications.
    try {
      if (after.status === 'PLACED') {
        await notifyStore(
          after.storeId,
          'New order',
          `${after.itemCount || after.items?.length || 1} item(s) · ₹${after.pricing?.total ?? ''} · ${after.payment?.method === 'cod' ? 'Cash on delivery' : 'Paid online'}`,
          { type: 'order', orderId },
        );
        return;
      }
      if (!before || before.status === 'PAYMENT_PENDING' || after.status === 'RETURN_REQUESTED') return;
      if (after.status === 'CANCELLED') {
        await notifyStore(after.storeId, 'Order cancelled', `Order ${orderId.slice(-6).toUpperCase()} was cancelled.`, {
          type: 'order',
          orderId,
        });
      }
      const msg = customerMessage(after);
      if (msg) await notifyUser(after.customerId, msg[0], msg[1], { type: 'order', orderId });
    } catch (e) {
      logger.error('Order notification failed', { orderId, error: e.message });
    }
  },
);

// ---------------------------------------------------------------------------
// Triggers: returns & exchanges
// ---------------------------------------------------------------------------

exports.onReturnRequestCreated = onDocumentCreated('return_requests/{orderId}', async (event) => {
  const r = event.data?.data();
  if (!r) return;
  const orderRef = orders().doc(event.params.orderId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(orderRef);
    if (snap.exists && snap.get('status') === 'DELIVERED') {
      tx.update(orderRef, { status: 'RETURN_REQUESTED', returnType: r.type || 'RETURN', updatedAt: now() });
    }
  });
  try {
    await notifyStore(
      r.storeId,
      r.type === 'EXCHANGE' ? 'Exchange requested' : 'Return requested',
      `${(r.items || []).length} item(s) · ${r.reason || ''}`,
      { type: 'return', orderId: event.params.orderId },
    );
  } catch (e) {
    logger.error('Return notification failed', { error: e.message });
  }
});

exports.onReturnRequestUpdated = onDocumentUpdated(
  { document: 'return_requests/{orderId}', secrets: PAYMENT_SECRETS },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after || before.status === after.status) return;
    const orderId = event.params.orderId;
    const kind = after.type === 'EXCHANGE' ? 'exchange' : 'return';

    // Completed returns of online orders: refund the returned items once.
    if (after.status === 'COMPLETED' && after.type !== 'EXCHANGE' && !after.refundStatus) {
      const orderSnap = await orders().doc(orderId).get();
      const o = orderSnap.data() || {};
      const refundPaise = (after.items || []).reduce((sum, it) => {
        const line = (o.items || []).find((x) => x.productId === it.productId && x.size === it.size);
        return sum + (line ? line.unitPrice * Math.min(it.quantity, line.quantity) * 100 : 0);
      }, 0);
      let refundStatus = 'manual';
      if (o.payment?.method === 'razorpay' && o.payment?.razorpayPaymentId && refundPaise > 0) {
        try {
          await razorpay('POST', `/payments/${encodeURIComponent(o.payment.razorpayPaymentId)}/refund`, {
            amount: refundPaise,
            speed: 'normal',
            notes: { orderId, reason: 'return' },
          });
          refundStatus = 'initiated';
        } catch (e) {
          logger.error('Return refund failed — needs manual action', { orderId, error: e.message });
          refundStatus = 'failed';
        }
      }
      await event.data.after.ref.update({ refundStatus, refundAmount: refundPaise / 100, updatedAt: now() });
    }

    const messages = {
      APPROVED: [`${kind === 'exchange' ? 'Exchange' : 'Return'} approved`, `${after.storeName || 'The store'} approved your ${kind}. They'll arrange the pickup.`],
      REJECTED: [`${kind === 'exchange' ? 'Exchange' : 'Return'} declined`, after.resolutionNote || `${after.storeName || 'The store'} declined your ${kind} request.`],
      COMPLETED: [`${kind === 'exchange' ? 'Exchange' : 'Return'} completed`, kind === 'exchange' ? 'Your exchange is complete.' : 'Your return is complete. Refunds reach your account in 5–7 business days.'],
    };
    const msg = messages[after.status];
    if (msg) {
      try {
        await notifyUser(after.customerId, msg[0], msg[1], { type: 'return', orderId });
      } catch (e) {
        logger.error('Return update notification failed', { error: e.message });
      }
    }
  },
);

// ---------------------------------------------------------------------------
// Trigger: reviews → store rating
// ---------------------------------------------------------------------------

exports.onReviewCreated = onDocumentCreated('reviews/{orderId}', async (event) => {
  const r = event.data?.data();
  if (!r || !r.storeId) return;
  const rating = Number(r.rating);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) return;
  const storeRef = db.collection('stores').doc(r.storeId);
  const orderRef = orders().doc(event.params.orderId);
  await db.runTransaction(async (tx) => {
    const store = await tx.get(storeRef);
    if (!store.exists) return;
    const sum = Number(store.get('ratingSum') || 0) + rating;
    const count = Number(store.get('ratingCount') || 0) + 1;
    tx.update(storeRef, {
      ratingSum: sum,
      ratingCount: count,
      rating: Math.round((sum / count) * 10) / 10,
    });
    tx.update(orderRef, { reviewed: true });
  });
});

// ---------------------------------------------------------------------------
// Trigger: restock alerts for wishlisted products
// ---------------------------------------------------------------------------

exports.onProductUpdated = onDocumentUpdated('products/{productId}', async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  if (after.active === false) return;
  const beforeSizes = before.sizes || {};
  const afterSizes = after.sizes || {};
  const restocked = Object.keys(afterSizes).filter(
    (s) => Number(afterSizes[s]) > 0 && !(Number(beforeSizes[s]) > 0),
  );
  if (restocked.length === 0) return;
  const wasSoldOut = Object.values(beforeSizes).every((q) => !(Number(q) > 0));

  const saved = await db
    .collectionGroup('wishlist')
    .where('productId', '==', event.params.productId)
    .limit(500)
    .get();
  const uids = [...new Set(saved.docs.map((d) => d.ref.parent.parent?.id).filter(Boolean))];
  const title = wasSoldOut ? 'Back in stock' : 'Your size is back';
  const body = `${after.name || 'An item you saved'} · size ${restocked.join(', ')} at ${after.storeName || 'a store near you'}`;
  await Promise.allSettled(
    uids.map((uid) => notifyUser(uid, title, body, { type: 'product', productId: event.params.productId })),
  );
});

// ---------------------------------------------------------------------------
// Scheduled: resolve abandoned online payments
// ---------------------------------------------------------------------------

exports.cleanupPendingPayments = onSchedule(
  { schedule: 'every 15 minutes', timeZone: 'Asia/Kolkata', secrets: PAYMENT_SECRETS },
  async () => {
    const snap = await orders().where('status', '==', 'PAYMENT_PENDING').limit(200).get();
    const cutoff = Date.now() - PENDING_PAYMENT_TTL_MS;
    for (const doc of snap.docs) {
      const created = doc.get('createdAt');
      const createdMs = created instanceof Timestamp ? created.toMillis() : 0;
      if (createdMs > cutoff) continue;
      try {
        let captured = null;
        try {
          captured = await findCapturedPayment(doc.get('payment.razorpayOrderId'));
        } catch (e) {
          // Keep waiting unless it's very old.
          if (createdMs > Date.now() - 24 * 60 * 60 * 1000) continue;
        }
        if (captured) {
          await markPaid(doc.ref, captured.id);
        } else {
          await cancelAndRestock(doc.ref, 'Payment not completed', {
            allowedFrom: ['PAYMENT_PENDING'],
            paymentStatus: 'failed',
          });
        }
      } catch (e) {
        logger.error('Pending payment cleanup failed', { orderId: doc.id, error: e.message });
      }
    }
  },
);
