# SincerelySea Master Product Blueprint

**Status:** target product source of truth. **Current implementation authority:** repository evidence. **Last audited:** 2026-09-22.

## What SincerelySea is

SincerelySea is a community, product-experience, customer-ownership, commerce, product-lifecycle, and contribution-and-reward platform for SincerelySea leather products. It is an official-brand experience, not a general multi-seller marketplace.

Target loop: Community -> Product Experience -> Review -> Recommendation -> Direct Messaging / External Sharing -> Discovery -> Purchase -> Ownership -> Collection -> Product History -> Contribution -> Rewards -> Transfer/Gift/controlled Resale -> New Ownership -> Community.

Users are visitors/registered customers, verified customers, verified owners, historical customers, official accounts, endorsement users, and internal admins. Registered Account, Verified Account, Verified Owner, Official Account, Endorsement User, and Admin are separate concepts; never collapse them into `isVerified`.

## Repository evidence: current state

Flutter/Firebase currently provides email and Google authentication, email activation for password users, username reservation, posts/comments/replies/likes/follows, block/report/hide controls, discovery/map, product catalog, product wishlists, cart, trusted callable checkout/cancellation, official-store presentation, notifications, support tickets, App Check client activation, post sharing, and post-only deep links. MOB-01 removes all mobile management UI and privileged callable clients; admin/developer accounts receive the same customer surface as ordinary accounts. SEC-02 removes Flutter finance writes and derives order-created and order-cancelled journals/reports in trusted Cloud Functions with deterministic event identities. SEC-03 moves new order creation, authoritative product snapshots/totals, stock mutation, and pending-order cancellation to trusted callable transactions. SEC-04 splits signed-in-readable `users_public` profiles from owner-only `users_private` account/contact data in source, keeps mixed legacy `users` documents owner-only, and aligns active Terms, Privacy, and Support content with the customer-only application. SEC-05 enforces public/follower/private post reads, symmetric blocks, and parent-gated comments/replies in Firestore Rules; Flutter feed/search/map/profile discovery uses Rules-compatible author-scoped queries. SEC-06 makes active profile, post, and support uploads authenticated, owner-scoped, MIME/size constrained, and makes legacy product-gallery media customer read-only; new support records retain private Storage paths instead of download URLs. SEC-07 selects debug providers only for debug builds, selects Play Integrity and App Attest with DeviceCheck fallback for non-debug builds, fails closed when production initialization fails, and declares native App Check enforcement on customer-sensitive callables.

Current primary navigation is **Home, Search, Explore (map), Shop, Profile**. MOB-02 preserves tab state with one indexed stack, returns root-level back navigation from a secondary tab to Home, and keeps Create Post as a prominent community-only Home action. MOB-03 completes the retained customer flows at source/test level: real password recovery, safe auth and customer errors, current-product validation through cart/checkout/Buy Again, direct order-detail continuation after checkout, honest system notification settings, resilient hidden/shared content, and privacy-safe profile fallbacks. MOB-03A adds text/rating product reviews under each product with one deterministic review per customer, owner-only create/edit/delete, 1-5 validation, public author identity from users_public, and no client aggregate writes. QA-01 fixes account-export serialization and completeness plus trusted deletion cleanup for active customer content, support trees/media, reviews, replies, and customer subcollections. Review media and verified-purchase labels are not implemented, while review reporting/moderation remains a future backend enhancement. Existing official product posts remain readable, and the separate backend website remains the target management plane. Local analysis, Flutter tests, Firebase emulator tests, and an Android debug build pass; real-device auth, permissions, release App Check, and iOS build/signing remain outside this Windows QA run.

The canonical SEC-01 through SEC-07 status, production prerequisites, deployment order, rollback boundaries, and acceptance gates are frozen in [PRODUCTION_ROLLOUT.md](PRODUCTION_ROLLOUT.md). Source completion, test completion, migration, deployment, and production verification remain distinct states.

## MOB-03 customer feature matrix

| Customer domain | Status |
| --- | --- |
| Auth | COMPLETE |
| Community | COMPLETE |
| Social | COMPLETE |
| Search / Explore | COMPLETE |
| Shop | COMPLETE |
| Wishlist / Saved | COMPLETE |
| Cart | COMPLETE |
| Checkout | COMPLETE |
| Orders | COMPLETE |
| Reviews | COMPLETE |
| Notifications | COMPLETE |
| Profile | COMPLETE |
| Settings | COMPLETE |
| Support | COMPLETE |
| Legal | COMPLETE |
| Account lifecycle | COMPLETE |

Statuses describe the current source/test boundary only. Production migration, deployment, App Check registration/enforcement, and production smoke verification remain governed by the security checkpoint.

## QA-01 matrix

| Area | Happy Path | Failure Path | Security | Status |
| --- | --- | --- | --- | --- |
| Auth | Routes and recovery are covered | Safe errors are covered | Public/private identity split retained | PARTIAL |
| Profile | Edit and export paths are covered | Export failure is recoverable | Private email is not a public fallback | PASS |
| Community | Post/comment/reply flows are covered | Missing/hidden content is neutral | Visibility and block Rules pass | PASS |
| Social | Follow/save/report paths are covered | Blocked/private access is denied | Cross-user boundaries pass | PASS |
| Search/Explore | Queries and map states are covered | Empty/error states are retryable | Author-scoped queries retained | PARTIAL |
| Shop | Catalog/detail flows are covered | Unavailable product state is handled | Official-store boundary retained | PASS |
| Reviews | Create/edit/delete/read are covered | Invalid/cross-user writes are denied | Owner-only Rules pass | PASS |
| Wishlist/Saved | Add/remove/read paths are covered | Missing targets are neutral | Owner-only state retained | PASS |
| Cart | Quantity and clear flows are covered | Stale/unavailable items are blocked | Owner-only cart retained | PASS |
| Checkout | Trusted request flow is covered | Invalid stock/price/input is rejected | No client order write | PARTIAL |
| Orders | List/detail/cancel paths are covered | Missing/non-pending cases are handled | Trusted cancellation retained | PASS |
| Notifications | Center and routing are covered | Missing targets fail safely | Customer-only destinations retained | PARTIAL |
| Support/Legal | Ticket, Terms, and Privacy paths are covered | Upload/input failures are recoverable | Tickets/media remain owner-private | PASS |
| Account lifecycle | Export and cleanup pass in local emulators | Reauth/export errors are recoverable | Trusted callable and required indexes retained | PASS |
| Storage | Allowed owner uploads are covered | MIME/size/cross-user denial passes | SEC-06 Rules pass | PASS |
| App Check | Debug selection is covered | Release initialization fails closed | Production registration not exercised | BLOCKED BY PRODUCTION |
| Navigation | Five tabs and detail returns are covered | Back behavior is covered | No management destination | PASS |
| Android build | Debug APK builds | Dependency warnings are non-blocking | Debug artifact only | PASS |
| iOS verification | Static configuration is present | Build/sign/device checks need macOS | App Attest entitlement is present | BLOCKED BY PLATFORM |

PASS records evidence from this local source/test boundary, not production verification. PARTIAL identifies real-device or full callable integration coverage still required by REL-01.

## Target account journeys

| Journey | Target |
| --- | --- |
| Mobile self-registration | Download -> register -> registered/unverified -> configurable profile/email/phone/consent verification -> verified -> protected purchase eligibility. Public discovery must remain available. |
| Website-first customer | Website purchase -> find existing identity or securely provision one -> expiring one-time activation -> private Firebase Auth password -> verify -> instance/ownership/Collection. |
| Legacy customer | Register/recover -> verify -> submit product evidence -> trusted review -> approved instance/ownership/history -> Collection. Evidence upload is not ownership proof. |

Login email is a private authentication identity. Public username is a distinct, unique community handle and must never expose email. Provisioned accounts need secure activation links or short-lived, one-time temporary credentials; final passwords remain only in Firebase Auth.

## Product domains and target rules

| Domain | Target rule |
| --- | --- |
| Profile | Split public profile from private customer/contact/verification/commerce data. |
| Community | Product-experience posts support media, product relation, caption, rating snapshot, location privacy, interaction, report and moderation state. |
| Location | Ask contextually during posting. Area mode stores city/regency, province, country and no retained coordinates; precise mode adds coordinates. |
| Catalog | A catalog Product differs from a physical Product Instance. Preserve `storeId=sincerelysea`, `storeName=SincerelySea Store`, `ownerType=business`, `managedByAdmins=true`. |
| Ratings | One user + one product = one current rating; likes/save/wishlist are distinct and multiple posts cannot inflate ratings. |
| Wishlist | One user + one product relation; it is demand intelligence, not a reward. |
| Ownership | Collection presents authoritative owned product instances, not order history or a customer-created list. Server creates ownership from valid purchase, approved claim, gift/transfer, or controlled resale. No NFC. |
| Provenance | History distinguishes verified events from customer-provided approximate events. |
| DMs | Request/accept one-to-one conversations, participant-only messages, block/report/rate limits; no unrestricted anonymous messaging or default admin reading. |
| Contributions | Qualified review, verified helpful contribution, and verified conversion are backend-evaluated with anti-farming rules. |
| Attribution/rewards | Track meaningful referrals, configurable last eligible referral, valid order item, reversal; points are immutable ledger entries, never mutable client balance. |

## Dependency map

```text
Identity -> Verification -> Product catalog -> Product instance/ownership -> Collection
                    |                                      |                 |
Community -> ratings, recommendation, DM ------------------+                 +-> transfer -> resale
Community + Product -> sharing -> deep links -> attribution -> contribution -> points -> rewards
Commerce <- Product catalog + Identity + Verification + trusted payment/order processing
Historical claim -> validation -> Product instance/ownership -> Collection/history
```

## Current-to-target gaps

| Domain | Current | Target | Status/action |
| --- | --- | --- | --- |
| Identity | Firebase Auth plus source-level `users_public`/`users_private` split; legacy `users` owner-only | production backfill and removal of mixed legacy documents | SEC-04 implemented/tested, not deployed |
| Authorization | Firebase Auth custom claims; Firestore mirrors are non-authoritative | custom claims/server authority | SEC-01 PARTIAL 7/8; fresh-token production smoke pending |
| Community | source-level post visibility, symmetric block enforcement, private hide/save state, reports | product experience and trusted moderation workflow | SEC-05 implemented/tested, not deployed |
| Media | owner-scoped profile/post/support writes; signed-in community reads; official legacy product media read-only | post-aware delivery and backend-managed official media | SEC-06 implemented/tested, not deployed; legacy token/path review required |
| App Check | build-mode provider selection and source-level enforcement on mobile callables | registered production providers, deployed callables, staged service enforcement, and real-device validation | SEC-07 source/test readiness complete; production enforcement pending |
| Catalog | official-store catalog | variants/material/care/inventory authority | partial |
| Commerce | trusted checkout/cancellation and create/cancel reporting; payment gateway absent | backend payment state machine and legacy-order reconciliation | SEC-02/SEC-03 source implemented and tested, not deployed |
| Collection | user-editable post collections | verified physical ownership | transformation required |
| Product reviews/ratings | one text/rating review per signed-in customer and product; summary derived only from loaded reviews | trusted aggregate summary, verified purchase, and backend reporting/moderation | MOB-03A implemented/tested, not deployed |
| Claims/history/DMs | absent | target domains | not implemented |
| Rewards/attribution/endorsement/resale | absent | future domains | deferred |

## Security non-negotiables

Flutter is untrusted and customer-only. It must never grant or present management for role, verification, official/endorsement state, ownership, claim approval, product price/stock authority, payment/order truth, order final status, moderation, finance, attribution, points or reward balance. Use Auth custom claims and a separate backend website backed by audited Cloud Functions/Cloud Run commands, payment-provider webhooks, App Check enforcement, idempotency, and Rules/Functions security tests.

SEC-01 through SEC-07 define the security baseline for all subsequent mobile development. Future mobile phases must preserve these trust boundaries. Any change that weakens them requires an explicit security phase and regression tests.

## Target data model (incremental)

| Domain | Authoritative records |
| --- | --- |
| Identity | `users_public`, restricted `users_private`, `usernames`, Auth custom claims |
| Product/lifecycle | `products`, variants, `product_instances`, `ownerships`, `product_history_events`, `historical_claims` |
| Community | `posts`, `products/{productId}/reviews/{uid}`, `saved_posts`, `wishlists`, `reports` |
| Commerce | server checkout intents, `orders`, `payment_events`, reservations |
| Messaging | `conversations`, `message_requests`, participant-scoped `messages` |
| Rewards | `contributions`, `reward_rules`, immutable `points_ledger`, redemptions |
| Attribution | `product_referrals`, `attribution_sessions`, `conversion_attributions` |

## Migration assessment

- **Users:** production transformation required: backfill `users_public` and `users_private`, validate counts/ownership, then retire mixed legacy `users` documents. No production migration was run in SEC-04.
- **Roles:** transformation required: migrate document roles to claims/server records; safely bootstrap auditable admins.
- **Products/orders:** compatible catalog extensions; trusted order/payment redesign requires legacy integrity review.
- **Current collections:** transformation required: retain user-curated post collections separately, introduce authoritative ownership Collections.
- **Posts/wishlists:** compatible extension; review legacy precise coordinates before any map migration.
- **Post visibility:** normalize legacy community posts that lack `visibility`; SEC-05 treats them as owner-only, while legacy official product posts remain authenticated-community readable.
- **Storage media:** audit legacy support tickets that store tokenized attachment URLs, backfill safe Storage paths and revoke exposed tokens. Existing flat `post_images/{uid}_{timestamp}.jpg` objects and stored profile/post download URLs cannot reproduce SEC-05 visibility/block policy; a post-ID-aware path or trusted delivery redesign is a separate migration, not part of SEC-06.
- **App Check:** register the Android/iOS production providers, configure real release identities outside the repository, deploy reviewed customer callables, and stage enforcement with real-device validation. Firestore and Storage production enforcement are operator-controlled service settings and are not proven by client source.
- **Reviews:** existing products require no migration and correctly begin with zero reviews. Review media, verified-purchase derivation, trusted aggregate summaries, and backend reporting/moderation remain future enhancements.
- **Instances, claims, DMs, rewards, attribution:** no migration until introduced; historical imports need investigation.

## Glossary

**Product** catalog definition; **Variant** purchasable option; **Product Instance** physical unit; **Ownership** authoritative right to an instance; **Collection** recognized owned instances; **Product History** lifecycle events; **Historical Claim** reviewed legacy request; **Post** community content; **Product Rating** current per-user/product rating; **Wishlist** product intent; **Saved Post** bookmark; **Contribution** eligible evaluated behaviour; **Qualified Review/Helpful Contribution** qualifying categories; **Referral/Attribution/Conversion** eligible click/causal credit/valid order; **Points/Reward** ledger amount/redemption benefit; **Badge** protected reputation marker; **Direct Message** participant-private chat; **Official Message** protected company communication; **Transactional Notification** operation message; **Legacy Customer** pre-digital-ownership customer.

Related documents: [production rollout](PRODUCTION_ROLLOUT.md), [security operations](SECURITY.md), [technical architecture](TECHNICAL_BLUEPRINT.md), [roadmap](ROADMAP.md), [flows](USER_FLOWS.md), [decisions](DECISIONS.md).
