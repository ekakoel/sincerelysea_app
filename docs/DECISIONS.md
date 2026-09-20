# SincerelySea Architectural Decisions

| ID | Decision | Rationale |
| --- | --- | --- |
| D-01 | Email and public username are separate. | Email is private authentication identity. |
| D-02 | Verified Account and Verified Owner are separate. | Account eligibility is not proof of an owned instance. |
| D-03 | Catalog product and physical product instance are separate. | Lifecycle applies to units. |
| D-04 | Points use an immutable ledger. | Auditability and reversals. |
| D-05 | One active rating per user/product. | Prevent rating inflation. |
| D-06 | Area-first location privacy. | Retain discovery without exposing coordinates. |
| D-07 | Ownership, claims, attribution and verification are server-controlled. | Client input is untrusted. |
| D-08 | Provisioned accounts use secure activation. | No permanent default or stored passwords. |
| D-09 | DMs are participant-private by default. | Admin access needs explicit legal/moderation policy. |
| D-10 | Canonical URLs are required. | Sharing, deep links, web fallback and attribution. |
| D-11 | Firebase Auth custom claims are the sole authority for admin, developer, and admin scopes. Firestore role fields are server-written display/migration mirrors only. | A user-owned document cannot be a trustworthy privilege source; claims can be changed only through trusted Admin SDK code and are available to Security Rules without a user-document lookup. |
| D-12 | Cloud Functions target Node.js 22; dependency recovery uses a lockfile-consistent clean install, while Firebase SDK major upgrades are separate compatibility work. | Node.js 22 is supported by the installed Firebase tooling and avoids the approaching Node.js 20 decommission date. The SEC-01 discovery failure came from an incomplete installation, not an incompatible SDK API, so unrelated major-version risk is deferred. |
| D-13 | Flutter is customer-facing only; all privileged operations belong to a separate backend website. | Mobile claims must not alter navigation or expose management capability, while SEC-01 backend authorization remains available for the management plane. |
