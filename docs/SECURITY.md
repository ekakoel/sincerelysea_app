# SincerelySea Security Operations

## Role authority

Firebase Authentication custom claims are the sole authorization source for privileged application access:

- `developer: true` grants developer authority and all supported admin scopes.
- `admin: true` grants admin authority.
- `adminScopes: string[]` limits an admin to `products`, `orders`, `finance`, `community`, and/or `roles`.
- An admin claim with a missing or empty scope list retains all scopes for compatibility; only trusted Admin SDK code can create that state.

The `role` and `adminScopes` fields in `users/{uid}` are display and migration metadata only. Firestore Rules do not use them for authorization. Clients cannot create privileged values or add, remove, or change `role`, `adminScopes`, `isAdmin`, `isDeveloper`, `permissions`, `official`, `isOfficial`, `endorsement`, `accountVerified`, or `verifiedOwner`.

## Trusted role changes

The future backend website may call the deployed callable function `setUserAdminAccess`. Flutter has no user-facing caller after MOB-01. The function:

1. requires an authenticated caller with trusted `developer` or `admin` plus the `roles` scope;
2. rejects self-access changes;
3. permits only a developer to grant, alter, or remove developer access;
4. validates the requested role and scopes;
5. preserves unrelated custom claims while replacing SincerelySea role claims;
6. mirrors non-authoritative display metadata to Firestore and writes `admin_audit_logs`.

## Mobile management boundary

Flutter is customer-facing for every Firebase identity. An account with `admin`, `developer`, or `adminScopes` claims receives the same mobile navigation and settings as an ordinary customer. The application contains no management route, role/scope presentation, catalog editor, fulfilment control, report moderation, finance dashboard, audit-log UI, or `setUserAdminAccess` caller.

This product boundary does not replace authorization. Claim-aware Firestore Rules, trusted Admin SDK scripts, the deployed callable, and `admin_audit_logs` remain intact for the future backend management plane.

A target user must exist in both Firebase Auth and `users/{uid}`. A changed user must sign out and back in, or otherwise force an ID-token refresh, before the new authorization is visible to Flutter and Firestore Rules.

## Trusted financial reporting (SEC-02)

Flutter no longer writes `journal_entries` or `sales_reports`. Order creation and the first transition into `cancelled` are observed by Cloud Functions, which use the Admin SDK to create the journal event and increment the UTC daily report in one Firestore transaction.

Each event uses a deterministic journal ID, `order_created_{orderId}` or `order_cancelled_{orderId}`. An existing event document makes a retried invocation a no-op, preventing duplicate report increments. Firestore Rules retain the existing `finance`-scope read policy and deny every client create, update, and delete on both financial collections.

At the SEC-02 checkpoint, checkout totals and inventory remained client-driven debt for SEC-03. SEC-02 reporting has not been deployed to production. SEC-01 remains 7/8 with its existing fresh-session smoke blocker.

## Trusted checkout and order state (SEC-03)

Flutter now submits only product IDs, quantities, shipping/contact input, and a per-attempt `checkoutRequestId` to `createCustomerOrder`. The callable loads official-store product documents, validates availability and inventory, calculates authoritative item snapshots and totals, decrements ready stock, and creates the pending order in one transaction. A UID-scoped deterministic order ID makes retries return the same logical order without another stock decrement or another SEC-02 create event.

`cancelCustomerOrder` verifies authentication, ownership, trusted order provenance, and pending status before restoring ready stock and changing the order to `cancelled` in one transaction. A repeated cancellation returns the existing cancelled result without restoring stock again. The existing SEC-02 document triggers remain the only financial reporting implementation.

Firestore Rules preserve own-order and scoped backend-admin reads but deny every client create, update, and delete on `orders`. Ordinary customers remain unable to mutate products or stock. Existing legacy orders remain readable; pending legacy orders are intentionally rejected by trusted cancellation because their item and stock snapshots were client-authored and cannot be safely restored without operator reconciliation. No production Rules or Functions deployment or production-data migration occurred.

SEC-01 remains 7/8 with its production fresh-token smoke pending. SEC-02 and SEC-03 are implemented and tested in the current source tree but are not deployed.

## First admin bootstrap

Run bootstrap only from a trusted operator workstation or CI environment with Google Application Default Credentials authorized for the intended Firebase project. Never place a service-account key in this repository.

The command refuses every project except `gen-lang-client-0026437130`, requires the UID, role, and scopes explicitly, and defaults to a read-only dry run. From `functions/`, first review the proposed change:

```powershell
$env:GOOGLE_CLOUD_PROJECT = "gen-lang-client-0026437130"
gcloud auth application-default login
node scripts/set-admin-claims.js --project gen-lang-client-0026437130 --uid <verified-firebase-auth-uid> --role developer --scopes all
```

Only after a human verifies that UID against organizational records, rerun the same command with `--confirm`:

```powershell
node scripts/set-admin-claims.js --project gen-lang-client-0026437130 --uid <verified-firebase-auth-uid> --role developer --scopes all --confirm
```

Use a UID copied from Firebase Authentication, not an email address. Inspect the returned verified claims, Firestore user mirror, and audit-log entry, then have the user sign out and back in. A scoped admin grant uses, for example, `--role admin --scopes products,orders`. A revocation uses `--role user` with no `--scopes`. Every mutation still requires `--confirm`.

The script supplies `projectId` directly to the Admin SDK and rejects conflicting `GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`, or `FIREBASE_CONFIG` values. Credentials remain external to the repository.

## Read-only legacy inventory

Legacy `role` values are untrusted candidates, not migration approval. After configuring Application Default Credentials, run:

```powershell
node scripts/inventory-legacy-admins.js --project gen-lang-client-0026437130
```

The inventory performs no writes. It emits UID, public username, legacy role/scopes, authorization-source marker, Auth-record existence/disabled state, and current trusted role claims. It intentionally omits email addresses and tokens. Review each candidate using Firebase Authentication and organizational records:

```text
LEGACY ROLE -> MANUAL IDENTITY VERIFICATION -> APPROVED?
  NO  -> no claim grant; investigate metadata
  YES -> dry-run bootstrap -> second human review -> --confirm
```

## Legacy role migration

Before deploying claim-authoritative Rules to production:

1. Run the read-only inventory and record all candidate documents whose legacy `role` is `admin` or `developer`.
2. Independently verify each identity and its least-privilege scopes; a legacy field is evidence to review, not proof of authorization.
3. Run the bootstrap dry run and use `--confirm` only for explicitly approved identities. Do not bulk-copy unverified legacy roles into claims.
4. Revoke unexpected legacy values by assigning `user`; investigate those accounts and relevant audit history.
5. Deploy Cloud Functions first, then Firestore Rules and the Flutter client.
6. Require migrated privileged users to refresh their token and verify one permitted and one denied operation.
7. Retain the legacy mirror temporarily for UI display and migration reconciliation. Remove it in a separately tested cleanup after all consumers are migrated.

There are no administrator emails, UID allowlists, or credentials hardcoded in application code. Approved bootstrap UIDs may be retained in this operational record as deployment evidence; authorization still comes only from Firebase Auth custom claims.

## Production activation order

1. Confirm Firebase CLI login and explicit target `gen-lang-client-0026437130`.
2. Confirm the Cloud Functions API is enabled, enumerate deployed Functions, and ensure a targeted deployment will not delete unrelated resources.
3. Validate Functions and Rules locally using the declared Node 22 runtime.
4. Deploy only `setUserAdminAccess`.
5. Run the read-only legacy inventory and manually approve a trusted UID.
6. Dry-run, confirm, and verify that UID's Auth custom claims.
7. Deploy only Firestore Rules.
8. Refresh the approved account's ID token.
9. Run harmless production checks for privileged success and customer/unauthenticated denial, then verify an ordinary profile operation.

Do not deploy claim-only Rules before at least one legitimate privileged identity has verified claims. Do not use a broad Functions deployment until the existing deployed inventory is known.

## Current production activation state

On 2026-09-20, Firebase CLI 15.4.0 was authenticated and selected `gen-lang-client-0026437130`, matching `.firebaserc`, `firebase.json`, and client configuration. The earlier `Failed to find location of Firebase Functions SDK` error was caused by an incomplete `functions/node_modules` installation: the packages could be partially resolved, but the required `node_modules/.bin/firebase-functions` SDK shim was absent. A lockfile-consistent clean install under Node 22 and npm 10 restored the shim and a clean dependency tree.

The Functions runtime is now Node 22. The installed `firebase-functions` 5.1.1 and `firebase-admin` 12.7.0 remain compatible with the current CommonJS v2 source and Firebase CLI discovery. Their major-version upgrades were deliberately deferred because they were not required to repair the installation and would add unrelated compatibility risk. On this workstation, source initialization exceeded Firebase CLI's default discovery timeout, so validation and deployment used `FUNCTIONS_DISCOVERY_TIMEOUT=120`; this affects local CLI analysis only, not production execution.

The targeted deployment created only `setUserAdminAccess`. Production inventory confirms an active v2 callable in `us-central1` on `nodejs22`; the other seven local exports were discovered but not deployed. The Firebase CLI returned a nonzero final exit after successful Function creation because it would not create an Artifact Registry cleanup policy without `--force`. That operational warning did not roll back the Function, but the repository should establish a cleanup policy separately to prevent old build images accumulating.

The legacy inventory tool was statically audited and validated to reject a non-production project before Admin SDK initialization. It uses only a Firestore query and Firebase Auth `getUser` lookups and does not emit email addresses, phone numbers, or tokens. Google Cloud CLI access and Application Default Credentials were verified against `gen-lang-client-0026437130`, and the read-only production inventory completed with two legacy privileged candidates.

The human operator independently verified and explicitly approved both candidate identities. The bootstrap tool was re-audited to require the exact project, explicit UID/role/scopes, a read-only dry run, and `--confirm` for mutation; it preserves unrelated claims and verifies Auth claims after mutation. Both approved changes were dry-run, reviewed, confirmed, and independently re-read through the inventory tool:

- `WT0trMBt9zNaMFYXQ61cs67K1x53` is the technical/system developer. Firebase Auth verifies `admin: true`, `developer: true`, and `adminScopes: [products, orders, finance, community, roles]` on an enabled account.
- `4RWo2A35L2NYavF4NuD0VwINOmB2` is the application administration/testing account. Firebase Auth verifies `admin: true`, `developer: false`, and `adminScopes: [products, orders, finance, community]` on an enabled account.

The admin scope set covers every currently implemented operational area: official catalog, order fulfilment, transaction reporting, and community moderation. The `roles` scope is intentionally excluded because it delegates privileged access and remains with the approved developer account. This is an account-level least-privilege assignment within the existing five-scope architecture, not a new RBAC design.

The bootstrap retained the non-authoritative Firestore role/scope mirrors and created audit records. Immediately before Rules deployment, the read-only inventory reconfirmed both enabled accounts and their exact approved claims. The complete Rules audit confirmed that privileged decisions use `request.auth.token` only and that customer profile writes cannot create, change, add, or remove protected authority fields.

The pre-deployment Firestore Emulator gate passed all nine cases after expanding the assertions for explicit developer-role rejection, all listed protected authority fields, authority-field add/change/removal, and both claimed admin and developer access. On 2026-09-20, the targeted command `firebase deploy --only firestore:rules --project gen-lang-client-0026437130` compiled and released only `firestore.rules`. The active `cloud.firestore` release was independently verified through the read-only Firebase Rules API as ruleset `ed2fdf20-027d-4e7b-b271-51033f9d6c16`, updated at `2026-09-19T23:11:01.939251Z`.

The compiler reported non-blocking warnings associated with the existing unused `isFollower` helper and the unused `postId` parameter; compilation and production release succeeded. No Function, index, Storage Rules, Hosting, Flutter application, or claim change was deployed. Firestore role metadata must not be used as a stale-session fallback.

## Production smoke attempt

The operator reported signing out and back in so the privileged application sessions could refresh their claims. Those application sessions were not reachable from this verification environment, and no connected device or running application process was detected. The trusted Admin SDK precheck nevertheless reconfirmed both enabled Auth accounts and their exact approved custom claims before the smoke attempt.

The repository now includes a project-locked read-only verifier at `functions/scripts/verify-sec01-production.js`. It accepts only `gen-lang-client-0026437130`, imports no Firestore mutation APIs, uses in-memory client authentication, emits no token or credential, and defines only bounded reads. The intended short-lived custom-token flow stopped before privileged Firestore access because operator ADC lacks `iam.serviceAccounts.signBlob` on the existing Firebase Admin service account. No IAM permission was granted and no password, ID token, refresh token, or service-account key was requested.

| Identity type | Authority expected | Operation/path | Expected result | Actual result | Status |
| --- | --- | --- | --- | --- | --- |
| Developer | `roles` read | `admin_audit_logs`, limit 1 | Allowed | Not run: fresh client session unavailable | Blocked |
| Admin | `orders` read | official-store `orders`, limit 1 | Allowed | Not run: fresh client session unavailable | Blocked |
| Admin | `finance` read | `sales_reports`, limit 1 | Allowed | Not run: fresh client session unavailable | Blocked |
| Admin | `community` read | `reports`, limit 1 | Allowed | Not run: fresh client session unavailable | Blocked |
| Admin | no `roles` authority | `admin_audit_logs`, limit 1 | Denied | Not run: fresh client session unavailable | Blocked |
| Developer | ordinary authenticated access | own `users/{uid}` document | Allowed | Not run: fresh client session unavailable | Blocked |
| Admin | ordinary authenticated access | own `users/{uid}` document | Allowed | Not run: fresh client session unavailable | Blocked |
| Unauthenticated | no `roles` authority | `admin_audit_logs`, limit 1 | Denied | `permission-denied` | Pass |

No suitable normal-customer production session was available, so no customer identity was created or selected merely for testing. The active production Rules, complete source audit, and nine-case Emulator suite continue to establish that Firestore role metadata is non-authoritative, normal users cannot perform privileged operations, safe profile updates remain allowed, and protected authority fields cannot be created or mutated. Those results supplement but do not replace the required fresh-token developer/admin production cases.

The smoke attempt performed no production write, deletion, notification, order/product/finance mutation, role/claim change, Rules deployment, or IAM change. SEC-01 remains at 7/8 and blocked until the matrix is executed from a reachable fresh signed-in application session or another pre-approved secure token-signing environment.

## Rollback and recovery

To revoke a compromised account, use the trusted script with role `user`, revoke the user's refresh tokens in Firebase Auth, and review `admin_audit_logs`. Do not restore Rules that trust the Firestore role mirror. If the callable deployment fails, continue using the local trusted script until the backend is repaired; this preserves the same custom-claim authority boundary.

Auth claims and Firestore writes cannot be committed in one cross-service transaction. Claims are updated first so authorization is correct even if mirror/audit writing fails. If a command reports failure after the Auth update, inspect the target claims and reconcile the Firestore mirror/audit entry before retrying.

## SEC-01 verification

The Firestore Emulator suite covers these required cases:

- a normal customer can create a safe profile;
- registration cannot set `role=admin` or `role=developer`;
- a customer cannot add, change, or remove authority fields on an existing profile;
- a customer cannot create any listed privileged, official, endorsement, or verification authority field;
- an ordinary profile update remains allowed;
- claim-authorized admin and developer identities can perform an admin-protected product operation;
- unauthenticated access is denied;
- a signed-in non-admin is denied;
- a forged legacy Firestore developer role does not grant authority.

Production Rules deployment and unauthenticated privileged-access denial are complete. Fresh-token developer success, scoped-admin success, admin `roles` denial, and authenticated ordinary-profile reads remain blocked by the unavailable client-session execution path. SEC-01 is not complete until those production checks are recorded.
