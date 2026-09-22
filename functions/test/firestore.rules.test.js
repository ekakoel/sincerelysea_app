const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  addDoc,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} = require('firebase/firestore');

const projectId = 'sincerelysea-sec01-test';
let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
    },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearFirestore();
});

function safeProfile(uid) {
  return {
    uid,
    username: uid,
    usernameLower: uid,
    usernameChangedOnce: false,
    displayName: 'Customer',
    photoUrl: '',
    createdAt: 1,
    updatedAt: 1,
  };
}

function privateProfile(uid) {
  return {
    uid,
    email: `${uid}@example.test`,
    phone: '0800000000',
    address: 'Private address',
    createdAt: 1,
    updatedAt: 1,
  };
}

function validProduct(uid) {
  return {
    userId: uid,
    ownerType: 'business',
    ownerId: 'sincerelysea',
    storeName: 'SincerelySea Store',
    managedByAdmins: true,
    name: 'Test Product',
    price: 100,
    inventoryType: 'ready_stock',
    preorderDays: 0,
    preorderNote: '',
    availableForPurchase: true,
    stock: 1,
    images: [],
  };
}

function validReview(uid, overrides = {}) {
  return {
    productId: 'product-1',
    userId: uid,
    rating: 5,
    reviewText: 'A durable and well-finished product.',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function validOrder(uid) {
  return {
    userId: uid,
    storeId: 'sincerelysea',
    storeName: 'SincerelySea Store',
    fulfillmentMode: 'admin_managed',
    items: [],
    totalPrice: 100,
    status: 'pending',
    sellerIds: [],
    customerName: 'Customer',
    phone: '0800000000',
    address: 'Test address',
    createdAt: 1,
  };
}

function validJournalEntry() {
  return {
    storeId: 'sincerelysea',
    storeName: 'SincerelySea Store',
    orderId: 'order-1',
    entryType: 'order_created',
    memo: 'Customer order created for SincerelySea Store.',
    lines: [],
  };
}

function validSalesReport() {
  return {
    storeId: 'sincerelysea',
    storeName: 'SincerelySea Store',
    reportDateKey: '2026-09-20',
    orderCount: 1,
    paidOrderCount: 0,
    completedOrderCount: 0,
    cancelledOrderCount: 0,
    grossSales: 100,
    cancelledSales: 0,
    netSales: 100,
  };
}

function validPost(uid, visibility = 'public') {
  return {
    content: 'Community post',
    username: uid,
    imageUrl: '',
    location: '',
    locationName: '',
    locationKeywords: [],
    geo: null,
    hashtags: [],
    uid,
    visibility,
    allowComments: 'everyone',
    type: 'post',
    productId: null,
    timestamp: 1,
    likes: [],
    commentCount: 0,
    shareCount: 0,
  };
}

function validSupportTicket(uid, overrides = {}) {
  return {
    uid,
    category: 'account',
    subject: 'Account support',
    description: 'Please help with this account issue.',
    contactEmail: 'customer@example.test',
    status: 'open',
    priority: 'normal',
    attachmentName: 'evidence.jpg',
    attachmentPath: `support_attachments/${uid}/1700000000000_0001.jpg`,
    attachmentUrl: '',
    createdAt: 1,
    updatedAt: 1,
    lastMessage: 'Please help with this account issue.',
    lastMessageAt: 1,
    searchTokens: ['account'],
    deviceInfo: { platform: 'android' },
    createdDayKey: '20260921',
    ...overrides,
  };
}

test('A: normal customer can register only a safe profile', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'users_public/customer'),
    safeProfile('customer'),
  ));
});

test('B1: normal customer cannot register with a privileged role', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  for (const role of ['admin', 'developer']) {
    await assertFails(setDoc(doc(db, 'users_public/customer'), {
      ...safeProfile('customer'),
      role,
    }));
  }
});

test('B2: normal customer cannot add, change, or remove authority fields', async () => {
  const db = testEnv.authenticatedContext('customer-update').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'users_private/customer-update'),
    privateProfile('customer-update'),
  ));
  await assertFails(updateDoc(
    doc(db, 'users_private/customer-update'),
    { role: 'admin' },
  ));
  await assertFails(updateDoc(
    doc(db, 'users_private/customer-update'),
    { adminScopes: ['products'] },
  ));
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users_private/customer-update'),
      { role: 'user', adminScopes: [] },
      { merge: true },
    );
  });
  await assertFails(updateDoc(
    doc(db, 'users_private/customer-update'),
    { role: deleteField(), adminScopes: deleteField() },
  ));
});

test('C: normal customer cannot create protected authority fields', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  const protectedFields = {
    isAdmin: true,
    isDeveloper: true,
    permissions: ['all'],
    official: true,
    isOfficial: true,
    endorsement: true,
    accountVerified: true,
    verifiedOwner: true,
  };
  for (const [field, value] of Object.entries(protectedFields)) {
    await assertFails(setDoc(doc(db, 'users_public/customer'), {
      ...safeProfile('customer'),
      [field]: value,
    }));
  }
});

test('D: normal customer can update approved profile fields', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'users_public/customer'),
    safeProfile('customer'),
  ));
  await assertSucceeds(updateDoc(doc(db, 'users_public/customer'), {
    displayName: 'Updated Customer',
    updatedAt: 2,
  }));
});

test('E: claimed product admin and developer can perform protected operations', async () => {
  const adminDb = testEnv.authenticatedContext('catalog-admin', {
    admin: true,
    adminScopes: ['products'],
  }).firestore();
  await assertSucceeds(setDoc(
    doc(adminDb, 'products/product-1'),
    validProduct('catalog-admin'),
  ));

  const developerDb = testEnv.authenticatedContext('system-developer', {
    developer: true,
  }).firestore();
  await assertSucceeds(setDoc(
    doc(developerDb, 'products/product-2'),
    validProduct('system-developer'),
  ));
});

test('F: unauthenticated caller cannot perform a protected operation', async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(setDoc(
    doc(db, 'products/product-1'),
    validProduct('attacker'),
  ));
});

test('G: signed-in non-admin cannot perform a protected operation', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  await assertFails(setDoc(
    doc(db, 'products/product-1'),
    validProduct('customer'),
  ));
});

test('legacy Firestore role is non-authoritative', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users_private/customer'), {
      ...privateProfile('customer'),
      role: 'developer',
      adminScopes: ['all'],
    });
  });
  const db = testEnv.authenticatedContext('customer').firestore();
  await assertFails(setDoc(
    doc(db, 'products/product-1'),
    validProduct('customer'),
  ));
});

test('SEC-04: public profiles exclude private account fields', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  for (const field of ['email', 'phone', 'address']) {
    await assertFails(setDoc(doc(db, 'users_public/customer'), {
      ...safeProfile('customer'),
      [field]: 'private-value',
    }));
  }
});

test('SEC-04: signed-in users can read public profiles only', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users_public/other-customer'),
      safeProfile('other-customer'),
    );
    await setDoc(
      doc(context.firestore(), 'users_private/other-customer'),
      privateProfile('other-customer'),
    );
  });

  const db = testEnv.authenticatedContext('customer').firestore();
  await assertSucceeds(getDoc(doc(db, 'users_public/other-customer')));
  await assertFails(getDoc(doc(db, 'users_private/other-customer')));
});

test('SEC-04: owner can create and read their private account document', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'users_private/customer'),
    privateProfile('customer'),
  ));
  await assertSucceeds(getDoc(doc(db, 'users_private/customer')));
});

test('SEC-04: legacy mixed user documents are owner-only', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/customer'), {
      ...safeProfile('customer'),
      email: 'customer@example.test',
    });
  });

  const ownerDb = testEnv.authenticatedContext('customer').firestore();
  const otherDb = testEnv.authenticatedContext('other-customer').firestore();
  await assertSucceeds(getDoc(doc(ownerDb, 'users/customer')));
  await assertFails(getDoc(doc(otherDb, 'users/customer')));
});

test('SEC-06: support records accept own paths and reject token URLs', async () => {
  const ownerDb = testEnv.authenticatedContext('customer').firestore();
  const ticketRef = doc(
    ownerDb,
    'users/customer/support_tickets/ticket-1',
  );
  await assertSucceeds(setDoc(ticketRef, validSupportTicket('customer')));

  const attackerDb = testEnv.authenticatedContext('attacker').firestore();
  await assertFails(getDoc(doc(
    attackerDb,
    'users/customer/support_tickets/ticket-1',
  )));
  await assertFails(setDoc(
    doc(ownerDb, 'users/customer/support_tickets/ticket-token'),
    validSupportTicket('customer', {
      attachmentUrl:
        'https://firebasestorage.googleapis.com/v0/b/test/o/support.jpg?token=secret',
    }),
  ));
  await assertFails(setDoc(
    doc(ownerDb, 'users/customer/support_tickets/ticket-forged'),
    validSupportTicket('customer', {
      attachmentPath:
        'support_attachments/other/1700000000000_0001.jpg',
    }),
  ));
});

test('SEC-05: authenticated public read and owner private read are allowed', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'posts/public-post'),
      validPost('author'),
    );
    await setDoc(
      doc(context.firestore(), 'posts/private-post'),
      validPost('author', 'private'),
    );
  });

  const viewerDb = testEnv.authenticatedContext('viewer').firestore();
  const ownerDb = testEnv.authenticatedContext('author').firestore();
  const anonymousDb = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(viewerDb, 'posts/public-post')));
  await assertFails(getDoc(doc(anonymousDb, 'posts/public-post')));
  await assertSucceeds(getDoc(doc(ownerDb, 'posts/private-post')));
  await assertFails(getDoc(doc(viewerDb, 'posts/private-post')));
});

test('SEC-05: symmetric blocks deny direct post and child reads', async () => {
  for (const [blocker, blocked] of [
    ['author', 'viewer'],
    ['viewer', 'author'],
  ]) {
    await testEnv.clearFirestore();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'posts/post-1'), validPost('author'));
      await setDoc(doc(db, `users/${blocker}/blocks/${blocked}`), {
        uid: blocked,
        username: blocked,
        createdAt: 1,
      });
      await setDoc(doc(db, 'posts/post-1/comments/comment-1'), {
        content: 'Comment',
        username: 'author',
        uid: 'author',
        timestamp: 1,
        likes: [],
      });
      await setDoc(
        doc(db, 'posts/post-1/comments/comment-1/replies/reply-1'),
        {
          content: 'Reply',
          username: 'author',
          uid: 'author',
          timestamp: 1,
          likes: [],
        },
      );
    });

    const viewerDb = testEnv.authenticatedContext('viewer').firestore();
    await assertFails(getDoc(doc(viewerDb, 'posts/post-1')));
    await assertFails(getDoc(
      doc(viewerDb, 'posts/post-1/comments/comment-1'),
    ));
    await assertFails(getDoc(
      doc(viewerDb, 'posts/post-1/comments/comment-1/replies/reply-1'),
    ));
    await assertFails(addDoc(
      collection(viewerDb, 'posts/post-1/comments'),
      {
        content: 'Blocked interaction',
        username: 'viewer',
        uid: 'viewer',
        timestamp: 2,
        likes: [],
      },
    ));
    await assertFails(updateDoc(doc(viewerDb, 'posts/post-1'), {
      likes: ['viewer'],
    }));
  }
});

test('SEC-05: follower visibility requires approved relationship', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, 'posts/followers-post'),
      validPost('author', 'followers'),
    );
    await setDoc(doc(db, 'users/author/followers/approved'), {
      uid: 'approved',
      username: 'approved',
      createdAt: 1,
    });
    await setDoc(doc(db, 'users/author/follow_requests/pending'), {
      uid: 'pending',
      username: 'pending',
      status: 'pending',
      createdAt: 1,
    });
  });

  const approvedDb = testEnv.authenticatedContext('approved').firestore();
  await assertSucceeds(getDoc(doc(approvedDb, 'posts/followers-post')));
  await assertSucceeds(getDocs(query(
    collection(approvedDb, 'posts'),
    where('uid', '==', 'author'),
    where('visibility', '==', 'followers'),
  )));
  await assertFails(getDoc(doc(
    testEnv.authenticatedContext('pending').firestore(),
    'posts/followers-post',
  )));
  await assertFails(getDoc(doc(
    testEnv.authenticatedContext('outsider').firestore(),
    'posts/followers-post',
  )));

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users/author/blocks/approved'), {
      uid: 'approved',
      username: 'approved',
      createdAt: 2,
    });
  });
  await assertFails(getDoc(doc(approvedDb, 'posts/followers-post')));
  await assertFails(getDocs(query(
    collection(approvedDb, 'posts'),
    where('uid', '==', 'author'),
    where('visibility', '==', 'followers'),
  )));
});

test('SEC-05: post ownership and product-post creation are protected', async () => {
  const authorDb = testEnv.authenticatedContext('author').firestore();
  await assertSucceeds(setDoc(
    doc(authorDb, 'posts/post-1'),
    validPost('author'),
  ));
  await assertSucceeds(updateDoc(doc(authorDb, 'posts/post-1'), {
    content: 'Updated community post',
  }));
  const attackerDb = testEnv.authenticatedContext('attacker').firestore();
  await assertFails(updateDoc(doc(attackerDb, 'posts/post-1'), {
    uid: 'attacker',
  }));
  await assertFails(setDoc(doc(attackerDb, 'posts/product-post'), {
    ...validPost('attacker'),
    type: 'product',
    productId: 'product-1',
  }));
});

test('SEC-05: owner controls validated block records only', async () => {
  const ownerDb = testEnv.authenticatedContext('owner').firestore();
  const blockRef = doc(ownerDb, 'users/owner/blocks/target');
  await assertSucceeds(setDoc(blockRef, {
    uid: 'target',
    username: 'target',
    createdAt: 1,
  }));
  await assertSucceeds(deleteDoc(blockRef));
  await assertFails(setDoc(doc(ownerDb, 'users/owner/blocks/owner'), {
    uid: 'owner',
    username: 'owner',
    createdAt: 1,
  }));

  const attackerDb = testEnv.authenticatedContext('attacker').firestore();
  await assertFails(setDoc(doc(attackerDb, 'users/owner/blocks/attacker'), {
    uid: 'attacker',
    username: 'attacker',
    createdAt: 1,
  }));
});

test('SEC-05: hide and saved-post state remain owner-only', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/owner/hidden_posts/post-1'), {
      postId: 'post-1',
      postOwnerUid: 'author',
      createdAt: 1,
    });
    await setDoc(doc(db, 'users/owner/saved_posts/post-1'), {
      postId: 'post-1',
    });
  });
  const attackerDb = testEnv.authenticatedContext('attacker').firestore();
  await assertFails(getDoc(doc(
    attackerDb,
    'users/owner/hidden_posts/post-1',
  )));
  await assertFails(getDoc(doc(
    attackerDb,
    'users/owner/saved_posts/post-1',
  )));
});

test('SEC-05: author-scoped public query is compatible and broad query is denied', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'posts/public-post'),
      validPost('author'),
    );
  });
  const db = testEnv.authenticatedContext('viewer').firestore();
  await assertSucceeds(getDocs(query(
    collection(db, 'posts'),
    where('uid', '==', 'author'),
    where('visibility', '==', 'public'),
  )));
  await assertFails(getDocs(query(
    collection(db, 'posts'),
    where('visibility', '==', 'public'),
  )));
});

test('SEC-05: legacy community posts are owner-only while product posts remain readable', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const community = validPost('author');
    delete community.visibility;
    const product = {
      ...validPost('catalog-admin'),
      type: 'product',
      productId: 'product-1',
    };
    delete product.visibility;
    await setDoc(doc(context.firestore(), 'posts/legacy-community'), community);
    await setDoc(doc(context.firestore(), 'posts/legacy-product'), product);
  });

  const ownerDb = testEnv.authenticatedContext('author').firestore();
  const viewerDb = testEnv.authenticatedContext('viewer').firestore();
  await assertSucceeds(getDoc(doc(ownerDb, 'posts/legacy-community')));
  await assertFails(getDoc(doc(viewerDb, 'posts/legacy-community')));
  await assertSucceeds(getDoc(doc(viewerDb, 'posts/legacy-product')));
});

test('MOB-03A: authenticated customers can read product reviews', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, 'products/product-1'),
      validProduct('catalog-admin'),
    );
    await setDoc(
      doc(db, 'products/product-1/reviews/reviewer'),
      validReview('reviewer'),
    );
  });

  const customerDb = testEnv.authenticatedContext('customer').firestore();
  const publicReviews = collection(
    customerDb,
    'products/product-1/reviews',
  );
  await assertSucceeds(getDocs(publicReviews));

  const guestDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDocs(collection(
    guestDb,
    'products/product-1/reviews',
  )));
});

test('MOB-03A: valid own review create is allowed and IDs prevent duplicates', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'products/product-1'),
      validProduct('catalog-admin'),
    );
  });

  const db = testEnv.authenticatedContext('customer').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'products/product-1/reviews/customer'),
    validReview('customer'),
  ));
  await assertFails(setDoc(
    doc(db, 'products/product-1/reviews/second-review'),
    validReview('customer'),
  ));
});

test('MOB-03A: ratings outside 1 to 5 are denied', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'products/product-1'),
      validProduct('catalog-admin'),
    );
  });

  const lowDb = testEnv.authenticatedContext('low-rating').firestore();
  await assertFails(setDoc(
    doc(lowDb, 'products/product-1/reviews/low-rating'),
    validReview('low-rating', { rating: 0 }),
  ));
  const highDb = testEnv.authenticatedContext('high-rating').firestore();
  await assertFails(setDoc(
    doc(highDb, 'products/product-1/reviews/high-rating'),
    validReview('high-rating', { rating: 6 }),
  ));
});

test('MOB-03A: forged ownership and moderation fields are denied', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'products/product-1'),
      validProduct('catalog-admin'),
    );
  });

  const db = testEnv.authenticatedContext('customer').firestore();
  const reviewRef = doc(db, 'products/product-1/reviews/customer');
  await assertFails(setDoc(reviewRef, validReview('forged-user')));

  for (const [field, value] of Object.entries({
    approved: true,
    featured: true,
    official: true,
    hiddenByAdmin: true,
    moderated: true,
  })) {
    await assertFails(setDoc(
      reviewRef,
      validReview('customer', { [field]: value }),
    ));
  }
});

test('MOB-03A: only the owner can update legitimate review fields', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'products/product-1'),
      validProduct('catalog-admin'),
    );
  });

  const ownerDb = testEnv.authenticatedContext('owner').firestore();
  const reviewRef = doc(ownerDb, 'products/product-1/reviews/owner');
  await assertSucceeds(setDoc(reviewRef, validReview('owner')));
  await assertSucceeds(updateDoc(reviewRef, {
    rating: 4,
    reviewText: 'Updated after using it for several weeks.',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(reviewRef, { productId: 'product-2' }));

  const otherDb = testEnv.authenticatedContext('other').firestore();
  await assertFails(updateDoc(
    doc(otherDb, 'products/product-1/reviews/owner'),
    {
      rating: 1,
      reviewText: 'Forged review update.',
      updatedAt: serverTimestamp(),
    },
  ));
  const adminDb = testEnv.authenticatedContext('review-admin', {
    admin: true,
    adminScopes: ['community'],
  }).firestore();
  await assertFails(updateDoc(
    doc(adminDb, 'products/product-1/reviews/owner'),
    {
      rating: 1,
      reviewText: 'Customer app claims cannot moderate reviews.',
      updatedAt: serverTimestamp(),
    },
  ));
});

test('MOB-03A: only the owner can delete a review', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'products/product-1'),
      validProduct('catalog-admin'),
    );
  });

  const ownerDb = testEnv.authenticatedContext('owner').firestore();
  const reviewRef = doc(ownerDb, 'products/product-1/reviews/owner');
  await assertSucceeds(setDoc(reviewRef, validReview('owner')));

  const otherDb = testEnv.authenticatedContext('other').firestore();
  await assertFails(deleteDoc(
    doc(otherDb, 'products/product-1/reviews/owner'),
  ));
  await assertSucceeds(deleteDoc(reviewRef));
});

test('MOB-03A: reviews cannot be created for a missing product', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  await assertFails(setDoc(
    doc(db, 'products/missing/reviews/customer'),
    validReview('customer', { productId: 'missing' }),
  ));
});

test('SEC-02: customer cannot create or update financial records', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  const journalRef = doc(db, 'journal_entries/order_created_order-1');
  const reportRef = doc(db, 'sales_reports/2026-09-20');

  await assertFails(setDoc(journalRef, validJournalEntry()));
  await assertFails(setDoc(reportRef, validSalesReport()));

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'journal_entries/order_created_order-1'),
      validJournalEntry(),
    );
    await setDoc(
      doc(context.firestore(), 'sales_reports/2026-09-20'),
      validSalesReport(),
    );
  });

  await assertFails(updateDoc(journalRef, { memo: 'forged' }));
  await assertFails(updateDoc(reportRef, { netSales: 999999 }));
});

test('SEC-03: customer cannot create, mutate, or delete orders directly', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  const orderRef = doc(db, 'orders/order-1');

  await assertFails(setDoc(orderRef, validOrder('customer')));
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'orders/order-1'),
      validOrder('customer'),
    );
  });
  await assertFails(updateDoc(orderRef, { status: 'cancelled' }));
  await assertFails(deleteDoc(orderRef));
});

test('SEC-03: customer can read only their own order', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'orders/order-1'),
      validOrder('customer'),
    );
  });

  const ownerDb = testEnv.authenticatedContext('customer').firestore();
  const otherDb = testEnv.authenticatedContext('other-customer').firestore();
  await assertSucceeds(getDoc(doc(ownerDb, 'orders/order-1')));
  await assertFails(getDoc(doc(otherDb, 'orders/order-1')));
});

test('SEC-03: customer cannot mutate product stock directly', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'products/product-1'),
      validProduct('catalog-admin'),
    );
  });

  const db = testEnv.authenticatedContext('customer').firestore();
  await assertFails(updateDoc(doc(db, 'products/product-1'), { stock: 999 }));
});
