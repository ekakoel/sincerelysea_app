const fs = require('node:fs');
const path = require('node:path');
const admin = require('firebase-admin');
const { deleteApp, initializeApp } = require('firebase/app');
const {
  getAuth,
  inMemoryPersistence,
  setPersistence,
  signInWithCustomToken,
  signOut,
} = require('firebase/auth');
const {
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  limit,
  query,
  where,
} = require('firebase/firestore');

const EXPECTED_PROJECT_ID = 'gen-lang-client-0026437130';
const TOKEN_SIGNER_SERVICE_ACCOUNT =
  'firebase-adminsdk-fbsvc@gen-lang-client-0026437130.iam.gserviceaccount.com';
const DEVELOPER_UID = 'WT0trMBt9zNaMFYXQ61cs67K1x53';
const ADMIN_UID = '4RWo2A35L2NYavF4NuD0VwINOmB2';
const ALL_SCOPES = ['products', 'orders', 'finance', 'community', 'roles'];
const ADMIN_SCOPES = ['products', 'orders', 'finance', 'community'];

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
}

function projectFromArgs(argv) {
  if (argv.length !== 2 || argv[0] !== '--project') {
    throw new Error(
      'Usage: node scripts/verify-sec01-production.js --project <project-id>',
    );
  }
  if (argv[1] !== EXPECTED_PROJECT_ID) {
    throw new Error(`Refusing project ${argv[1]}; expected ${EXPECTED_PROJECT_ID}.`);
  }
  return argv[1];
}

function assertAmbientProjectIsSafe(projectId) {
  for (const variable of ['GOOGLE_CLOUD_PROJECT', 'GCLOUD_PROJECT']) {
    const value = process.env[variable];
    if (value && value !== projectId) {
      throw new Error(`${variable} targets ${value}; expected ${projectId}.`);
    }
  }
}

function webFirebaseConfig(projectId) {
  const optionsPath = path.resolve(
    __dirname,
    '..',
    '..',
    'lib',
    'firebase_options.dart',
  );
  const source = fs.readFileSync(optionsPath, 'utf8');
  const webBlock = source.match(
    /static const FirebaseOptions web = FirebaseOptions\(([\s\S]*?)\n  \);/,
  )?.[1];
  const apiKey = webBlock?.match(/apiKey:\s*'([^']+)'/)?.[1];
  const appId = webBlock?.match(/appId:\s*'([^']+)'/)?.[1];
  const configuredProject = webBlock?.match(/projectId:\s*'([^']+)'/)?.[1];
  if (!apiKey || !appId || configuredProject !== projectId) {
    throw new Error('Web Firebase configuration is missing or targets another project.');
  }
  return {
    apiKey,
    appId,
    authDomain: `${projectId}.firebaseapp.com`,
    projectId,
  };
}

function normalizedScopes(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(value.map((scope) => String(scope)))].sort();
}

function sameScopes(actual, expected) {
  return JSON.stringify(normalizedScopes(actual))
    === JSON.stringify([...expected].sort());
}

function privilegedClaimsMatch(claims, expected) {
  return claims.admin === expected.admin
    && claims.developer === expected.developer
    && sameScopes(claims.adminScopes, expected.adminScopes);
}

function permissionDenied(error) {
  return String(error?.code || '').toLowerCase().includes('permission-denied');
}

function safeError(error) {
  return String(error?.code || error?.name || 'unknown-error');
}

async function expectAllowed(rows, details, operation) {
  try {
    await operation();
    rows.push({
      ...details,
      actualResult: 'ALLOWED',
      status: 'PASS',
    });
  } catch (error) {
    rows.push({
      ...details,
      actualResult: `ERROR:${safeError(error)}`,
      status: 'FAIL',
    });
  }
}

async function expectDenied(rows, details, operation) {
  try {
    await operation();
    rows.push({
      ...details,
      actualResult: 'ALLOWED',
      status: 'FAIL',
    });
  } catch (error) {
    rows.push({
      ...details,
      actualResult: permissionDenied(error)
        ? 'DENIED:permission-denied'
        : `ERROR:${safeError(error)}`,
      status: permissionDenied(error) ? 'PASS' : 'FAIL',
    });
  }
}

async function verifiedClient({ firebaseConfig, identityType, uid, expected }) {
  const authRecord = await admin.auth().getUser(uid);
  if (authRecord.disabled) {
    throw new Error(`${identityType} Auth account is disabled.`);
  }
  if (!privilegedClaimsMatch(authRecord.customClaims || {}, expected)) {
    throw new Error(`${identityType} trusted Auth claims do not match approval.`);
  }

  const clientApp = initializeApp(
    firebaseConfig,
    `sec01-${identityType.toLowerCase().replaceAll(' ', '-')}`,
  );
  const auth = getAuth(clientApp);
  await setPersistence(auth, inMemoryPersistence);

  let customToken = await admin.auth().createCustomToken(uid);
  const credential = await signInWithCustomToken(auth, customToken);
  customToken = '';
  if (credential.user.uid !== uid) {
    throw new Error(`${identityType} custom-token sign-in returned another UID.`);
  }

  let tokenResult = await credential.user.getIdTokenResult(true);
  const issuedAt = Date.parse(tokenResult.issuedAtTime);
  const tokenClaimsMatch = privilegedClaimsMatch(tokenResult.claims, expected);
  tokenResult = null;
  if (!tokenClaimsMatch || !Number.isFinite(issuedAt) || Date.now() - issuedAt > 300000) {
    throw new Error(`${identityType} fresh ID-token claims failed verification.`);
  }

  return {
    auth,
    clientApp,
    db: getFirestore(clientApp),
    identityType,
    uid,
  };
}

async function main() {
  const projectId = projectFromArgs(process.argv.slice(2));
  assertAmbientProjectIsSafe(projectId);
  const firebaseConfig = webFirebaseConfig(projectId);

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
    serviceAccountId: TOKEN_SIGNER_SERVICE_ACCOUNT,
  });

  const rows = [];
  const clients = [];
  let blocker = null;

  const unauthenticatedApp = initializeApp(firebaseConfig, 'sec01-unauthenticated');
  const unauthenticatedDb = getFirestore(unauthenticatedApp);
  await expectDenied(rows, {
    identityType: 'UNAUTHENTICATED',
    authorityExpected: 'no roles authority',
    operationPath: 'admin_audit_logs (limit 1)',
    expectedResult: 'DENIED',
  }, () => getDocs(query(
    collection(unauthenticatedDb, 'admin_audit_logs'),
    limit(1),
  )));
  await deleteApp(unauthenticatedApp);

  try {
    const developer = await verifiedClient({
      firebaseConfig,
      identityType: 'DEVELOPER',
      uid: DEVELOPER_UID,
      expected: {
        admin: true,
        developer: true,
        adminScopes: ALL_SCOPES,
      },
    });
    clients.push(developer);

    const applicationAdmin = await verifiedClient({
      firebaseConfig,
      identityType: 'ADMIN',
      uid: ADMIN_UID,
      expected: {
        admin: true,
        developer: false,
        adminScopes: ADMIN_SCOPES,
      },
    });
    clients.push(applicationAdmin);

    await expectAllowed(rows, {
      identityType: 'DEVELOPER',
      authorityExpected: 'roles read',
      operationPath: 'admin_audit_logs (limit 1)',
      expectedResult: 'ALLOWED',
    }, () => getDocs(query(collection(developer.db, 'admin_audit_logs'), limit(1))));

    await expectAllowed(rows, {
      identityType: 'ADMIN',
      authorityExpected: 'orders read',
      operationPath: 'orders where storeId=sincerelysea (limit 1)',
      expectedResult: 'ALLOWED',
    }, () => getDocs(query(
      collection(applicationAdmin.db, 'orders'),
      where('storeId', '==', 'sincerelysea'),
      limit(1),
    )));

    await expectAllowed(rows, {
      identityType: 'ADMIN',
      authorityExpected: 'finance read',
      operationPath: 'sales_reports (limit 1)',
      expectedResult: 'ALLOWED',
    }, () => getDocs(query(collection(applicationAdmin.db, 'sales_reports'), limit(1))));

    await expectAllowed(rows, {
      identityType: 'ADMIN',
      authorityExpected: 'community read',
      operationPath: 'reports (limit 1)',
      expectedResult: 'ALLOWED',
    }, () => getDocs(query(collection(applicationAdmin.db, 'reports'), limit(1))));

    await expectDenied(rows, {
      identityType: 'ADMIN',
      authorityExpected: 'no roles authority',
      operationPath: 'admin_audit_logs (limit 1)',
      expectedResult: 'DENIED',
    }, () => getDocs(query(
      collection(applicationAdmin.db, 'admin_audit_logs'),
      limit(1),
    )));

    for (const client of clients) {
      await expectAllowed(rows, {
        identityType: client.identityType,
        authorityExpected: 'authenticated self-profile read',
        operationPath: `users/{self}`,
        expectedResult: 'ALLOWED',
      }, () => getDoc(doc(client.db, 'users', client.uid)));
    }

  } catch (error) {
    blocker = String(error?.message || error);
  } finally {
    for (const client of clients) {
      await signOut(client.auth).catch(() => {});
      await deleteApp(client.clientApp).catch(() => {});
    }
  }

  const failed = rows.filter((row) => row.status !== 'PASS');
  process.stdout.write(`${JSON.stringify({
    projectId,
    mode: 'READ ONLY',
    freshTokenClaimsVerified: blocker === null && failed.length === 0,
    blocker,
    rows,
    summary: {
      passed: rows.length - failed.length,
      failed: failed.length,
    },
  }, null, 2)}\n`);

  if (blocker !== null || failed.length > 0) {
    throw new Error(
      blocker || `${failed.length} SEC-01 production smoke case(s) failed.`,
    );
  }
}

main().catch((error) => {
  fail(error?.stack || String(error));
});
