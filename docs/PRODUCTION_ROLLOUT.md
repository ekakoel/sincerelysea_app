# SincerelySea Security Baseline and Production Rollout

**Authority:** canonical SEC-01 through SEC-07 status, production prerequisites, deployment order, rollback boundaries, and release gates.

**Checkpoint date:** 2026-09-21.

**Production action in this checkpoint:** none.

## Frozen security baseline

SEC-01 through SEC-07 define the security baseline for all subsequent mobile development. Future mobile phases must preserve these trust boundaries. Any change that weakens them requires an explicit security phase and regression tests.

The approved architecture is:

- Flutter mobile is an untrusted, customer-only application for every identity, including identities that also hold admin or developer claims.
- The Admin SDK, trusted Cloud Functions, operator scripts, and future backend website form the privileged management plane.
- Firebase Auth custom claims establish privileged identity and scope.
- App Check attests the application/client and never replaces identity or authorization.
- Firestore Rules authorize document access independently of App Check.
- Storage Rules authorize media access independently of App Check.
- Cloud Functions and Admin SDK code own trusted business operations, authoritative commerce calculations, and privileged mutations.

Mobile development must not restore admin/seller management, direct client order writes, client financial writes, cross-user private-profile reads, weaker community visibility/block enforcement, weaker Storage ownership, or production App Check bypasses.

## Canonical security status

| Phase | Canonical status | Source and tests | Migration/deployment | Production verification |
| --- | --- | --- | --- | --- |
| SEC-01 | **PARTIAL 7/8** | authorization boundary implemented and tested | approved claims, `setUserAdminAccess`, and claim-authoritative Firestore Rules have recorded targeted production activation | fresh-token privileged smoke matrix pending |
| SEC-02 | **IMPLEMENTED + TESTED** | trusted financial event derivation complete | not deployed | not production-verified |
| SEC-03 | **IMPLEMENTED + TESTED** | trusted checkout/cancellation complete | not deployed; legacy pending orders unresolved | not production-verified |
| SEC-04 | **SOURCE/TEST COMPLETE** | public/private profile split and legal/support alignment complete | profile backfill and coordinated deployment pending | not production-verified |
| SEC-05 | **IMPLEMENTED + TESTED** | visibility/block enforcement complete | legacy visibility normalization and deployment pending | not production-verified |
| SEC-06 | **IMPLEMENTED + TESTED** | media policy, Rules, and tests complete | support/token/media remediation and deployment pending | not production-verified |
| SEC-07 | **SOURCE/TEST COMPLETE** | client providers and protected-callable configuration complete | provider registration, callable/service enforcement rollout, and release configuration pending | real-device validation pending |

No later phase may infer migration, deployment, or production verification from source/test completion.

## Production prerequisite register

### Commerce

- Reconcile every legacy pending order before the SEC-03 cutover.
- Identify client-authored item snapshots, prices, totals, stock restoration data, and provenance that the trusted cancellation path cannot safely accept.
- Resolve each record through an operator-approved outcome; an unexplained record is a release blocker.

Reason: historical pending orders may be incompatible with the server-authoritative order and stock model.

### User privacy

- Backfill `users/{uid}` into `users_public/{uid}` and `users_private/{uid}` without changing the UID.
- Copy only the SEC-04 allowlisted community fields into `users_public`.
- Keep account/contact and non-authoritative role mirrors private.
- Verify that no email, phone, authorization metadata, or other private field leaks into the public document.
- Keep legacy records until counts, field classification, application compatibility, and rollback evidence are approved; cleanup is a later operation.

### Community

- Inventory customer posts without `visibility`.
- Normalize them using an operator-approved conservative policy compatible with SEC-05.
- Preserve legacy official product-post compatibility separately from customer community content.
- Do not broaden visibility merely because historical intent is unknown.

### Storage and media

- Inventory legacy support records, Storage paths, tokenized URLs, ownership, and missing objects.
- Backfill validated owner-bound support paths where evidence permits.
- Revoke exposed download tokens when required and verify application compatibility.
- Normalize legacy ownership/path data only where the inventory proves it is necessary.
- Preserve the accepted limitation: flat legacy post-media paths and previously shared token URLs cannot retroactively inherit SEC-05 document visibility/block semantics. A post-aware path or trusted-delivery redesign is separate work.

### App Check and release identity

- Configure the private Android release signing identity outside the repository.
- Register/configure Play Integrity for the production Android app identity.
- Enable the iOS App Attest capability/provisioning and configure App Attest with the documented DeviceCheck fallback.
- Validate legitimate Android and iOS release builds on real devices.
- Stage callable, Firestore, and Storage enforcement; do not enable all service enforcement at once.

## Migration and operator-script readiness

- `functions/scripts/inventory-legacy-admins.js`: **READY** for its narrow, read-only SEC-01 legacy-role inventory; it is not a general rollout inventory.
- `functions/scripts/set-admin-claims.js`: **READY** for project-locked, dry-run-by-default claim changes requiring explicit `--confirm`.
- `functions/scripts/verify-sec01-production.js`: **NEEDS OPERATOR REVIEW** and reachable fresh application sessions or a separately approved token-signing path.
- Legacy pending-order reconciliation: **NEEDS SCRIPT / NEEDS OPERATOR REVIEW**.
- `users` to `users_public` + `users_private` backfill: **NEEDS SCRIPT / NEEDS OPERATOR REVIEW**.
- Legacy post visibility normalization: **NEEDS SCRIPT / NEEDS OPERATOR REVIEW**.
- Storage/support path and token remediation: **NEEDS SCRIPT / NEEDS OPERATOR REVIEW**; some token revocation and console operations may remain **MANUAL**.
- Android/iOS provider registration and Firebase service enforcement: **MANUAL** operator actions.

No migration script was added at this checkpoint. Exact production data shapes, record classifications, token exposure, and operator-approved mappings must be established first. Any future migration script must be non-destructive, project-locked, dry-run by default, explicitly confirmed for production writes, idempotent where practical, auditable, and safely re-runnable.

## Safe rollout sequence

### Stage 0 - Backup, inventory, and release preparation

1. Confirm the exact Firebase project, operator identities, least-privilege access, deployed Function inventory, active Rules versions, and client versions in use.
2. Create approved Firestore/Storage backup or export evidence before mutation. Record project ID, timestamp, export location, retention/access controls, and object/document counts. Do not place exports or credentials in the repository.
3. Produce read-only inventories for legacy pending orders, mixed user documents, missing post visibility, support/media paths and token URLs, and App Check/provider readiness.
4. Review unexplained records and approve the mapping/rollback plan before any write-capable script is enabled.

No backup, export, or production inventory was executed by this checkpoint.

### Stage 1 - Additive reconciliation and backfill

Run in this order:

1. reconcile legacy pending orders;
2. backfill `users_public` and `users_private`;
3. normalize legacy community visibility;
4. remediate support/media paths and exposed tokens where required.

Each step must begin with a reviewed dry run, emit counts and exceptions, preserve an audit artifact, be idempotent/re-runnable where practical, and stop on unexplained records. Prefer additive writes, verification, controlled cutover, and cleanup later. Destructive deletion is not part of this sequence.

### Stage 2 - Trusted backend

1. Re-enumerate deployed Functions and use explicit targets; never use an unreviewed broad deploy.
2. Deploy the reviewed SEC-02 financial triggers and SEC-03 customer operations required by the compatible app.
3. Treat deployment of `hardDeleteAccount`, `createCustomerOrder`, and `cancelCustomerOrder` as the first App Check enforcement step because current source declares native `enforceAppCheck: true`.
4. Deploy protected callables only after production providers, release identities, legitimate-client compatibility, and rollback authority are ready.
5. Verify Function health, authentication denial, App Check denial, idempotency, and business-operation success before Rules cutover.

### Stage 3 - Firestore and Storage Rules

Deploy only after data compatibility, trusted Functions, release-candidate compatibility, and prior Rules rollback artifacts are verified. Use targeted Firestore/Storage Rules deployments, then immediately run allow/deny smoke cases. Do not weaken Rules to compensate for App Check or client failures.

### Stage 4 - Customer application

Release the compatible signed Flutter build in the coordinated cutover window after backend and Rules prerequisites are ready. Confirm the production build points to `gen-lang-client-0026437130`, uses production App Check providers, and does not depend on a data contract unavailable in production. Monitor registration, profile, community, commerce, media, crash, and callable failure signals.

### Stage 5 - Staged App Check service enforcement

1. Observe App Check metrics with registered production providers.
2. Validate legitimate Android/iOS traffic and protected callable success/rejection.
3. Confirm protected callable enforcement after the Function deployment.
4. Enable Firestore enforcement, validate, and monitor.
5. Enable Storage enforcement, validate, and monitor.

Record the operator, timestamp, affected product, metrics, smoke evidence, and rollback decision at each step. Firebase Console service enforcement remains a manual operator action.

### Stage 6 - Closeout

Run the complete smoke matrix, reconcile migration/deployment counts, close SEC-01 only after its fresh-token cases pass, record active Rules/Function/app versions, and retain rollback artifacts. Schedule destructive legacy cleanup as a separate reviewed change after the observation window.

## Rollback boundaries

Rollback is a controlled incident response, not proof that destructive migration is reversible.

- **Functions failure:** stop affected operations, use explicit targets to redeploy the last known-good reviewed Function version, and verify Auth/Rules still deny unsafe direct client writes. Do not delete unrelated Functions or restore client authority.
- **Firestore Rules failure:** redeploy the last known-good secure Rules artifact, run deny-first smoke tests, and pause incompatible client operations. Never restore Rules that trust mutable document roles or client order/finance writes.
- **Storage Rules failure:** redeploy the last known-good secure Storage Rules artifact and pause uploads if necessary. Never open public or cross-user writes as a workaround.
- **Profile backfill issue:** stop the backfill/cutover, retain legacy `users` documents, compare audit output, correct additive destination records, and rerun verification. Cleanup remains deferred.
- **Community normalization issue:** stop normalization, preserve its before-state audit, keep unknown legacy customer posts on the conservative owner-only interpretation, and correct records through an approved rerun.
- **App Check legitimate-client rejection:** temporarily disable only the affected App Check enforcement layer when approved, restore/repair provider or release configuration, and retain Firebase Auth plus Firestore/Storage Rules. Never weaken Rules because attestation fails.

Token revocation and other destructive media actions require their own before-state inventory and incident-specific recovery plan; they must not be described as trivially reversible.

## Pre-deploy acceptance gate

Every item is mandatory before the coordinated rollout:

- release candidate commit/tag has a clean or explicitly approved intended diff;
- `flutter analyze` passes;
- complete `flutter test` passes;
- Functions lint passes under the declared Node 22 runtime;
- Firestore, Storage, and Functions emulators load successfully;
- the complete security regression suite passes;
- every migration dry run and exception list is reviewed and signed off;
- production inventories and backup/export evidence are reviewed;
- rollback owners, artifacts, authority, and decision thresholds are approved;
- a signed Android release build and an iOS release archive are generated from the candidate;
- Android release signing and Play Integrity registration are ready;
- iOS provisioning/App Attest configuration is ready;
- real-device App Check validation succeeds on supported Android and iOS devices;
- reachable fresh privileged sessions are available for the final SEC-01 production smoke.

### Checkpoint gate state

**NOT READY.** Source regression checks were last recorded as passing on 2026-09-21, but there is no release-candidate commit/tag, migration script/dry-run evidence, coordinated production inventory/export review, approved rollout rollback record, signed Android/iOS release artifact, completed provider registration, real-device validation, or reachable fresh-token SEC-01 smoke session.

## Post-deploy smoke matrix

### Authentication

- Register/login and logout succeed; Google login succeeds when enabled.
- The authenticated customer profile loads without exposing private data.

### Community

- Create a customer post and verify public, follower, and private reads.
- Verify follow-request approval, symmetric block behavior, comments/replies, and direct blocked-post denial.

### Privacy

- The owner can read their `users_private` document.
- Another signed-in customer is denied that private document.
- Allowed `users_public` reads work without private/authority-field leakage.

### Commerce and finance

- Browse an official product and create checkout through the trusted callable.
- Verify server-authoritative total/snapshot, one stock decrement, order history, pending cancellation, one stock restoration, and exactly one financial event per logical event/retry.

### Storage

- Profile/post uploads succeed for the owner with accepted MIME/size.
- Cross-user writes and official-media customer writes are denied.
- Support media remains owner-private.

### App Check

- Valid Android and iOS real devices obtain attestation and complete protected callables.
- Missing/invalid/unattested clients are rejected after the relevant enforcement step.
- Firestore and Storage legitimate traffic remains healthy after each separate service-enforcement change.

### SEC-01 privileged smoke

- Run the final fresh-token developer/admin allow cases, scoped-admin `roles` denial, authenticated ordinary-profile reads, and unauthenticated privileged denial.
- Record sanitized evidence before changing SEC-01 from 7/8.

## Release STOP conditions

Stop the rollout when any of the following is true:

- a migration dry run has unexplained or unapproved records;
- legacy pending orders remain unresolved;
- the public/private profile backfill is incomplete or leaks private/authority fields;
- legacy community visibility normalization is incomplete;
- critical support/media token exposure is unresolved;
- any required emulator/security regression test fails;
- a signed release build or archive fails;
- production App Check registration rejects legitimate real-device clients;
- the required rollback artifact, owner, or authority is unavailable;
- deployed backend/Rules/app versions cannot be proven compatible.

Cosmetic UX defects are not security rollout blockers unless they break compatibility, obscure a security failure, or prevent a required smoke case.

## Security debt register

- **Production verification prerequisite:** SEC-01 fresh-token privileged smoke remains open.
- **Known accepted limitation:** flat legacy post-media paths and previously shared token URLs cannot fully inherit SEC-05 visibility/block semantics; critical support token exposures still require remediation.
- **Future privacy enhancement:** consent-version history is not implemented.
- **Future trusted-commerce feature:** payment-provider webhook verification and payment state authority are not implemented.
- **Operational debt:** establish and verify an Artifact Registry cleanup policy separately from application deployment.

These labels are not interchangeable: a rollout prerequisite blocks the coordinated release, a known accepted limitation requires explicit risk acceptance/mitigation, a future feature is outside this baseline, and a confirmed vulnerability requires an incident/security fix.

## MOB-02 boundary

The next phase is **MOB-02 - Customer Navigation & UX Finalization**.

MOB-02 may improve navigation, labels, customer flows, responsive behavior, and loading/error/empty states, and may remove dead customer UI. It may not change the frozen trust boundaries, restore direct order or financial writes, restore cross-user private reads, weaken visibility/block or Storage ownership Rules, disable App Check source configuration, or restore mobile management UI.
