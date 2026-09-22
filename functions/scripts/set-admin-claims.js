const admin = require('firebase-admin');

const EXPECTED_PROJECT_ID = 'gen-lang-client-0026437130';
const ADMIN_SCOPES = ['products', 'orders', 'finance', 'community', 'roles'];

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
}

function usage() {
  return [
    'Usage:',
    '  node scripts/set-admin-claims.js --project <project-id> --uid <uid>',
    '    --role <user|admin|developer> [--scopes <scope1,scope2|all>] [--confirm]',
    '',
    'Without --confirm the command is read-only and prints the proposed change.',
  ].join('\n');
}

function parseArgs(argv) {
  const options = { confirm: false };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--confirm') {
      options.confirm = true;
      continue;
    }
    if (!['--project', '--uid', '--role', '--scopes'].includes(arg)) {
      throw new Error(`Unknown argument: ${arg}`);
    }
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new Error(`Missing value for ${arg}`);
    }
    options[arg.slice(2)] = value;
    index += 1;
  }
  return options;
}

function validatedRequest(options) {
  if (options.project !== EXPECTED_PROJECT_ID) {
    throw new Error(
      `Refusing project ${options.project || '(missing)'}; expected ${EXPECTED_PROJECT_ID}.`,
    );
  }
  if (!options.uid || options.uid.length > 128 || /\s/.test(options.uid)) {
    throw new Error('A valid Firebase Auth UID is required explicitly.');
  }
  const role = String(options.role || '').trim().toLowerCase();
  if (!['admin', 'developer', 'user'].includes(role)) {
    throw new Error('An explicit role of user, admin, or developer is required.');
  }

  const rawScopes = options.scopes
    ? options.scopes.split(',').map((scope) => scope.trim().toLowerCase())
    : [];
  const unknownScopes = rawScopes.filter(
    (scope) => scope !== 'all' && !ADMIN_SCOPES.includes(scope),
  );
  if (unknownScopes.length > 0) {
    throw new Error(`Unknown admin scopes: ${unknownScopes.join(', ')}`);
  }
  if (role === 'admin' && rawScopes.length === 0) {
    throw new Error(`Admin requires explicit scopes or all: ${ADMIN_SCOPES.join(', ')}`);
  }
  if (role === 'developer' && rawScopes.join(',') !== 'all') {
    throw new Error('Developer requires --scopes all.');
  }
  if (role === 'user' && rawScopes.length > 0) {
    throw new Error('User role must not include --scopes.');
  }

  const scopes = rawScopes.includes('all')
    ? [...ADMIN_SCOPES]
    : [...new Set(rawScopes)];
  return { projectId: options.project, uid: options.uid, role, scopes };
}

function assertAmbientProjectIsSafe(projectId) {
  for (const variable of ['GOOGLE_CLOUD_PROJECT', 'GCLOUD_PROJECT']) {
    const value = process.env[variable];
    if (value && value !== projectId) {
      throw new Error(`${variable} targets ${value}; expected ${projectId}.`);
    }
  }
  if (process.env.FIREBASE_CONFIG) {
    let config;
    try {
      config = JSON.parse(process.env.FIREBASE_CONFIG);
    } catch {
      throw new Error('FIREBASE_CONFIG is present but is not valid JSON.');
    }
    if (config.projectId && config.projectId !== projectId) {
      throw new Error(`FIREBASE_CONFIG targets ${config.projectId}; expected ${projectId}.`);
    }
  }
}

async function main() {
  let options;
  let request;
  try {
    options = parseArgs(process.argv.slice(2));
    request = validatedRequest(options);
    assertAmbientProjectIsSafe(request.projectId);
  } catch (error) {
    fail(`${error.message}\n\n${usage()}`);
    return;
  }

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: request.projectId,
  });
  const user = await admin.auth().getUser(request.uid);
  const firestore = admin.firestore();
  const [publicProfile, legacyProfile] = await Promise.all([
    firestore.collection('users_public').doc(request.uid).get(),
    firestore.collection('users').doc(request.uid).get(),
  ]);
  if (!publicProfile.exists && !legacyProfile.exists) {
    throw new Error(`Firestore profile for ${request.uid} does not exist.`);
  }

  const claims = { ...(user.customClaims || {}) };
  const previousClaims = {
    admin: claims.admin === true,
    developer: claims.developer === true,
    adminScopes: Array.isArray(claims.adminScopes) ? claims.adminScopes : [],
  };
  delete claims.admin;
  delete claims.developer;
  delete claims.adminScopes;
  if (request.role === 'admin') {
    claims.admin = true;
    claims.adminScopes = request.scopes;
  } else if (request.role === 'developer') {
    claims.admin = true;
    claims.developer = true;
    claims.adminScopes = [...ADMIN_SCOPES];
  }

  process.stdout.write(`${JSON.stringify({
    projectId: request.projectId,
    uid: request.uid,
    previousClaims,
    requestedRole: request.role,
    requestedScopes: request.scopes,
    mode: options.confirm ? 'CONFIRMED WRITE' : 'DRY RUN - NO WRITES',
  }, null, 2)}\n`);

  if (!options.confirm) {
    process.stdout.write('Review the UID and identity manually, then rerun with --confirm.\n');
    return;
  }

  await admin.auth().setCustomUserClaims(request.uid, claims);
  await firestore.collection('users_private').doc(request.uid).set({
    uid: request.uid,
    role: request.role,
    adminScopes: request.role === 'user' ? [] : claims.adminScopes,
    authorizationSource: 'firebase_auth_custom_claims',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
  await firestore.collection('admin_audit_logs').add({
    action: 'admin_access_bootstrapped',
    source: 'local_admin_sdk',
    actorUid: 'trusted_local_operator',
    targetUid: request.uid,
    previousClaims,
    newRole: request.role,
    newScopes: request.role === 'user' ? [] : claims.adminScopes,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const verified = await admin.auth().getUser(request.uid);
  process.stdout.write(`${JSON.stringify({
    projectId: request.projectId,
    uid: request.uid,
    verifiedClaims: {
      admin: verified.customClaims?.admin === true,
      developer: verified.customClaims?.developer === true,
      adminScopes: verified.customClaims?.adminScopes || [],
    },
    tokenRefreshRequired: true,
  }, null, 2)}\n`);
}

main().catch((error) => {
  fail(error?.stack || String(error));
});
