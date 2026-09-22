const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const functions = require('../src/index');

const functionsSource = fs.readFileSync(
  path.join(__dirname, '..', 'src', 'index.js'),
  'utf8',
);

test('SEC-07: mobile customer callables declare App Check enforcement', () => {
  assert.match(
    functionsSource,
    /const MOBILE_CALLABLE_OPTIONS = \{ enforceAppCheck: true \};/,
  );

  for (const name of [
    'hardDeleteAccount',
    'createCustomerOrder',
    'cancelCustomerOrder',
  ]) {
    assert.match(
      functionsSource,
      new RegExp(
        `exports\\.${name} = onCall\\(MOBILE_CALLABLE_OPTIONS, async`,
      ),
      `${name} must use the mobile App Check options`,
    );
  }
});

test('SEC-07: operator role callable keeps its claim authority boundary', () => {
  assert.match(
    functionsSource,
    /exports\.setUserAdminAccess = onCall\(async/,
  );
  assert.doesNotMatch(
    functionsSource,
    /exports\.setUserAdminAccess = onCall\(MOBILE_CALLABLE_OPTIONS/,
  );
});

test('SEC-07: App Check does not replace callable authentication', async () => {
  await assert.rejects(
    functions.hardDeleteAccount.run({ auth: null, data: null }),
    (error) => error.code === 'unauthenticated',
  );
  await assert.rejects(
    functions.createCustomerOrder.run({ auth: null, data: {} }),
    (error) => error.code === 'unauthenticated',
  );
});
