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
  deleteField,
  doc,
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
