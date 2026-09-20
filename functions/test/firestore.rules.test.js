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
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  setDoc,
  updateDoc,
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
    email: `${uid}@example.test`,
    photoUrl: '',
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

test('A: normal customer can register only a safe profile', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/customer'), safeProfile('customer')));
});

test('B1: normal customer cannot register with a privileged role', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  for (const role of ['admin', 'developer']) {
    await assertFails(setDoc(doc(db, 'users/customer'), {
      ...safeProfile('customer'),
      role,
    }));
  }
});

test('B2: normal customer cannot add, change, or remove authority fields', async () => {
  const db = testEnv.authenticatedContext('customer-update').firestore();
  await assertSucceeds(setDoc(
    doc(db, 'users/customer-update'),
    safeProfile('customer-update'),
  ));
  await assertFails(updateDoc(
    doc(db, 'users/customer-update'),
    { role: 'admin' },
  ));
  await assertFails(updateDoc(
    doc(db, 'users/customer-update'),
    { adminScopes: ['products'] },
  ));
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users/customer-update'),
      { role: 'user', adminScopes: [] },
      { merge: true },
    );
  });
  await assertFails(updateDoc(
    doc(db, 'users/customer-update'),
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
    await assertFails(setDoc(doc(db, 'users/customer'), {
      ...safeProfile('customer'),
      [field]: value,
    }));
  }
});

test('D: normal customer can update approved profile fields', async () => {
  const db = testEnv.authenticatedContext('customer').firestore();
  await assertSucceeds(setDoc(doc(db, 'users/customer'), safeProfile('customer')));
  await assertSucceeds(updateDoc(doc(db, 'users/customer'), {
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
    await setDoc(doc(context.firestore(), 'users/customer'), {
      ...safeProfile('customer'),
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
