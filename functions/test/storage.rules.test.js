const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');

const projectId = 'sincerelysea-sec06-test';
const mebibyte = 1024 * 1024;
let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    storage: {
      rules: fs.readFileSync(
        path.join(__dirname, '..', '..', 'storage.rules'),
        'utf8',
      ),
    },
  });
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test.beforeEach(async () => {
  await testEnv.clearStorage();
});

function objectRef(context, objectPath) {
  return context.storage().ref(objectPath);
}

function upload(
  context,
  objectPath,
  { size = 1, contentType = 'image/jpeg', customMetadata } = {},
) {
  return objectRef(context, objectPath).put(
    new Uint8Array(size),
    { contentType, customMetadata },
  );
}

async function seed(objectPath, options = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await upload(context, objectPath, options);
  });
}

test('SEC-06: unauthenticated customer upload is denied', async () => {
  const anonymous = testEnv.unauthenticatedContext();
  await assertFails(upload(anonymous, 'profile_images/anonymous.jpg'));
  await assertFails(upload(anonymous, 'post_images/anonymous_1.jpg'));
});

test('SEC-06: profile media is owner-write and cross-user safe', async () => {
  const owner = testEnv.authenticatedContext('owner');
  const attacker = testEnv.authenticatedContext('attacker');
  const objectPath = 'profile_images/owner.jpg';

  await assertSucceeds(upload(owner, objectPath));
  await assertFails(upload(attacker, objectPath));
  await assertFails(objectRef(attacker, objectPath).delete());
  await assertSucceeds(objectRef(owner, objectPath).delete());
});

test('SEC-06: post media is owner-write and cross-user safe', async () => {
  const owner = testEnv.authenticatedContext('owner');
  const attacker = testEnv.authenticatedContext('attacker');
  const objectPath = 'post_images/owner_1700000000000.jpg';

  await assertSucceeds(upload(owner, objectPath, { contentType: 'image/webp' }));
  await assertFails(upload(attacker, objectPath));
  await assertFails(objectRef(attacker, objectPath).delete());
  await assertSucceeds(objectRef(owner, objectPath).delete());
});

test('SEC-06: MIME allowlist and profile size limit are enforced', async () => {
  const owner = testEnv.authenticatedContext('owner');
  await assertFails(upload(owner, 'profile_images/owner.jpg', {
    contentType: 'text/html',
  }));
  await assertSucceeds(upload(owner, 'profile_images/owner.jpg', {
    size: 5 * mebibyte,
    contentType: 'image/png',
  }));
  await assertFails(upload(owner, 'profile_images/owner.jpg', {
    size: 5 * mebibyte + 1,
    contentType: 'image/png',
  }));
});

test('SEC-06: official legacy product media is customer read-only', async () => {
  const objectPath = 'users/catalog-admin/products/product-1/hero.jpg';
  await seed(objectPath);

  const customer = testEnv.authenticatedContext('customer');
  const anonymous = testEnv.unauthenticatedContext();
  await assertSucceeds(objectRef(customer, objectPath).getDownloadURL());
  await assertFails(objectRef(anonymous, objectPath).getDownloadURL());
  await assertFails(upload(customer, objectPath, {
    customMetadata: { official: 'true', isAdmin: 'true' },
  }));
  await assertFails(objectRef(customer, objectPath).delete());
});

test('SEC-06: support attachment is private to its owner', async () => {
  const owner = testEnv.authenticatedContext('owner');
  const other = testEnv.authenticatedContext('other');
  const objectPath = 'support_attachments/owner/1700000000000_0001.png';

  await assertSucceeds(upload(owner, objectPath, { contentType: 'image/png' }));
  await assertSucceeds(objectRef(owner, objectPath).getDownloadURL());
  await assertFails(objectRef(other, objectPath).getDownloadURL());
  await assertFails(objectRef(other, objectPath).delete());
  await assertSucceeds(objectRef(owner, objectPath).delete());
});

test('SEC-06: attachment extension must match MIME and other paths deny', async () => {
  const owner = testEnv.authenticatedContext('owner');
  await assertFails(upload(
    owner,
    'support_attachments/owner/1700000000000_0001.png',
    { contentType: 'image/jpeg' },
  ));
  await assertFails(upload(owner, 'products/product-1/hero.jpg'));
  await assertFails(upload(owner, 'store/branding/logo.png', {
    contentType: 'image/png',
  }));
});
