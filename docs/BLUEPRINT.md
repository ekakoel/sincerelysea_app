# SincerelySea Master Product Blueprint

**Status:** target product source of truth. **Current implementation authority:** repository evidence. **Last audited:** 2026-09-19.

## What SincerelySea is

SincerelySea is a community, product-experience, customer-ownership, commerce, product-lifecycle, and contribution-and-reward platform for SincerelySea leather products. It is an official-brand experience, not a general multi-seller marketplace.

Target loop: Community -> Product Experience -> Review -> Recommendation -> Direct Messaging / External Sharing -> Discovery -> Purchase -> Ownership -> Collection -> Product History -> Contribution -> Rewards -> Transfer/Gift/controlled Resale -> New Ownership -> Community.

Users are visitors/registered customers, verified customers, verified owners, historical customers, official accounts, endorsement users, and internal admins. Registered Account, Verified Account, Verified Owner, Official Account, Endorsement User, and Admin are separate concepts; never collapse them into `isVerified`.

## Repository evidence: current state

Flutter/Firebase currently provides email and Google authentication, email activation for password users, username reservation, posts/comments/replies/likes/follows, block/report/hide controls, discovery/map, product catalog, product wishlists, cart, client-created orders, an official-store data convention, scoped admin UI, basic sales reporting, notifications, support tickets, App Check client activation, post sharing, and post-only deep links.

Current primary navigation is **Home, Search, Explore (map), Shop, Profile**. Target navigation is **Home, Explore, +, Shop, Profile**, where Explore contains Discover and Map and `+` is contextual creation. There is one formatter test only; no emulator Rules, Functions, integration, Android device, or iOS device tests were found.

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
| Identity | Firebase Auth, public `users` data | explicit lifecycle and public/private split | P0 refactor |
| Authorization | Firestore role/scopes | custom claims/server authority | P0 refactor |
| Community | basic social system | product experience, privacy, moderation | partial |
| Catalog | official-store catalog | variants/material/care/inventory authority | partial |
| Commerce | client orders/reporting | backend checkout/payment state machine | P0 refactor |
| Collection | user-editable post collections | verified physical ownership | transformation required |
| Ratings/claims/history/DMs | absent | target domains | not implemented |
| Rewards/attribution/endorsement/resale | absent | future domains | deferred |

## Security non-negotiables

Flutter is untrusted. It must never grant role, verification, official/endorsement state, ownership, claim approval, product price/stock authority, payment/order truth, order final status, attribution, points or reward balance. Use Auth custom claims; audited Cloud Functions/Cloud Run commands; payment-provider webhooks; App Check enforcement; idempotency; and Rules/Functions security tests.

## Target data model (incremental)

| Domain | Authoritative records |
| --- | --- |
| Identity | `users_public`, restricted `users_private`, `usernames`, Auth custom claims |
| Product/lifecycle | `products`, variants, `product_instances`, `ownerships`, `product_history_events`, `historical_claims` |
| Community | `posts`, keyed `product_ratings`, `saved_posts`, `wishlists`, `reports` |
| Commerce | server checkout intents, `orders`, `payment_events`, reservations |
| Messaging | `conversations`, `message_requests`, participant-scoped `messages` |
| Rewards | `contributions`, `reward_rules`, immutable `points_ledger`, redemptions |
| Attribution | `product_referrals`, `attribution_sessions`, `conversion_attributions` |

## Migration assessment

- **Users:** transformation required: private contact/verification and authority leave broadly readable `users` documents.
- **Roles:** transformation required: migrate document roles to claims/server records; safely bootstrap auditable admins.
- **Products/orders:** compatible catalog extensions; trusted order/payment redesign requires legacy integrity review.
- **Current collections:** transformation required: retain user-curated post collections separately, introduce authoritative ownership Collections.
- **Posts/wishlists:** compatible extension; review legacy precise coordinates before any map migration.
- **Ratings, instances, claims, DMs, rewards, attribution:** no migration until introduced; historical imports need investigation.

## Glossary

**Product** catalog definition; **Variant** purchasable option; **Product Instance** physical unit; **Ownership** authoritative right to an instance; **Collection** recognized owned instances; **Product History** lifecycle events; **Historical Claim** reviewed legacy request; **Post** community content; **Product Rating** current per-user/product rating; **Wishlist** product intent; **Saved Post** bookmark; **Contribution** eligible evaluated behaviour; **Qualified Review/Helpful Contribution** qualifying categories; **Referral/Attribution/Conversion** eligible click/causal credit/valid order; **Points/Reward** ledger amount/redemption benefit; **Badge** protected reputation marker; **Direct Message** participant-private chat; **Official Message** protected company communication; **Transactional Notification** operation message; **Legacy Customer** pre-digital-ownership customer.

Related documents: [technical architecture](TECHNICAL_BLUEPRINT.md), [roadmap](ROADMAP.md), [flows](USER_FLOWS.md), [decisions](DECISIONS.md).
