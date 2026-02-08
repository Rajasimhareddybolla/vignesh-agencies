# vguard_service_app — Engineering Documentation (What’s verified from code)

> Scope note (important)
>
> You asked me to stop reading further and document what I understood. This document is therefore **authoritative only for the files I already inspected** and anything directly referenced by those files.
>
> **Verified from code (read):**
> - App entry + composition: `lib/main.dart`
> - Routing + access gating: `lib/app/router.dart`
> - Services: `lib/services/auth_service.dart`, `lib/services/firestore_service.dart`, `lib/services/order_service.dart`, `lib/services/cart_service.dart`, `lib/services/push_notification_service.dart`, `lib/services/warranty_notification_service.dart`, `lib/services/notification_service.dart`
> - Key models: `lib/models/{user_model,order_model,catalog_product_model,user_appliance_model,service_request_model,referral_model}.dart`
> - Key UI flows (sample): `lib/screens/auth/{login_screen,otp_screen,admin_login_screen}.dart`, `lib/screens/user/{checkout_screen,order_detail_screen}.dart`, `lib/screens/admin/{warranty_validation_screen,payout_manager_screen,reports_screen,send_notification_screen}.dart`
> - Firebase config + infra: `firebase.json`, `storage.rules`, `functions/index.js`, `functions/package.json`, `pubspec.yaml`, `PROJECT_SUMMARY.md`
>
> **Not fully verified:** all other screens, widgets, providers, and any backend security rules for Firestore (no `firestore.rules` found in the folder). Those areas are labeled as **“Unclear from code”** or **“Inferred from usage.”**

---

## 1. HIGH-LEVEL OVERVIEW

### Purpose of the package
A Flutter application (supports web + mobile targets based on repo structure) that combines:
- **Customer portal:** OTP login, product catalog browsing, cart + checkout (COD), orders tracking, warranty appliance registration, service request creation/tracking, notifications.
- **Admin portal:** dashboard/command center, service request management, warranty validation, referral payout management, marketing banners management, product catalog management, order management, report generation, notifications broadcast.

### Primary responsibilities
- Provide UI and workflows for **commerce** (catalog → cart → checkout → orders) and **after-sales service** (warranty + service tickets).
- Store and stream operational data from **Cloud Firestore**.
- Support uploads to **Firebase Storage** (rules provided) for documents/evidence.
- Support push notifications via **Firebase Cloud Messaging** plus local notifications.
- Provide an admin interface for validating/assigning/updating operational records.

### Intended use cases
- A dealer/service center that needs a single app to manage warranty registrations, service tickets, and direct sales.

### Who should use this package
- This is an **application**, not a reusable library.
- Intended for:
  - Customers/end users (user mode)
  - Admin operators (admin mode)

---

## 2. PACKAGE & FOLDER STRUCTURE

### Root (selected)
- `lib/` — Dart source for app logic, UI, services, models.
- `functions/` — Firebase Cloud Functions (Node.js) used for push notification sending.
- `android/`, `ios/`, `macos/`, `web/` — platform scaffolding.
- `assets/` — app assets (images).
- `firebase.json` — Firebase project configuration mapping for FlutterFire and Functions.
- `storage.rules` — Firebase Storage rules.
- `pubspec.yaml` — Flutter dependencies and assets.

### `lib/` (as verified)
- `lib/main.dart` — entry point; Firebase init; App Check; push/local notification init; dependency injection via Provider; router wiring.
- `lib/app/` — app-level theme and routing (`router.dart` verified; `theme.dart` referenced).
- `lib/models/` — data models for Firestore documents (orders, service requests, users, referrals, appliances, catalog products).
- `lib/services/` — app services for auth, Firestore operations, cart persistence, order placement, notifications, storage.
- `lib/screens/` — UI pages grouped by role:
  - `auth/` (login, OTP, admin login)
  - `user/` (home, catalog, cart, checkout, orders, profile, appliances, service requests, referral, notifications, etc. **inferred from router**)
  - `admin/` (command center, requests, warranty, payouts, reports, marketing, products, orders, settings, agents, notifications **inferred from router + a subset verified**)
  - `common/` (help center, contact support, legal **inferred from router**)

### Relationships (high level)
- Screens call into services (`AuthService`, `FirestoreService`, `OrderService`, `CartService`, etc.).
- Services read/write Firestore and Storage and expose streams/futures to the UI.
- Models define the stable schema boundary between UI and Firestore documents.

---

## 3. ARCHITECTURE OVERVIEW

### Architectural style
- **Modular / layered Flutter app:**
  - Presentation: `lib/screens/**`
  - Domain-ish models: `lib/models/**`
  - Data/services layer: `lib/services/**`
  - App composition: `lib/main.dart`, `lib/app/router.dart`

### Core components and interaction
- **Routing + guard:** `AppRouter` redirects based on auth state and admin role.
- **Auth:** `AuthService` handles phone OTP flow, admin login bypass, user provisioning.
- **Data access:** `FirestoreService` centralizes Firestore collection access and business operations.
- **Commerce engine:** `CartService` persists cart; `OrderService` places orders with stock validation.
- **Notifications:**
  - `PushNotificationService` configures FCM + foreground local notifications.
  - `NotificationService` creates notification records in Firestore and combines personal/global notifications streams.
  - Cloud Function `sendPromoNotification` sends a broadcast push when a new promo notification is created.
- **Local warranty reminders:** `WarrantyNotificationService` schedules device-local reminders based on warranty end dates.

### Control flow direction
UI → Services → Firebase (Firestore/Storage/Messaging) → UI via Streams/refresh.

### Dependency flow
- Screens depend on services and models.
- Services depend on Firebase SDKs and models.
- Router depends on `AuthService`.

### Inversion of control
- Providers in `main.dart` inject services to widget tree.
- Router uses a static `AuthService` instance for redirects (note: this is *not* Provider-based).

---

## 4. EXECUTION & LOGICAL FLOW

### Entry point
- `main()` in `lib/main.dart`:
  1. Initializes Flutter bindings.
  2. Initializes Firebase app.
  3. Activates Firebase App Check (debug providers in debug mode; stronger providers in production).
  4. Initializes push notifications (FCM permissions, channel, listeners, token).
  5. Initializes warranty notification scheduler (timezone + channel).
  6. Runs `VigneshAgenciesApp`.

### App startup composition
- `VigneshAgenciesApp` builds `MaterialApp.router`:
  - Theme + theme mode via `ThemeProvider`.
  - Router config via `AppRouter.router`.
  - Providers register `AuthService`, `FirestoreService`, `StorageService`, `OrderService`, `CartService`, and notification services.

### Auth and routing flow
- Router starts at `/login`.
- Router `redirect` logic:
  - If not logged in and trying to access any non-login route → redirect to `/login`.
  - If logged in and visiting login/otp/admin-login routes → determine admin role and redirect to `/admin` (admin) or `/home` (user).

### Primary user-mode execution paths (verified/inferred)
1. Login via phone OTP
   - User enters phone → OTP sent → OTP verified → user record is created/updated → user is sent to `/home`.
2. Browse catalog + cart
   - Product list and product details routes exist.
   - Cart stored locally in memory and persisted to Firestore `carts/{userId}`.
3. Checkout → place order
   - Checkout validates stock/price/availability before placing.
   - Order placed via `OrderService.placeOrder` which performs an atomic Firestore transaction.
4. Order tracking + actions
   - User can cancel orders (only before shipping/delivery).
   - Delivered orders show a “Register for Warranty” action.
5. Warranty lifecycle
   - Users register appliances (route exists) and admins validate registrations.
6. Service requests
   - User creates request per appliance; admin assigns/updates status; user can submit feedback when completed.

### Primary admin-mode execution paths (verified/inferred)
- Admin login screen validates a single hard-coded credential pair and creates an admin session.
- Admin shell exposes command center + service requests + warranty + payouts + reports + notifications + settings, etc.

---

## 5. IMPORTANT MODULES, FILES & CLASSES

### `lib/main.dart`
**Responsibility:** app bootstrap + dependency injection.
- Side effects: Firebase init, App Check activation, notification initialization.

### `lib/app/router.dart` (`AppRouter`)
**Responsibility:** all routes + auth/admin redirect gate.
- Inputs: current route, auth state, admin check.
- Outputs: navigation decisions.
- Side effects: subscribes/unsubscribes to promo topic on user/admin shell init.

### `lib/services/auth_service.dart` (`AuthService`)
**Responsibility:** authentication and user record management.
- Key methods:
  - `sendOTP(...)` → triggers Firebase phone verification, handles errors.
  - `verifyOTP(verificationId, otp)` → signs in and ensures Firestore user doc exists.
  - `bypassOTPVerification(phone, otp)` → dev/test bypass that signs in anonymously and links to a “real” user via `linkedAccountId` (only active when `testMode` is true).
  - `bypassAdminLogin()` → signs in anonymously and writes a Firestore user doc with `isAdmin: true`.
  - `isCurrentUserAdmin()` → loads user model and caches admin flag.
  - `redeemReferral(code)` → atomic batch: creates referral record + marks user as referred.
- Side effects: writes to Firestore `users`, `referrals`.
- Notable behaviors:
  - Uses “linked account” mechanism for bypass mode; certain reads resolve to linked user.
  - `testMode` constant is currently `false` (verified).

### `lib/services/firestore_service.dart` (`FirestoreService`)
**Responsibility:** primary Firestore data API for the app.
- Collections used (verified):
  - `categories`, `support_messages`, `marketing_banners`, `products` (user appliances), `service_requests`, `referrals`, `users`, `catalog_products`, `orders`, `agents`.
- Key capabilities (verified):
  - Warranty products: add, stream per user, pending validation stream, update status, adjust purchase date.
  - Service requests: create, stream per user/product/all, update status & assignment, set estimated completion date, mark completed, submit feedback.
  - Referrals: create, approve, update to purchased, mark paid, compute pending payout users, mark a user payout complete.
  - Orders: user/admin streams, update status with transaction + version check, cancellation with stock restoration.
  - Catalog: stream active products with optional category filter and client-side search; stream admin list; add/update/delete products.
  - Agents: CRUD and active filtering.
- Side effects: many Firestore reads/writes, transactions, batch updates.

### `lib/services/order_service.dart` (`OrderService`)
**Responsibility:** place orders with inventory safety.
- Key methods:
  - `placeOrder(...)` (transaction):
    - Validates availability/active status.
    - Validates stock if `trackInventory`.
    - Decrements stock if tracking.
    - Creates order in `orders`.
  - `validateCart(cartItems)`:
    - Returns issues for out-of-stock/unavailable items.
    - Detects price change if difference > ₹1.
- Side effects: Firestore reads and transaction writes.

### `lib/services/cart_service.dart` (`CartService`)
**Responsibility:** in-memory cart with Firestore persistence.
- Key behaviors:
  - `initializeCart(userId)` loads `carts/{userId}`.
  - `addToCart(...)` respects max stock when inventory tracking is enabled.
  - `updateQuantity(...)` clamps to available stock.
  - Writes updates to Firestore `carts/{userId}`.

### `lib/services/push_notification_service.dart` (`PushNotificationService`)
**Responsibility:** configure FCM + local notification display.
- Initializes permissions, notification channel, foreground handling.
- Subscribes/unsubscribes to topic `promo_notifications` based on role.
- Side effects: device permission prompts, local notification channel creation.

### `lib/services/notification_service.dart` (`NotificationService`)
**Responsibility:** Firestore-backed notification feed + read tracking.
- Stores broadcast notifications in `promo_notifications`.
- Stores targeted notifications under `users/{userId}/notifications`.
- Merges personal + global notifications and marks global read via `users/{userId}/read_notifications`.

### Cloud Function: `functions/index.js`
**Responsibility:** sends FCM push to topic `promo_notifications` when a new Firestore document is created in `promo_notifications/{id}`.
- Skips inactive docs (`isActive === false`).
- Sends FCM with `notification` + `data` payload.

### Storage rules: `storage.rules`
**Responsibility:** define auth + path-based access for uploads.
- Auth required for reads across most paths.
- User-scoped writes for `bills/`, `warranty_cards/`, `profiles/`.
- Evidence/audio write paths are authenticated-only but not user-scoped to ownership (risk; see section 9).

---

## 6. CORE LOGIC (ABSTRACTED)

### A) Router access gate (decision tree)
- If user is not authenticated and route is not one of `{login, otp, admin-login}` → redirect to `/login`.
- If user is authenticated and route is an auth route → check admin flag:
  - admin → `/admin`
  - non-admin → `/home`
- Else allow navigation.

### B) User OTP login (high-level)
1. User submits phone.
2. App requests OTP via Firebase Phone Auth.
3. On OTP entry:
   - Create credential → sign in.
   - Ensure Firestore `users/{uid}` exists/updated.
4. Navigate to `/home`.

### C) Admin login bypass (high-level)
1. Admin enters email/password.
2. UI checks against hard-coded credential pair.
3. If match:
   - Sign in anonymously.
   - Write `users/{uid}` with `isAdmin: true`.
4. Navigate to `/admin`.

### D) Cart validation + order placement (conceptual algorithm)
- On checkout confirm:
  - Validate cart items:
    - For each product: ensure exists and active.
    - If inventory tracking: ensure `stockQuantity >= requested`.
    - Ensure current price is within ₹1 of cart price.
  - If valid → place order:
    - Transaction:
      - Re-validate each product.
      - Decrement stock for tracked inventory.
      - Create `orders/{id}` document with items snapshot.

### E) Order update with version (admin)
- Transaction:
  - Read order.
  - If `expectedVersion` provided and mismatched → reject with “refresh required.”
  - Update status + increment version.
  - If delivered: set delivered timestamp and add “digital coins” = 5% of order amount (rounded) to user.

### F) Order cancel (user)
- Transaction:
  - Validate order exists and belongs to user.
  - Forbid cancellation once shipped or delivered.
  - Restore stock for inventory-tracked items.
  - Set status cancelled + record cancellation metadata + increment version.

### G) Warranty registration and validation
- User appliances live in Firestore `products` collection with `ProductStatus`.
- Admin approves a pending appliance:
  - Update status to `active`, record validator + validated timestamp.
  - When status becomes active, referral processing may run for first validated product (**verified in `updateProductStatus` calling `_processReferralForProduct`**).

### H) Referral lifecycle (verified; note constants)
- Redemption:
  - User redeems code → creates `referrals` record with status `pending` and marks user doc `referredBy`.
- Purchase outcomes:
  - There are multiple purchase-related flows in `FirestoreService`:
    - `updateReferralToPurchased` uses `ReferralModel.fixedCommission` (₹500 constant).
    - `_processReferralForProduct` and `_processReferralForOrderDelivery` use `commission = 100.0`.
  - This is a **consistency risk** (see section 9).
- Payout completion:
  - Admin can mark user payout complete: all purchased referrals become paid; user pending payout resets.

### I) Warranty expiry reminders (device-local)
- For each active, under-warranty appliance:
  - Schedule notifications at 30/7/3/1 days before expiry.
  - Persist scheduled IDs in shared preferences to avoid duplicates.

---

## 7. CONFIGURATION & ENVIRONMENT

### Flutter dependencies (from `pubspec.yaml`)
- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_app_check`, `firebase_messaging`.
- Routing/state: `go_router`, `provider`.
- Notifications: `flutter_local_notifications`, `timezone`.
- Media/utilities: `image_picker`, `flutter_image_compress`, `cached_network_image`, `record`, `audioplayers`.
- Sharing/links/storage: `share_plus`, `url_launcher`, `path_provider`, `shared_preferences`.
- PDF/printing: `pdf`, `printing`.

### Firebase app configuration
- `firebase.json` includes project IDs and output mappings for FlutterFire.
- Cloud Functions runtime is Node.js 20.
- Storage bucket configured (`freelancing-mumbai`).

### Feature flags / toggles
- `AuthService.testMode` (boolean constant) controls bypass OTP mode. Currently `false`.

### Unclear from code
- Firestore security rules are not present in the folder; actual access control depends on deployed rules.

---

## 8. DEPENDENCIES & INTEGRATIONS

### External services
- **Firebase Authentication:** phone OTP and anonymous sign-in.
- **Cloud Firestore:** primary data store (orders, products, service requests, referrals, marketing banners, agents, carts, notifications).
- **Firebase Storage:** uploads for bills, warranty cards, evidence images, audio recordings, profile images.
- **Firebase Cloud Messaging:** push notifications (topic-based broadcast).
- **Cloud Functions:** sends a push on new `promo_notifications` documents.

### Internal module dependencies (observed)
- Screens depend on services via `Provider`.
- `router.dart` depends on `AuthService` and on `PushNotificationService` for role-based topic subscription.
- `checkout_screen.dart` uses `OrderService` for validation/order placement and uses `AuthService.getResolvedUserId()` to handle linked/bypass accounts.

---

## 9. EDGE CASES, LIMITATIONS & RISKS

### Auth/admin risks
- **Hard-coded admin credentials in UI** (`admin@vigneshagencies.in` / `Admin@123`). This is operationally risky unless access is otherwise restricted.
- Admin login uses anonymous auth + writes `isAdmin: true` into a Firestore user doc. Without strict Firestore security rules, this is sensitive.

### Data security depends on Firestore rules (missing in repo)
- Because Firestore rules are not included, it’s **unclear** what prevents:
  - A user reading another user’s orders.
  - A user writing admin-only fields.

### Storage rules ownership gaps
- Evidence and audio uploads are authenticated-only but **not** constrained to a user ID path in `storage.rules`:
  - `/evidence/{requestId}/**` writes allowed for any authenticated user.
  - `/audio/{requestId}/**` writes allowed for any authenticated user.
  - This may be intended (e.g., technicians/admin) but ownership boundaries are not explicit.

### Referral commission inconsistency
- Commission values differ across flows:
  - `updateReferralToPurchased` uses ₹500.
  - Other referral processing uses ₹100.
  - This can cause mismatched payouts depending on which path is used.

### Inventory modeling nuance
- `CatalogProductModel` supports per-variation stock, but `OrderService` validates stock using product-level `stockQuantity` (and `trackInventory`).
  - Variation stock handling is not clearly enforced in the order placement transaction (Unclear from code; needs broader file read).

### Concurrency
- `updateOrderStatus` supports optimistic concurrency with `version` and `expectedVersion`.
  - Some UI paths may not supply `expectedVersion` (Unclear from code without reading those admin screens fully).

### Known lint-level issues (from editor diagnostics)
- Unused private method `_autoRegisterAppliancesFromOrder` exists but is not referenced.
- A null-check in `AuthService` is flagged as always true (static analysis finding).

---

## 10. HOW TO USE THIS PACKAGE

### Conceptual initialization
- The app is launched through `main()` which initializes Firebase and notifications.
- The routing system enforces login before any main functionality.

### Typical usage patterns (conceptual)
- Customer:
  1. Login (OTP)
  2. Browse catalog → add to cart
  3. Checkout (address + COD)
  4. Track orders; cancel if eligible
  5. Register appliances for warranty; create service requests; view notifications
- Admin:
  1. Login via admin login screen
  2. Review and validate warranty registrations
  3. View/assign/update service requests
  4. Manage catalog and orders
  5. Mark referral payouts complete
  6. Generate service reports
  7. Send broadcast notifications

### Required setup steps (inferred from usage)
- Firebase project must be configured and accessible.
- Firestore collections used by the app must exist and have expected fields.
- Storage rules should be deployed if uploads are used.
- Cloud Functions should be deployed if push broadcast is expected.

---

## 11. EXTENSION & MODIFICATION GUIDELINES

### Where to add new logic (based on current patterns)
- New Firestore-backed business operations → add methods to `FirestoreService`.
- New non-trivial commerce logic (inventory, pricing) → add/extend `OrderService`.
- New user-visible entities → add a `Model` with `fromFirestore/toFirestore` and then integrate into the appropriate service.
- New screens/routes → register in `lib/app/router.dart` and follow role shell patterns.

### What should NOT be modified casually
- Route redirect logic in `AppRouter` (affects all access control flows).
- Order status update transaction and `version` semantics (affects admin concurrency).
- Referral payout methods (affects money/accounting outcomes).
- Storage rules without a clear ownership model.

### How to add features safely (pattern)
- Add model fields with backward-compatible defaults in `fromFirestore`.
- Ensure all writes set server timestamps where appropriate.
- Prefer transactions or batch writes when updating multiple documents that must stay consistent.

---

## 12. OPEN QUESTIONS & AMBIGUITIES

- Firestore security rules are not present: **Unclear from code** what enforces access control.
- Variation-level stock and pricing enforcement in `OrderService`: **Unclear from code** without reading full catalog/cart integration paths.
- Warranty “Register for Warranty” flow implementation: route exists and UI button exists, but the exact registration behavior is **Unclear from code** because the `AddProductScreen` and related services were not inspected in this pass.
- Service request evidence upload process: storage rules exist, but how files are uploaded and how ownership is tracked is **partially inferred from usage**.
- Agent assignment logic: agents exist in FirestoreService; how agents are selected/assigned in UI is **Unclear from code** without reading `AgentsManagementScreen` and service request admin screens.

---

## 13. TL;DR FOR NEW ENGINEERS

- This is a Flutter app with two roles: **User** and **Admin**, routed by an `isAdmin` flag in Firestore.
- Everything important lives in Firestore: `users`, `orders`, `catalog_products`, `products` (appliances), `service_requests`, `referrals`, etc.
- Orders are placed via a **transaction** that checks product availability and stock (when tracked) and decrements inventory.
- Admin order updates use **versioned transactions** to reduce conflicting edits; delivery credits “digital coins” at 5%.
- Warranty registrations are stored as “products/appliances” and must be **validated by admin** to become active.
- Service requests are state machines with timestamps and optional feedback.
- Notifications combine Firestore-stored promos with FCM broadcast; warranty reminders are **scheduled locally** on device.

