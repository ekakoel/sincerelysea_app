# SincerelySea Development Roadmap

**Current Phase:** MOB-01 - Customer-Only Mobile Surface. **Overall Status:** MOB-01 repository implementation complete `[x]`; security gate remains blocked `[!]`. **Completion:** MOB-01 6/6 source-boundary assertions pass; SEC-01 remains 7/8. **Current Milestone:** preserve the customer-only Flutter boundary while establishing a reachable fresh-token path for the remaining SEC-01 production smoke verification. **Last Updated:** 2026-09-20.

## Status

`[x]` verified in this repository; `[~]` partial; `[ ]` not started; `[!]` blocked/unsafe dependency.

| Phase | Status | Scope | Dependencies and validation |
| --- | --- | --- | --- |
| MOB-01 | [x] | Customer-only Flutter surface | Management screens/routes/callers removed; community-only post creation, official-store customer terminology, and six source-boundary assertions verified. |
| 0 | [x] | Audit, blueprint, architecture, P0 security gate | Repository architecture and P0 findings documented. |
| 1 | [!] | Firebase/bootstrap, Auth, username, App Check baseline | SEC-01 implementation, emulator verification, callable deployment, identity provisioning, and claim-authoritative Rules deployment are complete. Fresh-token production smoke verification is blocked because no signed-in application session is reachable and the operator ADC lacks `iam.serviceAccounts.signBlob`. |
| 2 | [~] | Target navigation, design system, loading/empty/error/offline | Phase 1. |
| 3 | [~] | Public/private profile, follow/privacy, account lifecycle | Phase 1; privacy Rules tests. |
| 4 | [~] | Feed/posts/comments/save/report/moderation | Phase 3; privacy/block tests. |
| 5 | [~] | Discover/search/map/location privacy | Phase 4; area-vs-precise tests. |
| 6 | [~] | Official catalog and inventory | P0 role fix; staff authorization tests. |
| 7 | [!] | Secure cart, checkout, payment/order state machine | P0 order/payment fix, provider and webhook tests. |
| 8 | [ ] | Product ratings | Phase 4/6; uniqueness and aggregation tests. |
| 9 | [~] | Wishlist and demand events | Phase 6; analytics/privacy tests. |
| 10 | [ ] | Product instances, ownership, Collection | Phase 7; server-authority tests. |
| 11 | [ ] | Product history/provenance | Phase 10; event integrity tests. |
| 12 | [ ] | Historical product claims | Phase 3/10; review/audit tests. |
| 13 | [ ] | Gift/transfer | Phase 10; acceptance/idempotency tests. |
| 14 | [ ] | Controlled pre-owned resale | Phases 10/13; policy/fraud tests. |
| 15 | [ ] | Direct messages and safety | Phase 3; participant/block/rate-limit tests. |
| 16 | [~] | Notifications | Source domains; Functions/device tests. |
| 17 | [ ] | Official account/content | Phases 3/4/6; protected badge tests. |
| 18 | [ ] | Badges and reputation | Phases 3/10/19; protected assignment tests. |
| 19 | [ ] | Contribution engine | Phases 8/15/7; quality/anti-farming tests. |
| 20 | [ ] | Community-commerce attribution | Phases 4/6/7/25/26; fraud/idempotency tests. |
| 21 | [ ] | Points and rewards | Phases 19/20; ledger/reversal/redemption tests. |
| 22 | [ ] | Endorsement program | Phases 17/19/20; admin/disclosure tests. |
| 23 | [~] | Activity, transactional and official notifications | Source domains; delivery/authorization tests. |
| 24 | [ ] | WhatsApp transactional communication | Phases 7/23; consent/provider/webhook tests. |
| 25 | [~] | External sharing/social acquisition | Phases 4/6; canonical URL analytics tests. |
| 26 | [~] | App/universal/deferred links | Phase 25; Android/iOS/app-not-installed tests. |
| 27 | [!] | Security, privacy and anti-abuse hardening | Resolve SEC-01 through SEC-07; emulator/abuse tests. |
| 28 | [ ] | Full QA, performance and UX polish | All relevant predecessor phases. |
| 29 | [ ] | Android/iOS production release | Phase 28; device, legal and release checks. |
| 30 | [ ] | app.sincerelysea.com | Phases 25/26/release needs. |
| 31+ | [ ] | Admin/business web backend | Mobile trusted-domain contracts. |

## MOB-01 checklist

- [x] Audit screens, navigation, dialogs, menus, role gates, services, providers, direct callables, Rules, Functions, and tests.
- [x] Remove Flutter management screens, routes, role/scope presentation, and the `setUserAdminAccess` client.
- [x] Make mobile post creation community-only while keeping existing product posts readable.
- [x] Retain customer catalog, wishlist, cart, checkout, own-order history/detail, Buy Again, and permitted pending-order cancellation.
- [x] Rename the legacy seller storefront to the official single-store customer surface.
- [x] Verify ordinary/admin/developer identities share one role-independent mobile surface and preserve SEC-01 backend infrastructure.

## Gap analysis: top priorities

| Priority | Domain and gap | Roadmap phase | Action |
| --- | --- | --- | --- |
| P0 | SEC-01 client role escalation - production blocked [!] | 1/27 | Implementation, emulator tests, callable, approved claims, and production Rules are deployed; complete the blocked fresh-token production authorization smoke matrix. |
| P0 | Client financial writes | 7/27 | Server-only accounting/event pipeline. |
| P0 | Client-controlled orders/payment state | 7/27 | Trusted checkout, recomputation and webhook state machine. |
| P0 | Private data broadly readable | 3/27 | Public/private profile split and migration. |
| P1 | Post visibility/block policy not enforced | 4/27 | Rules/backend policy. |
| P1 | Product stock/gallery authority incomplete | 6/27 | Scoped server inventory/media. |
| P1 | No instance/ownership model | 10 | Lifecycle service. |
| P1 | No verified account/owner distinction | 3/10 | Separate status and ownership models. |
| P1 | No ratings | 8 | One current rating/user/product. |
| P1 | No historical claims/history | 11/12 | Reviewed evidence workflow. |
| P1 | No user-to-user DMs | 15 | Request/block/privacy design. |
| P1 | No payment provider | 7 | Gateway/webhook/refund design. |
| P2 | Navigation differs from target | 2 | Explore grouping and creation action. |
| P2 | Post-only deep links | 26 | Product/profile/official routes and fallback. |
| P2 | Minimal tests | 1/27/28 | Unit/widget/integration/emulator/device suites. |

## Required future-work protocol

Every future developer/Codex task MUST: (1) read [BLUEPRINT.md](BLUEPRINT.md); (2) read this roadmap; (3) identify current phase and exact checklist items; (4) inspect implementation; (5) implement only requested scope; (6) run appropriate tests; (7) validate actual behaviour; (8) update checklist statuses and validation notes; (9) recalculate phase completion; (10) update Current Phase, Current Milestone, Current Blockers, Next Recommended Task and Last Updated. Never mark `[x]` from generated code alone.

Before moving phases, verify dependencies and P0 issues, run relevant tests, update documentation and record blockers. Mark `[!]` and explain a broken dependency rather than silently continuing.

## Phase 1 security checklist

- [~] SEC-01: eliminate client-controlled role authority.
  - [x] Claims-based implementation and client authority-field denial.
  - [x] Firestore Emulator authorization verification.
  - [x] Explicit-project, dry-run-first bootstrap and read-only legacy inventory tooling.
  - [x] Deploy `setUserAdminAccess` to production.
  - [x] Run the read-only legacy privileged-account inventory in production.
  - [x] Manually approve and provision the trusted privileged UIDs.
  - [x] Deploy claim-authoritative Firestore Rules.
  - [!] Run non-destructive production authorization smoke tests. Unauthenticated privileged access denial passed, but fresh developer/admin sessions were unavailable to the verifier: no connected signed-in application session was reachable and operator ADC lacks `iam.serviceAccounts.signBlob` on the existing Firebase Admin service account.
- [ ] SEC-02: move financial journal and sales-report writes behind server authority.
- [ ] SEC-03: replace client-controlled checkout/payment/order transitions with a trusted state machine.
- [ ] SEC-04: split public and private user data and enforce least-privilege reads.

## Status summary

- `[x]` complete phases: 2
- `[~]` partial phases: 10
- `[!]` blocked phases: 3
- `[ ]` not-started phases: 18
- Phase 1 P0 security-foundation completion: 0% (0/4 production-verified; 7/8 SEC-01 checklist subtasks verified)

## MOB-01 validation notes

- `flutter pub get`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: all 8 tests passed, including 6 MOB-01 boundary assertions.
- Functions syntax/lint: passed.
- Firestore Emulator: all 9 SEC-01 authorization scenarios passed.
- Repository-wide route/label/callable search found no Flutter management route or `setUserAdminAccess` caller. Remaining seller fields are historical order-schema compatibility; remaining admin/developer/scope references are backend security, documentation, tests, or official-store data compatibility.
- MOB-01 did not modify or deploy Firestore Rules, Storage Rules, Cloud Functions, custom claims, or production data.

## SEC-01 validation notes

- Firestore Emulator: 9 role-escalation/authorization scenarios passed.
- Flutter static analysis: changed authentication and administration services passed.
- Flutter regression tests: existing suite passed.
- Cloud Functions/script syntax checks, dependency resolution, Function discovery, and all nine Firestore Emulator tests passed under Node 22.
- Firebase target and CLI authentication were confirmed for `gen-lang-client-0026437130`.
- The incomplete local dependency installation was rebuilt from the lockfile, restoring the Firebase Functions SDK executable used by Firebase CLI discovery.
- A targeted deployment created only `setUserAdminAccess`; the production Functions inventory confirms it is an active v2 callable in `us-central1` on Node.js 22. The CLI subsequently reported that Artifact Registry cleanup policy setup requires `--force`; this did not roll back the successful Function creation.
- The legacy inventory script passed syntax and wrong-project rejection checks and was verified to use only Firestore query and Auth lookup APIs.
- On 2026-09-20, Google Cloud CLI access to `gen-lang-client-0026437130` and Application Default Credentials were verified. The read-only production inventory returned two untrusted legacy privileged candidates, each with an existing, enabled Firebase Auth record and no trusted privileged claim: `4RWo2A35L2NYavF4NuD0VwINOmB2` (`admin`) and `WT0trMBt9zNaMFYXQ61cs67K1x53` (`developer`). No claims, Firestore records, Rules, or other production data were changed.
- The human operator independently verified and explicitly approved both inventoried identities. Dry runs showed no existing privileged claims and the expected mutations only.
- `WT0trMBt9zNaMFYXQ61cs67K1x53` was provisioned as developer with `admin: true`, `developer: true`, and all supported scopes: `products`, `orders`, `finance`, `community`, and `roles`. A separate read-only Auth inventory verified the account exists, is enabled, and has exactly those privileged claims.
- `4RWo2A35L2NYavF4NuD0VwINOmB2` was provisioned as admin with the least-privilege operational scopes `products`, `orders`, `finance`, and `community`; the `roles` scope was intentionally excluded. A separate read-only Auth inventory verified the account exists, is enabled, has `admin: true`, and does not have the developer claim.
- The claim bootstrap retained the designed Firestore role/scope mirrors and wrote audit records; those mirrors remain non-authoritative. Rules deployment was then performed as a separately verified transition.
- Immediately before deployment, the read-only Auth inventory reconfirmed the exact approved claims on both enabled accounts. A complete Rules audit found all privileged authorization derives from `request.auth.token`; Firestore role/scope mirrors are never used to authorize.
- The nine-case Firestore Emulator gate passed after expanding its assertions to cover explicit `role=developer` rejection, protected authority-field creation and add/change/removal, and both claimed admin and developer access. Functions/bootstrap/inventory syntax checks also passed.
- `firebase deploy --only firestore:rules --project gen-lang-client-0026437130` compiled and released only `firestore.rules`. Firebase Rules release `cloud.firestore` now points to ruleset `ed2fdf20-027d-4e7b-b271-51033f9d6c16`, independently confirmed through the read-only Rules API with update time `2026-09-19T23:11:01.939251Z`.
- The Rules compiler emitted non-blocking warnings associated with the existing unused `isFollower` helper and the unused `postId` parameter; compilation and release succeeded. No Functions, indexes, Storage Rules, Hosting, Flutter application, claim changes, token refresh, or production smoke test occurred in this task.
- A project-locked read-only production verifier was added. It reads the existing web Firebase configuration, accepts only `gen-lang-client-0026437130`, uses in-memory authentication, imports no Firestore mutation APIs, prints no tokens, and defines only bounded reads for developer `roles`, admin `orders`/`finance`/`community`, admin `roles` denial, self-profile access, and unauthenticated denial.
- The Firebase CLI target and repository project aliases remained exactly `gen-lang-client-0026437130`. The trusted Admin SDK precheck reconfirmed both enabled accounts and their exact approved custom claims; the admin still has neither `developer` nor `roles` authority.
- Production smoke evidence completed for one case: an unauthenticated query of `admin_audit_logs` returned `permission-denied` as expected. No production document or claim was changed.
- Fresh developer/admin client sessions could not be minted because the operator ADC lacks `iam.serviceAccounts.signBlob` on `firebase-adminsdk-fbsvc@gen-lang-client-0026437130.iam.gserviceaccount.com`. No connected device or running application session was available to execute the same reads with the operator-refreshed tokens. Developer positive access, scoped-admin positive access, admin `roles` denial, and authenticated self-profile reads therefore remain unverified in production. No suitable normal-customer production session was available; the nine-case Emulator suite continues to verify normal-user denial, safe profile updates, protected authority fields, and forged legacy-role rejection.
- The verifier stopped without weakening Rules, adding scopes, granting IAM, requesting credentials, redeploying, or performing any production mutation. Functions/script syntax checks and all nine Firestore Emulator cases passed after the blocked production attempt.

**Current Blockers:** The operator reports fresh privileged sign-ins, but those sessions are not reachable from this workstation's verification process. Operator ADC cannot mint replacement in-memory sessions because it lacks `iam.serviceAccounts.signBlob`; no connected signed-in application session was detected. SEC-02, SEC-03 and SEC-04 remain unresolved. **Next Recommended Task:** Execute the non-destructive SEC-01 production smoke matrix from a reachable fresh signed-in application session for both approved privileged accounts.
