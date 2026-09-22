const test = require('node:test');
const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const functions = require('../src/index');

const db = admin.firestore();
const bucket = admin.storage().bucket();

test('QA-01: hard deletion removes customer data and retains records', async () => {
  for (const variable of [
    'FIREBASE_AUTH_EMULATOR_HOST',
    'FIRESTORE_EMULATOR_HOST',
    'FIREBASE_STORAGE_EMULATOR_HOST',
  ]) {
    assert.ok(process.env[variable], `${variable} is required`);
  }

  const uid = 'qa-account-owner';
  const otherUid = 'qa-other-user';

  await admin.auth().createUser({ uid, email: 'qa-owner@example.test' });
  await Promise.all([
    db.doc(`users/${uid}`).set({ uid }),
    db.doc(`users_public/${uid}`).set({ uid, username: 'qaowner' }),
    db.doc(`users_private/${uid}`).set({ uid, email: 'qa-owner@example.test' }),
    db.doc(`usernames/qaowner`).set({ uid, username: 'qaowner' }),
    db.doc(`users/${uid}/cart/product-1`).set({ productId: 'product-1' }),
    db.doc(`users/${uid}/collections/collection-1`).set({ uid }),
    db.doc(`users/${uid}/wishlists/wishlist-1`).set({ uid }),
    db.doc(`users/${uid}/saved_posts/post-1`).set({ postId: 'post-1' }),
    db.doc(`users/${uid}/support_tickets/ticket-1`).set({ uid }),
    db.doc(`users/${uid}/support_tickets/ticket-1/messages/message-1`).set({ uid }),
    db.doc(`users/${otherUid}/follow_requests/${uid}`).set({ uid }),
    db.doc(`posts/owned-post`).set({ uid, imageUrl: '' }),
    db.doc(`posts/owned-post/comments/other-comment`).set({ uid: otherUid }),
    db.doc(`posts/owned-post/comments/other-comment/replies/other-reply`).set({
      uid: otherUid,
    }),
    db.doc(`posts/other-post`).set({ uid: otherUid, commentCount: 1 }),
    db.doc(`posts/other-post/comments/own-comment`).set({ uid }),
    db.doc(`posts/other-post/comments/other-comment/replies/own-reply`).set({
      uid,
    }),
    db.doc(`products/product-1/reviews/${uid}`).set({
      productId: 'product-1',
      userId: uid,
    }),
    db.doc('orders/retained-order').set({ userId: uid }),
    db.doc('reports/retained-report').set({ reporterUid: uid }),
    bucket.file(`profile_images/${uid}.jpg`).save('profile'),
    bucket.file(`post_images/${uid}_1700000000000.jpg`).save('post'),
    bucket.file(`support_attachments/${uid}/1700000000000_0001.png`).save(
      'support',
    ),
  ]);

  const response = await functions.hardDeleteAccount.run({
    auth: {
      uid,
      token: { auth_time: Math.floor(Date.now() / 1000) },
    },
    app: { appId: 'qa-app' },
    data: null,
  });

  assert.deepEqual(response, { ok: true });
  for (const path of [
    `users/${uid}`,
    `users_public/${uid}`,
    `users_private/${uid}`,
    'usernames/qaowner',
    `users/${uid}/cart/product-1`,
    `users/${uid}/collections/collection-1`,
    `users/${uid}/support_tickets/ticket-1`,
    `users/${uid}/support_tickets/ticket-1/messages/message-1`,
    'posts/owned-post',
    'posts/owned-post/comments/other-comment/replies/other-reply',
    'posts/other-post/comments/own-comment',
    'posts/other-post/comments/other-comment/replies/own-reply',
    `products/product-1/reviews/${uid}`,
    `users/${otherUid}/follow_requests/${uid}`,
  ]) {
    assert.equal((await db.doc(path).get()).exists, false, path);
  }

  assert.equal((await db.doc('orders/retained-order').get()).exists, true);
  assert.equal((await db.doc('reports/retained-report').get()).exists, true);
  for (const path of [
    `profile_images/${uid}.jpg`,
    `post_images/${uid}_1700000000000.jpg`,
    `support_attachments/${uid}/1700000000000_0001.png`,
  ]) {
    const [exists] = await bucket.file(path).exists();
    assert.equal(exists, false, path);
  }
  await assert.rejects(
    admin.auth().getUser(uid),
    (error) => error.code === 'auth/user-not-found',
  );

  await Promise.all([
    db.doc('orders/retained-order').delete(),
    db.doc('reports/retained-report').delete(),
    db.doc('posts/other-post').delete(),
  ]);
});
