const admin = require('firebase-admin');

const EXPECTED_PROJECT_ID = 'gen-lang-client-0026437130';
const LEGACY_ROLE_VARIANTS = [
  'admin',
  'developer',
  'Admin',
  'Developer',
  'ADMIN',
  'DEVELOPER',
];

function fail(message) {
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
}

function projectFromArgs(argv) {
  if (argv.length !== 2 || argv[0] !== '--project') {
    throw new Error(
      'Usage: node scripts/inventory-legacy-admins.js --project <project-id>',
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

async function main() {
  const projectId = projectFromArgs(process.argv.slice(2));
  assertAmbientProjectIsSafe(projectId);
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });

  const snapshot = await admin.firestore()
    .collection('users')
    .where('role', 'in', LEGACY_ROLE_VARIANTS)
    .get();

  process.stdout.write(`${JSON.stringify({
    projectId,
    mode: 'READ ONLY',
    candidateCount: snapshot.size,
    warning: 'Legacy role metadata is untrusted. Do not provision claims without manual identity approval.',
  })}\n`);

  for (const document of snapshot.docs) {
    const data = document.data();
    let authSummary;
    try {
      const user = await admin.auth().getUser(document.id);
      authSummary = {
        exists: true,
        disabled: user.disabled,
        trustedClaims: {
          admin: user.customClaims?.admin === true,
          developer: user.customClaims?.developer === true,
          adminScopes: Array.isArray(user.customClaims?.adminScopes)
            ? user.customClaims.adminScopes
            : [],
        },
      };
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') throw error;
      authSummary = { exists: false };
    }

    process.stdout.write(`${JSON.stringify({
      uid: document.id,
      username: data.username || '',
      legacyRole: data.role || '',
      legacyScopes: Array.isArray(data.adminScopes) ? data.adminScopes : [],
      authorizationSource: data.authorizationSource || 'legacy_or_unknown',
      auth: authSummary,
      decision: 'MANUAL_REVIEW_REQUIRED',
    })}\n`);
  }
}

main().catch((error) => {
  fail(error?.stack || String(error));
});
