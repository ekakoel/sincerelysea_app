# SincerelySea Technical Blueprint

## Observed architecture

Flutter/Dart uses Provider, Firebase Auth/Firestore/Storage/Functions/Analytics/Crashlytics/App Check, Google Maps/location, local notifications, and App Links. `main.dart` initializes Firebase, App Check and Crashlytics; `AuthWrapper` gates password users on Firebase email verification. Node 22 Cloud Functions v2 provide hard account deletion, privileged access management, and event-triggered notifications/counts. Android/iOS declare custom and HTTPS post links; only `/post/{id}` is parsed.

MOB-01 establishes a hard product boundary: Flutter is customer-facing only. Its primary navigation is Home, Search, Explore, Shop, Profile; settings contain customer account/privacy/notification/support/commerce controls. No claim-aware admin/developer menu, management route, privileged callable client, catalog editor, fulfilment console, moderation queue, finance screen, or role UI remains. The future backend website is the management plane.

Observed root collections: `users`, `usernames`, `posts`, `products`, `orders`, `journal_entries`, `sales_reports`, `admin_audit_logs`, `reports`, `app_config`; user subcollections include followers/following/follow_requests, blocks, cart, hidden_posts, notifications, support tickets/messages, saved_posts, collections, wishlists. Storage covers posts, profiles, support attachments and product galleries.

## Security findings

| ID | Severity | Evidence / impact | Required remediation |
| --- | --- | --- | --- |
| SEC-01 | P0 - 7/8, production smoke blocked | Firebase Auth custom claims now authorize privileged operations; approved claims and claim-authoritative Rules are deployed. | Complete the fresh-token developer/admin production smoke matrix from a reachable signed-in session or pre-approved token-signing environment. |
| SEC-02 | P0 | Any signed-in user may create `journal_entries` and `sales_reports`; client code writes financial records. | Server-only immutable accounting/events and idempotency. |
| SEC-03 | P0 | Buyer may create orders with client items/totals and statuses including paid/processing/shipped/completed; no payment webhook authority. | Backend checkout/state machine, catalog recalculation, stock reservation, verified webhooks. |
| SEC-04 | P0 | All signed-in users read `users/{uid}` while profile documents may contain private contact/commerce data. | Public/private split and least-privilege Rules. |
| SEC-05 | P1 | Post visibility and blocks are not enforced in post/comment reads. | Enforce visibility/membership/block policy and immutable moderation fields. |
| SEC-06 | P1 | Public Storage reads, no size/dimension limits, product upload authorization is UID based. | Public-media policy, server media validation, scoped catalog media. |
| SEC-07 | P1 | Client App Check exists; repository contains no production enforcement evidence. | Enable/enforce with approved debug flow and monitoring. |

No hardcoded private password/secret was found in inspected Dart/Functions sources. Firebase client configuration is public identifier material, not a server secret.

## Target architecture and authority

```text
Flutter (untrusted intent) -> Firebase Auth/App Check -> Firestore read models
                                 -> Callable/HTTPS backend -> Admin SDK / payment webhooks / providers
```

Rules protect low-risk owner preferences. Privileged operations run on backend: roles, verification, catalog inventory, checkout/payment, ownership/claims/transfers, ratings aggregation, attribution, reward ledger, official state, and admin commands. Every trusted endpoint validates Auth/App Check/schema/role/rate limits/business invariants/idempotency and writes an audit trail.

| Operation | Authority |
| --- | --- |
| profile/preferences | owner, schema-limited Rules |
| roles/official/verified/endorsement | audited server command |
| catalog stock | scoped staff server command |
| paid order/payment state | checkout backend + provider webhook |
| ownership/claim/transfer/resale | lifecycle backend |
| rating aggregate/points/reversal | backend only |
| DMs | active permitted participants, backend-enforced requests/blocks/limits |

### Implemented role authority (SEC-01)

Firebase Auth custom claims are the sole authorization source for `admin`, `developer`, and `adminScopes`. Firestore Rules never authorize from `users/{uid}.role`. The user document retains `role`, `adminScopes`, and `authorizationSource` only as a server-written display/migration mirror; clients cannot create privileged values or add, remove, or modify authority fields.

Role changes use the callable `setUserAdminAccess`, which validates the caller's claims, prevents self-service access changes, reserves developer assignment for developers, updates Auth claims with the Admin SDK, mirrors display metadata, and records an audit event. Flutter has no caller for this function; it remains server infrastructure for the future backend website. The local `functions/scripts/set-admin-claims.js` command provides the trusted first-admin and migration path. Existing privileged sessions must refresh their Firebase ID token after a claim change. Full guidance lives in [SECURITY.md](SECURITY.md).

As of 2026-09-20, this design is repository-implemented and emulator-verified. The targeted `setUserAdminAccess` v2 callable is active in `us-central1` on Node.js 22, two operator-approved identities have verified least-privilege claims, and claim-authoritative Firestore Rules are deployed. Unauthenticated privileged access denial passed; fresh-token privileged positive/negative smoke cases remain blocked, so SEC-01 is 7/8 rather than complete.

## Test strategy

Each phase needs proportionate unit/widget tests, Firebase emulator Rules tests for all permit/deny cases, Functions tests for privileged/replay/idempotency cases, integration tests for identity/checkout/claim paths, and physical Android/iOS evidence for permissions, deep links and notifications. MOB-01 adds six source-boundary assertions for customer navigation/settings, role-independent UI, community-only post creation, official-store naming, removed management files, and retained SEC-01 infrastructure. SEC-01 adds nine Firestore Emulator scenarios covering safe registration, forbidden authority injection/update, ordinary profile updates, claim-authorized admin access, unauthenticated/non-admin denial, and rejection of a forged legacy Firestore role.

## Deferred

This audit does not implement Laravel/admin web, arbitrary marketplace, NFC, resale, points redemption, endorsement, WhatsApp automation, or public website. `app.sincerelysea.com` remains a future legal/support/activation/shared-content fallback surface.
