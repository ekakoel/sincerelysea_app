const admin = require('firebase-admin');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} = require('firebase-functions/v2/firestore');

admin.initializeApp();
setGlobalOptions({ maxInstances: 10, region: 'us-central1' });

const db = admin.firestore();
const storage = admin.storage();
const RECENT_AUTH_MAX_AGE_SECONDS = 5 * 60;

function notificationsRef(uid) {
  return db.collection('users').doc(uid).collection('notifications');
}

async function createNotification({
  targetUid,
  type,
  actorUid,
  actorUsername,
  postId = null,
  message = '',
  eventId,
}) {
  if (!targetUid || !actorUid || targetUid === actorUid) {
    return;
  }

  const safePostId = postId || 'none';
  const docId = `${type}_${actorUid}_${safePostId}_${eventId || Date.now()}`;

  await notificationsRef(targetUid).doc(docId).set(
    {
      type,
      actorUid,
      actorUsername,
      postId,
      message,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'server',
    },
    { merge: true },
  );
}

function extractStoragePathFromUrl(url) {
  if (!url || typeof url !== 'string') {
    return null;
  }

  try {
    const parsed = new URL(url);

    if (parsed.hostname.includes('firebasestorage.googleapis.com')) {
      const marker = '/o/';
      const idx = parsed.pathname.indexOf(marker);
      if (idx < 0) return null;
      return decodeURIComponent(parsed.pathname.substring(idx + marker.length));
    }

    if (parsed.hostname.includes('storage.googleapis.com')) {
      const segments = parsed.pathname.split('/').filter(Boolean);
      if (segments.length < 2) return null;
      return decodeURIComponent(segments.slice(1).join('/'));
    }
  } catch (_) {
    return null;
  }

  return null;
}

async function deleteCollection(path, batchSize = 200) {
  const collectionRef = db.collection(path);

  while (true) {
    const snapshot = await collectionRef.limit(batchSize).get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  }
}

async function deletePostsOwnedBy(uid) {
  const postSnapshot = await db.collection('posts').where('uid', '==', uid).get();

  for (const postDoc of postSnapshot.docs) {
    await deleteCollection(`posts/${postDoc.id}/comments`);

    const imageUrl = postDoc.data().imageUrl;
    const objectPath = extractStoragePathFromUrl(imageUrl);
    if (objectPath) {
      try {
        await storage.bucket().file(objectPath).delete();
      } catch (_) {}
    }

    await postDoc.ref.delete();
  }
}

async function deleteUserCommentsAndFixCount(uid) {
  const comments = await db.collectionGroup('comments').where('uid', '==', uid).get();
  await Promise.all(comments.docs.map((commentDoc) => commentDoc.ref.delete()));
}

async function deleteCrossFollowDocs(uid) {
  const followerDocs = await db.collectionGroup('followers').where('uid', '==', uid).get();
  const followingDocs = await db.collectionGroup('following').where('uid', '==', uid).get();

  const batch = db.batch();
  followerDocs.docs.forEach((d) => batch.delete(d.ref));
  followingDocs.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

async function deleteUsernameReservation(uid) {
  const usernameSnapshot = await db.collection('usernames').where('uid', '==', uid).get();
  const batch = db.batch();
  usernameSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

async function deleteUserStorage(uid) {
  try {
    await storage.bucket().file(`profile_images/${uid}.jpg`).delete();
  } catch (_) {}

  const [files] = await storage.bucket().getFiles({ prefix: 'post_images/' });
  const ownFiles = files.filter((file) => file.name.startsWith(`post_images/${uid}_`));
  await Promise.allSettled(ownFiles.map((file) => file.delete()));
}

exports.hardDeleteAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }

  const authTime = Number(request.auth.token.auth_time || 0);
  const now = Math.floor(Date.now() / 1000);
  if (!authTime || now - authTime > RECENT_AUTH_MAX_AGE_SECONDS) {
    throw new HttpsError(
      'failed-precondition',
      'Recent login required. Please reauthenticate and try again.',
    );
  }

  const uid = request.auth.uid;

  await deletePostsOwnedBy(uid);
  await deleteUserCommentsAndFixCount(uid);
  await deleteCrossFollowDocs(uid);
  await deleteUsernameReservation(uid);

  await deleteCollection(`users/${uid}/followers`);
  await deleteCollection(`users/${uid}/following`);
  await deleteCollection(`users/${uid}/saved_posts`);
  await deleteCollection(`users/${uid}/wishlists`);
  await deleteCollection(`users/${uid}/blocks`);
  await deleteCollection(`users/${uid}/hidden_posts`);
  await deleteCollection(`users/${uid}/notifications`);
  await deleteCollection(`users/${uid}/follow_requests`);

  await db.collection('users').doc(uid).delete();
  await deleteUserStorage(uid);

  await admin.auth().deleteUser(uid);

  return { ok: true };
});

exports.onFollowCreated = onDocumentCreated(
  'users/{targetUid}/followers/{followerUid}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    await createNotification({
      targetUid: event.params.targetUid,
      type: 'follow',
      actorUid: event.params.followerUid,
      actorUsername: data.username || 'user',
      message: `@${data.username || 'user'} started following you`,
      eventId: event.id,
    });
  },
);

exports.onFollowRequestCreated = onDocumentCreated(
  'users/{targetUid}/follow_requests/{requestUid}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    await createNotification({
      targetUid: event.params.targetUid,
      type: 'follow_request',
      actorUid: event.params.requestUid,
      actorUsername: data.username || 'user',
      message: `@${data.username || 'user'} requested to follow you`,
      eventId: event.id,
    });
  },
);

exports.onCommentCreated = onDocumentCreated(
  'posts/{postId}/comments/{commentId}',
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;

    const postRef = db.collection('posts').doc(event.params.postId);
    await db.runTransaction(async (tx) => {
      const postDoc = await tx.get(postRef);
      if (!postDoc.exists) {
        return;
      }
      tx.update(postRef, {
        commentCount: admin.firestore.FieldValue.increment(1),
      });
    });

    const postSnap = await postRef.get();
    const post = postSnap.data();
    if (!post) return;

    await createNotification({
      targetUid: post.uid,
      type: 'comment',
      actorUid: comment.uid,
      actorUsername: comment.username || 'user',
      postId: event.params.postId,
      message: `@${comment.username || 'user'} commented on your post`,
      eventId: event.id,
    });
  },
);

exports.onCommentDeleted = onDocumentDeleted(
  'posts/{postId}/comments/{commentId}',
  async (event) => {
    const postRef = db.collection('posts').doc(event.params.postId);
    await db.runTransaction(async (tx) => {
      const postDoc = await tx.get(postRef);
      if (!postDoc.exists) {
        return;
      }
      const currentCount = Number(postDoc.get('commentCount') || 0);
      tx.update(postRef, {
        commentCount: Math.max(0, currentCount - 1),
      });
    });
  },
);

exports.onPostUpdated = onDocumentUpdated('posts/{postId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!before || !after) return;

  const postOwnerUid = after.uid;

  const beforeLikes = Array.isArray(before.likes) ? before.likes : [];
  const afterLikes = Array.isArray(after.likes) ? after.likes : [];
  const addedLikes = afterLikes.filter((uid) => !beforeLikes.includes(uid));

  for (const likerUid of addedLikes) {
    const likerSnap = await db.collection('users').doc(likerUid).get();
    const likerUsername = likerSnap.data()?.username || 'user';
    await createNotification({
      targetUid: postOwnerUid,
      type: 'like',
      actorUid: likerUid,
      actorUsername: likerUsername,
      postId: event.params.postId,
      message: `@${likerUsername} liked your post`,
      eventId: `${event.id}_${likerUid}`,
    });
  }

  const beforeShare = Number(before.shareCount || 0);
  const afterShare = Number(after.shareCount || 0);
  if (afterShare > beforeShare) {
    const actorUid = after.lastShareActorUid || null;
    if (actorUid) {
      const actorSnap = await db.collection('users').doc(actorUid).get();
      const actorUsername = actorSnap.data()?.username || 'user';
      await createNotification({
        targetUid: postOwnerUid,
        type: 'share',
        actorUid,
        actorUsername,
        postId: event.params.postId,
        message: `@${actorUsername} shared your post`,
        eventId: `${event.id}_${actorUid}_share`,
      });
    }
  }
});
