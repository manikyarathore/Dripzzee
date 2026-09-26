'use strict';
// Free AI product photos via Pollinations.ai (no key). Prompt = name + colours + description.
//   node ai_images.js          generate + attach
//   node ai_images.js --clear  remove images
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
initializeApp({ credential: applicationDefault() });
const db = getFirestore();
const clear = process.argv.includes('--clear');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const url = (prompt, seed, w, h) =>
  `https://image.pollinations.ai/prompt/${encodeURIComponent(prompt)}` +
  `?width=${w}&height=${h}&seed=${seed}&model=flux&nologo=true`;

async function warm(link, label) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const res = await fetch(link, { signal: AbortSignal.timeout(120000) });
      if (res.ok) { await res.arrayBuffer(); console.log('  ✓', label); return; }
      console.log(`  … ${label}: HTTP ${res.status}, retrying`);
    } catch (e) { console.log(`  … ${label}: ${e.message}, retrying`); }
    await sleep(8000 * attempt);
  }
  console.log('  ✗', label, '(will generate when first opened in the app)');
}

(async () => {
  const products = await db.collection('products').where('seeded', '==', true).get();
  const stores = await db.collection('stores').where('seeded', '==', true).get();
  if (clear) {
    const b = db.batch();
    products.docs.forEach((d) => b.update(d.ref, { images: [] }));
    stores.docs.forEach((d) => b.update(d.ref, { imageUrl: '' }));
    await b.commit();
    console.log('Cleared images.'); process.exit(0);
  }
  let seed = 101;
  for (const d of products.docs) {
    const p = d.data();
    const colours = (p.colors || []).join(' and ');
    const prompt = `Professional e-commerce product photo of ${p.name}` +
      (colours ? `, ${colours} colour` : '') +
      `, ${(p.description || '').slice(0, 160)}, Indian fashion, full item visible, ` +
      'plain light grey studio background, soft lighting, sharp detail, no text';
    const link = url(prompt, seed++, 600, 800);
    await d.ref.update({ images: [link] });
    await warm(link, p.name);
  }
  for (const d of stores.docs) {
    const s = d.data();
    const link = url(`Interior of a modern Indian fashion boutique called ${s.name}, ` +
      `${s.description}, clothes on racks, warm lighting, wide shot, no text`, seed++, 800, 400);
    await d.ref.update({ imageUrl: link });
    await warm(link, s.name);
  }
  console.log(`Done: ${products.size} products, ${stores.size} stores.`);
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
