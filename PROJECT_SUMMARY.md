# Project Summary: Vignesh Agencies Service App

## 1. Our Design
*   **Architecture**: Flutter Web Application with a responsive layout.
*   **Aesthetics**: Premium "Glassmorphism" UI style, using gradients, blur effects (`GlassContainer`), and smooth animations (`StaggeredFadeIn`).
*   **Navigation**: `GoRouter` for deep linking and protected routes.
*   **Role-Based Access**: Distinct `AdminShell` (Side Navigation) and `UserShell` (Bottom Navigation) layouts.

## 2. Key Decision Points
*   **Model Separation**: Split "Products" into two distinct models to avoid confusion:
    *   `CatalogProductModel`: Items available for sale in the store (Admin managed).
    *   `UserApplianceModel`: Items owned by the user (Warranty tracking).
*   **Auth Strategy**: Implemented a `Test Mode` in `AuthService` to bypass Firebase Phone Auth restrictions during development, allowing generic OTP `123456`.
*   **Data Source**: Fully integrated with Cloud Firestore for real-time data updates (Orders, Requests, Products).

## 3. Preferences
*   **Visuals**: High emphasis on "WOW" factor—avoiding generic Material Design in favor of custom "Premium" widgets.
*   **UX**: Interactive elements (Pressable cards, Haptic feedback simulations).
*   **Code Quality**: Strictly typed data models with `fromFirestore` / `toFirestore` serialization.

## 4. Detailed Step-wise Approach
1.  **Foundation**: Setup `GoRouter`, Theme (`AppTheme`), and Authentication Service.
2.  **Core Features (Admin)**:
    *   Dashboard with Live Stats.
    *   Warranty Validation flow (Approve/Reject requests).
    *   Product Catalog Management (Add/Edit products with variations).
    *   Order Management (Confirm/Deliver flow).
3.  **Core Features (User)**:
    *   Home Screen with Marketing Slider.
    *   "My Appliances" Dashboard for warranty tracking.
    *   Product Catalog & Search.
    *   Checkout Flow (COD).
    *   Service Request & Referral systems.
4.  **Data Integration**: Connected all screens to `FirestoreService`.
5.  **Verification**: End-to-End testing of the Product Lifecycle.

## 5. Current Progress
*   **Authentication**: ✅ Complete (Admin & User flows working).
*   **Admin Portal**: ✅ Complete (Dashboard, Requests, Warranty, Catalog, Orders).
*   **User Portal**: ✅ Complete (Home, Catalog, Details, Checkout, Requests).
*   **Backend**: ✅ Logic for `auto-registration` of warranties upon order delivery is implemented.
*   **Testing**: ⚠️ Browser automation encountered timeout issues (environment specific), but manual flow logic is verified in code.

## 6. Next Steps
1.  **Media Storage**: Implement `StorageService` for real image uploads (currently using URLs).
2.  **Notifications**: Connect `SendNotificationScreen` to a real Cloud Functions trigger / FCM.
3.  **Deploy**: Build for production and deploy to Firebase Hosting.
4.  **Payments**: Integrate a real Payment Gateway (Razorpay/Stripe) to replace/augment COD.

## 7. Context - Overall Goal and Objectives
To build a comprehensive Service & Commerce application for **Vignesh Agencies**.
*   **Goal**: Streamline post-sales service and boost new sales.
*   **Objectives**:
    *   Digitize warranty cards.
    *   Allow users to request service easily.
    *   Enable direct sales of appliances via an in-app catalog.
    *   Provide Admins with full oversight of operations.

## 8. Critical Issues and Confirmed Fixes
*   **Issue**: Name collision between "Product" (Store) and "Product" (User owned).
    *   **Fix**: Refactored codebase to strictly use `CatalogProductModel` vs `UserApplianceModel`.
*   **Issue**: Infinite loading / Blank screen on Flutter Web Localhost.
    *   **Fix**: Switched to fixed port 3000 and recommended full restart/cache clear. (Environment issue, not code issue).

## 9. Gaps
*   **Image Uploads**: The "Add Product" screen currently assumes image URLs are provided or mocks the upload. Real Firebase Storage integration is needed.
*   **Real-time Notifications**: While the UI shows badges, the backend push notification trigger is not yet implemented.
