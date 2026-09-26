#!/usr/bin/env node
/**
 * Seeds demo stores + products around a location so the customer app has
 * real Firestore data to show (home, search, campaign edits, checkout).
 *
 *   cd seed && npm install
 *   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
 *   node seed.js --lat <your latitude> --lng <your longitude>
 *   node seed.js --lat ... --lng ... --reset   # remove previous demo data first
 *   node seed.js --reset-only                   # just remove demo data
 *   node seed.js --coupons-only                 # just add/refresh demo coupons
 *
 * Everything written here has `seeded: true`, so it's easy to remove before
 * real retailers go live. Images are left empty — the app draws a designed
 * placeholder — until retailers upload photos.
 */

'use strict';

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}
const has = (name) => process.argv.includes(`--${name}`);

const resetOnly = has('reset-only');
const couponsOnly = has('coupons-only');
const lat = Number(arg('lat'));
const lng = Number(arg('lng'));
if (!resetOnly && !couponsOnly && (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180)) {
  console.error('Usage: node seed.js --lat <latitude> --lng <longitude> [--reset]');
  console.error('Tip: long-press your location in Google Maps to copy its coordinates.');
  process.exit(1);
}
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('Set GOOGLE_APPLICATION_CREDENTIALS to your service-account JSON (see SETUP.md).');
  process.exit(1);
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

/** Offset a point by dx (east) / dy (north) kilometres. */
function offset(dxKm, dyKm) {
  return {
    lat: +(lat + dyKm / 111).toFixed(6),
    lng: +(lng + dxKm / (111 * Math.cos((lat * Math.PI) / 180))).toFixed(6),
  };
}

const daysAgo = (n) => Timestamp.fromDate(new Date(Date.now() - n * 86400000));

const RETURN_7 = 'Returns and size exchanges within 7 days of delivery. Items must be unused with original tags.';
const RETURN_3 = 'Size exchanges within 3 days of delivery for unworn items with tags. No refunds on sale items.';

const STORES = [
  {
    key: 'kesariya',
    name: 'Kesariya Ethnic House',
    description: 'Handpicked chaniya cholis, kediyus and festive jewellery with mirror and gota work.',
    categories: ['ethnic', 'women', 'accessories'],
    tags: ['festive', 'navratri'],
    at: [1.2, 0.8], fee: 39, eta: [30, 50], rating: [4.6, 38], returns: RETURN_7, window: 7,
  },
  {
    key: 'rangmahal',
    name: 'Rang Mahal Boutique',
    description: 'Bandhani, leheriya and Kutch embroidery straight from artisan clusters.',
    categories: ['ethnic', 'women'],
    tags: ['festive', 'handloom'],
    at: [-2.1, 1.6], fee: 49, eta: [35, 55], rating: [4.4, 22], returns: RETURN_7, window: 7,
  },
  {
    key: 'urbanthread',
    name: 'Urban Thread Co.',
    description: 'Oversized tees, cargos and everyday streetwear drops every Friday.',
    categories: ['streetwear', 'men', 'women'],
    tags: ['new'],
    at: [0.6, -1.4], fee: 29, eta: [25, 40], rating: [4.3, 51], returns: RETURN_7, window: 7,
  },
  {
    key: 'solestory',
    name: 'Sole Story Sneakers',
    description: 'Clean everyday sneakers, runners and festive juttis.',
    categories: ['sneakers', 'accessories'],
    tags: ['festive'],
    at: [3.4, -0.5], fee: 49, eta: [35, 60], rating: [4.5, 64], returns: RETURN_3, window: 3,
  },
  {
    key: 'gentsgallery',
    name: 'The Gents Gallery',
    description: 'Kurta sets, Nehru jackets and smart-casual shirts for men.',
    categories: ['men', 'ethnic'],
    tags: ['festive'],
    at: [-1.0, -2.6], fee: 39, eta: [30, 50], rating: [4.2, 17], returns: RETURN_7, window: 7,
  },
  {
    key: 'looplabel',
    name: 'Loop Label',
    description: 'Minimal womenswear: co-ords, linen shirts and easy dresses.',
    categories: ['women'],
    tags: [],
    at: [4.8, 2.9], fee: 49, eta: [40, 65], rating: [4.1, 12], returns: RETURN_7, window: 7,
  },
  {
    key: 'chandbali',
    name: 'Chandbali Accessories',
    description: 'Oxidised silver, jhumkas, potli bags and dandiya sticks.',
    categories: ['accessories'],
    tags: ['festive', 'navratri'],
    at: [-3.8, -1.2], fee: 29, eta: [25, 45], rating: [4.7, 29], returns: RETURN_3, window: 3,
  },
  {
    key: 'denimdock',
    name: 'Denim Dock',
    description: 'Jeans, jackets and denim co-ords in every fit.',
    categories: ['men', 'women', 'streetwear'],
    tags: [],
    at: [6.5, -4.0], fee: 59, eta: [45, 70], rating: [0, 0], returns: RETURN_7, window: 7,
  },
];

const S = (xs, qty) => Object.fromEntries(xs.map((s, i) => [s, Array.isArray(qty) ? qty[i] : qty]));
const APPAREL = ['S', 'M', 'L', 'XL'];
const SHOES = ['6', '7', '8', '9', '10'];

// [storeKey, name, brand, category, price, mrp, colors, sizes, tags, description, ageDays]
const PRODUCTS = [
  // Kesariya — Navratri core
  ['kesariya', 'Mirror-work Chaniya Choli', 'Kesariya', 'ethnic', 3499, 4299, ['Marigold', 'Red'], S(APPAREL, [3, 5, 4, 2]), ['navratri', 'garba', 'festive', 'chaniya choli', 'lehenga'], 'Flared 8-kali skirt with hand-set mirrors, padded choli and a contrast dupatta. Built to twirl.', 4],
  ['kesariya', 'Gota-patti Chaniya Choli', 'Kesariya', 'ethnic', 4199, 4999, ['Purple', 'Peacock Green'], S(APPAREL, [2, 3, 3, 1]), ['navratri', 'garba', 'festive', 'chaniya choli'], 'Cotton-silk chaniya with gota-patti borders and tassel tie-ups.', 6],
  ['kesariya', 'Kutch-work Lehenga Set', 'Kesariya', 'ethnic', 5299, 6499, ['Peacock Green', 'Red'], S(APPAREL, [1, 2, 2, 1]), ['navratri', 'garba', 'festive', 'lehenga'], 'Kutch embroidery and shell detailing on a lightweight flared lehenga.', 9],
  ['kesariya', 'Mirror-work Dupatta', 'Kesariya', 'accessories', 899, 1199, ['Marigold', 'Royal Blue', 'Green'], S(['FREE SIZE'], 12), ['navratri', 'garba', 'festive', 'dupatta'], 'Cotton dupatta with mirror borders and pom-pom edges.', 3],
  ['kesariya', 'Kids Chaniya Choli', 'Kesariya', 'ethnic', 1499, 1899, ['Yellow', 'Red'], S(['2-3Y', '4-5Y', '6-7Y'], [3, 4, 2]), ['navratri', 'garba', 'festive', 'kids'], 'Soft cotton chaniya choli with elastic waist for little dancers.', 12],
  ['kesariya', 'Oxidised Kamarbandh', 'Kesariya', 'accessories', 799, null, ['Grey'], S(['FREE SIZE'], 10), ['navratri', 'garba', 'festive', 'jewellery'], 'Adjustable oxidised waist chain with ghungroo drops.', 20],

  // Rang Mahal — handloom festive
  ['rangmahal', 'Bandhani Lehenga', 'Rang Mahal', 'ethnic', 4899, 5999, ['Red', 'Yellow'], S(APPAREL, [2, 3, 2, 1]), ['navratri', 'garba', 'festive', 'lehenga', 'bandhani'], 'Hand-tied bandhani on modal silk with zari border.', 5],
  ['rangmahal', 'Leheriya Dupatta', 'Rang Mahal', 'accessories', 1099, 1399, ['Green', 'Marigold'], S(['FREE SIZE'], 9), ['navratri', 'festive', 'dupatta', 'leheriya'], 'Wave-dyed leheriya dupatta in soft chiffon.', 8],
  ['rangmahal', 'Chikankari Kurta', 'Rang Mahal', 'women', 1899, 2299, ['Ivory', 'Grey'], S(APPAREL, [4, 5, 3, 2]), ['navratri', 'festive', 'kurta', 'chikankari'], 'Hand-embroidered chikankari on breathable cotton.', 15],
  ['rangmahal', 'Silk Kediyu Top', 'Rang Mahal', 'ethnic', 1799, null, ['Royal Blue', 'Purple'], S(APPAREL, [2, 3, 3, 0]), ['navratri', 'garba', 'festive', 'kediyu'], 'Frilled kediyu top in art silk with embroidered yoke.', 10],
  ['rangmahal', 'Ajrakh Print Saree', 'Rang Mahal', 'women', 2999, 3499, ['Royal Blue', 'Red'], S(['FREE SIZE'], 4), ['festive', 'saree', 'handloom'], 'Block-printed Ajrakh on mul cotton with blouse piece.', 30],
  ['rangmahal', 'Patola Print Kurta Set', 'Rang Mahal', 'women', 2499, 2999, ['Purple', 'Yellow'], S(APPAREL, [2, 2, 2, 2]), ['navratri', 'festive', 'kurta set'], 'Straight kurta with palazzo and dupatta in patola print.', 7],

  // Urban Thread — streetwear
  ['urbanthread', 'Oversized Graphic Tee', 'Urban Thread', 'streetwear', 799, 999, ['Black', 'White'], S(APPAREL, [8, 10, 9, 6]), ['oversized', 'tee', 'graphic'], '240 GSM cotton, drop shoulders, puff-print back graphic.', 2],
  ['urbanthread', 'Relaxed Cargo Pants', 'Urban Thread', 'streetwear', 1499, 1899, ['Olive', 'Black', 'Beige'], S(['28', '30', '32', '34'], [4, 6, 5, 3]), ['cargo', 'pants', 'utility'], 'Six-pocket relaxed cargos with adjustable hems.', 6],
  ['urbanthread', 'Heavyweight Hoodie', 'Urban Thread', 'streetwear', 1799, 2199, ['Grey', 'Black'], S(APPAREL, [3, 4, 4, 2]), ['hoodie', 'winter'], 'Brushed fleece hoodie with kangaroo pocket.', 18],
  ['urbanthread', 'Varsity Bomber Jacket', 'Urban Thread', 'streetwear', 2799, 3299, ['Navy', 'Maroon'], S(APPAREL, [2, 3, 2, 1]), ['jacket', 'bomber'], 'Wool-blend varsity bomber with chenille patches.', 25],
  ['urbanthread', 'Boxy Striped Shirt', 'Urban Thread', 'men', 1199, null, ['Blue', 'White'], S(APPAREL, [3, 5, 4, 2]), ['shirt', 'casual'], 'Boxy fit cotton shirt with camp collar.', 11],
  ['urbanthread', 'Ribbed Crop Top', 'Urban Thread', 'women', 599, 799, ['Black', 'Lavender', 'White'], S(['XS', 'S', 'M', 'L'], [5, 6, 6, 3]), ['crop top', 'basics'], 'Stretch rib-knit crop with square neck.', 4],

  // Sole Story — footwear
  ['solestory', 'Classic White Sneakers', 'Sole Story', 'sneakers', 2499, 2999, ['White'], S(SHOES, [3, 5, 6, 4, 2]), ['sneakers', 'white sneakers', 'everyday'], 'Leather-look low-tops with cushioned insole.', 14],
  ['solestory', 'Retro Runner', 'Sole Story', 'sneakers', 3299, 3999, ['Grey', 'Navy'], S(SHOES, [2, 3, 4, 3, 1]), ['sneakers', 'running'], 'Suede-panel retro runner with EVA midsole.', 8],
  ['solestory', 'Embroidered Jutti', 'Sole Story', 'accessories', 1299, 1599, ['Gold', 'Red'], S(['5', '6', '7', '8'], [3, 4, 3, 2]), ['navratri', 'garba', 'festive', 'jutti', 'footwear'], 'Cushioned juttis with zari embroidery — comfy for all-night garba.', 5],
  ['solestory', 'Chunky Platform Sneakers', 'Sole Story', 'sneakers', 2899, null, ['Black', 'White'], S(SHOES, [0, 2, 3, 2, 0]), ['sneakers', 'platform'], 'Chunky sole sneakers with padded collar.', 3],
  ['solestory', 'Kolhapuri Flats', 'Sole Story', 'accessories', 999, 1299, ['Beige', 'Brown'], S(['5', '6', '7', '8', '9'], [3, 3, 4, 2, 2]), ['festive', 'kolhapuri', 'footwear'], 'Hand-stitched leather kolhapuris.', 20],

  // Gents Gallery — men's ethnic
  ['gentsgallery', 'Kediyu & Dhoti Set', 'Gents Gallery', 'men', 2299, 2799, ['Marigold', 'Ivory'], S(APPAREL, [3, 4, 4, 2]), ['navratri', 'garba', 'festive', 'kediyu', 'men'], 'Traditional frilled kediyu with dhoti pants, mirror-work yoke.', 4],
  ['gentsgallery', 'Silk Kurta Pyjama', 'Gents Gallery', 'men', 2699, 3199, ['Royal Blue', 'Maroon'], S(APPAREL, [2, 4, 3, 2]), ['navratri', 'festive', 'kurta'], 'Art-silk kurta with churidar pyjama.', 9],
  ['gentsgallery', 'Printed Nehru Jacket', 'Gents Gallery', 'men', 1899, 2299, ['Peacock Green', 'Navy'], S(APPAREL, [2, 3, 3, 1]), ['navratri', 'festive', 'nehru jacket'], 'Block-printed Nehru jacket to layer over any kurta.', 6],
  ['gentsgallery', 'Linen Short Kurta', 'Gents Gallery', 'men', 1299, null, ['White', 'Beige'], S(APPAREL, [4, 5, 5, 3]), ['kurta', 'linen'], 'Breathable linen short kurta with mandarin collar.', 16],
  ['gentsgallery', 'Bandhgala Blazer', 'Gents Gallery', 'men', 4999, 5999, ['Black', 'Navy'], S(['38', '40', '42', '44'], [1, 2, 2, 1]), ['festive', 'blazer', 'wedding'], 'Structured bandhgala with brass buttons.', 28],
  ['gentsgallery', 'Dhoti Pants', 'Gents Gallery', 'men', 899, 1099, ['Ivory', 'Grey'], S(APPAREL, [4, 4, 4, 2]), ['navratri', 'garba', 'festive', 'dhoti'], 'Ready-to-wear dhoti pants with elastic waist.', 12],

  // Loop Label — womenswear
  ['looplabel', 'Linen Co-ord Set', 'Loop Label', 'women', 2799, 3299, ['Beige', 'Olive'], S(['XS', 'S', 'M', 'L'], [2, 3, 3, 2]), ['co-ord', 'linen'], 'Relaxed shirt and wide-leg trousers in washed linen.', 5],
  ['looplabel', 'Satin Slip Dress', 'Loop Label', 'women', 1999, 2499, ['Purple', 'Black'], S(['XS', 'S', 'M', 'L'], [1, 3, 2, 1]), ['dress', 'party'], 'Bias-cut satin slip dress with adjustable straps.', 10],
  ['looplabel', 'Oversized Poplin Shirt', 'Loop Label', 'women', 1399, null, ['White', 'Blue'], S(['XS', 'S', 'M', 'L'], [3, 4, 4, 2]), ['shirt', 'basics'], 'Crisp cotton poplin in an oversized cut.', 19],
  ['looplabel', 'Tiered Midi Skirt', 'Loop Label', 'women', 1599, 1899, ['Marigold', 'Green'], S(['XS', 'S', 'M', 'L'], [2, 3, 3, 1]), ['skirt', 'festive'], 'Tiered cotton midi — pairs with a kediyu for indo-western garba.', 7],
  ['looplabel', 'Knit Cardigan', 'Loop Label', 'women', 1699, 1999, ['Lavender', 'Cream'], S(['S', 'M', 'L'], [2, 2, 2]), ['cardigan', 'winter'], 'Soft chunky-knit cardigan with pearl buttons.', 35],

  // Chandbali — accessories
  ['chandbali', 'Oxidised Jhumkas', 'Chandbali', 'accessories', 499, 699, ['Grey'], S(['FREE SIZE'], 20), ['navratri', 'garba', 'festive', 'jhumka', 'jewellery', 'earrings'], 'Lightweight oxidised jhumkas with ghungroo drops.', 3],
  ['chandbali', 'Painted Dandiya Sticks (Pair)', 'Chandbali', 'accessories', 349, null, ['Multicolour'], S(['FREE SIZE'], 25), ['navratri', 'garba', 'festive', 'dandiya'], 'Hand-painted wooden dandiya sticks with ghungroo.', 2],
  ['chandbali', 'Mirror-work Potli Bag', 'Chandbali', 'accessories', 699, 899, ['Red', 'Marigold', 'Royal Blue'], S(['FREE SIZE'], 12), ['navratri', 'festive', 'potli', 'bag'], 'Drawstring potli with mirror and bead work.', 6],
  ['chandbali', 'Oxidised Choker Set', 'Chandbali', 'accessories', 1199, 1499, ['Grey'], S(['FREE SIZE'], 7), ['navratri', 'garba', 'festive', 'jewellery', 'necklace'], 'Statement choker with matching studs.', 9],
  ['chandbali', 'Maang Tikka', 'Chandbali', 'accessories', 399, null, ['Gold', 'Grey'], S(['FREE SIZE'], 15), ['navratri', 'festive', 'jewellery'], 'Kundan-look maang tikka with adjustable chain.', 14],
  ['chandbali', 'Anklet Pair (Payal)', 'Chandbali', 'accessories', 599, 799, ['Silver'], S(['FREE SIZE'], 0), ['navratri', 'garba', 'festive', 'jewellery', 'anklet'], 'Oxidised payal with ghungroo — sold out, restocking soon.', 11],

  // Denim Dock — denim
  ['denimdock', 'Straight Fit Jeans', 'Denim Dock', 'men', 1999, 2499, ['Denim', 'Black'], S(['30', '32', '34', '36'], [4, 6, 5, 3]), ['jeans', 'denim'], 'Rigid-look stretch denim in a classic straight fit.', 13],
  ['denimdock', 'Wide Leg Jeans', 'Denim Dock', 'women', 2199, 2599, ['Denim', 'Blue'], S(['26', '28', '30', '32'], [3, 4, 4, 2]), ['jeans', 'wide leg', 'denim'], 'High-rise wide-leg jeans with a clean hem.', 4],
  ['denimdock', 'Denim Trucker Jacket', 'Denim Dock', 'streetwear', 2799, 3299, ['Denim'], S(APPAREL, [2, 3, 3, 1]), ['jacket', 'denim'], 'Classic trucker jacket with button flaps.', 22],
  ['denimdock', 'Denim Shirt', 'Denim Dock', 'men', 1599, null, ['Blue'], S(APPAREL, [3, 4, 3, 2]), ['shirt', 'denim'], 'Soft chambray-weight denim shirt.', 26],
  ['denimdock', 'Denim Co-ord Set', 'Denim Dock', 'women', 2999, 3599, ['Denim', 'Black'], S(['XS', 'S', 'M', 'L'], [1, 2, 2, 1]), ['co-ord', 'denim'], 'Cropped jacket with matching straight jeans.', 2],
];

async function deleteSeeded(collection) {
  let removed = 0;
  for (;;) {
    const snap = await db.collection(collection).where('seeded', '==', true).limit(400).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    removed += snap.size;
  }
  return removed;
}

const COUPONS = {
  WELCOME100: {
    type: 'flat', value: 100, minOrder: 799, maxDiscount: 0, oncePerUser: true,
    description: '₹100 off your first order over ₹799',
  },
  NAVRATRI15: {
    type: 'percent', value: 15, minOrder: 1499, maxDiscount: 300, oncePerUser: false,
    description: '15% off festive shopping, up to ₹300',
    expiresAt: Timestamp.fromDate(new Date('2026-10-26T23:59:59+05:30')),
  },
  DRIP50: {
    type: 'flat', value: 50, minOrder: 499, maxDiscount: 0, oncePerUser: false,
    description: '₹50 off orders over ₹499',
  },
};

async function seedCoupons() {
  const batch = db.batch();
  for (const [code, c] of Object.entries(COUPONS)) {
    batch.set(db.collection('coupons').doc(code), {
      ...c,
      active: true,
      seeded: true,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();
  console.log(`Coupons ready: ${Object.keys(COUPONS).join(', ')}`);
}

async function main() {
  if (couponsOnly) {
    await seedCoupons();
    return;
  }
  if (has('reset') || resetOnly) {
    const p = await deleteSeeded('products');
    const s = await deleteSeeded('stores');
    const c = await deleteSeeded('coupons');
    console.log(`Removed ${s} demo stores, ${p} demo products and ${c} coupons.`);
    if (resetOnly) return;
  }

  const storeIds = {};
  const storeNames = {};
  let batch = db.batch();
  for (const s of STORES) {
    const ref = db.collection('stores').doc(`demo_${s.key}`);
    const pos = offset(s.at[0], s.at[1]);
    const [rating, count] = s.rating;
    storeIds[s.key] = ref.id;
    storeNames[s.key] = s.name;
    batch.set(ref, {
      name: s.name,
      description: s.description,
      imageUrl: '',
      address: `Demo location · ${Math.hypot(s.at[0], s.at[1]).toFixed(1)} km from your pin`,
      categories: s.categories,
      tags: s.tags,
      lat: pos.lat,
      lng: pos.lng,
      deliveryFee: s.fee,
      minDeliveryMinutes: s.eta[0],
      maxDeliveryMinutes: s.eta[1],
      pickupAvailable: true,
      returnPolicy: s.returns,
      returnWindowDays: s.window,
      rating,
      ratingCount: count,
      ratingSum: Math.round(rating * count),
      active: true,
      fcmTokens: [],
      seeded: true,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  batch = db.batch();
  let n = 0;
  for (const [storeKey, name, brand, category, price, mrp, colors, sizes, tags, description, age] of PRODUCTS) {
    const ref = db.collection('products').doc();
    batch.set(ref, {
      storeId: storeIds[storeKey],
      storeName: storeNames[storeKey],
      name,
      brand,
      category,
      price,
      mrp: mrp ?? null,
      colors,
      sizes,
      tags,
      description,
      images: [],
      active: true,
      trendingScore: Math.round(Math.random() * 60) + (tags.includes('navratri') ? 40 : 0),
      seeded: true,
      createdAt: daysAgo(age),
      updatedAt: FieldValue.serverTimestamp(),
    });
    n += 1;
  }
  await batch.commit();

  await seedCoupons();

  const festive = STORES.filter((s) => s.tags.includes('festive')).length;
  console.log(`Seeded ${STORES.length} stores (${festive} festive) and ${n} products around ${lat}, ${lng}.`);
  console.log('Open the app, set your location near that point, and pull to refresh.');
}

main().then(
  () => process.exit(0),
  (e) => {
    console.error('Seeding failed:', e.message);
    process.exit(1);
  },
);
