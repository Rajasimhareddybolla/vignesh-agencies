# Client-Facing System Explanation (Vignesh Agencies Service App)

## 1. THE CORE IDEA
This system is a **two-sided operations hub** for an appliance business:
- A **customer portal** for warranty visibility, service requests, notifications, and buying products.
- An **admin portal** for validating warranties, running service operations, managing products/orders, handling referral payouts, and producing service reports.

Problem space:
- Post-sales service (tickets, assignment, completion, feedback)
- Warranty registration and approval
- Direct-to-customer commerce (catalog → cart → checkout → orders)
- Referral-driven growth and payout tracking

What it replaces/improves:
- Fragmented workflows across phone calls, spreadsheets, and paper warranty cards.
- Manual follow-ups on warranty expiry and service ticket progress.
- Ad-hoc catalog/order tracking without inventory-aware checkout.

## 2. HOW TO THINK ABOUT THIS SYSTEM
Metaphor: **“A digital front desk + a back office control room.”**
- Customers use the front desk to register appliances, request service, track orders, and view announcements.
- Admins use the control room to validate warranty claims, route work, and close the loop on payouts and reporting.

What it behaves like:
- A **workflow system** where core entities have **explicit statuses** (e.g., service requests, orders, warranty registrations).
- A **real-time dashboard** experience (lists and counts update as records change).

What it does NOT behave like:
- Not a “hands-off autopilot”: service resolution, warranty approval, and payouts still require people.
- Not a payment platform: checkout is explicitly **Cash on Delivery**.
- Not a guaranteed communications system: notifications depend on device permissions and platform limits.

## 3. VALUE PROVIDED
What users gain:
- **Warranty clarity**: appliances have a warranty status (pending validation / active / expiring / expired / rejected) and expiry reminders.
- **Faster service intake**: customers can raise a ticket with structured issue details and optional evidence.
- **Transparent progress**: tickets and orders expose their lifecycle state (pending → in progress → completed, etc.).
- **Commerce convenience**: browse catalog, maintain a cart, and place orders with stock/availability checks.
- **Referral benefits tracking**: redeeming a referral code creates a tracked referral record; admins can review and pay out commissions.

Work reduced/eliminated:
- Manual warranty card storage and repeated “is my warranty active?” queries.
- Manual cart/order sanity checks (availability, stock shortfalls, and price changes are checked at checkout).
- Manual “who has pending referral payouts?” aggregation (admin sees users with pending payouts).

Where human involvement is still required:
- Admin decisions for **warranty validation** (approve/reject, optionally record rejection reasons).
- Admin workflow steps for **service request assignment and status updates**.
- Admin action to **mark payouts complete**.
- Real-world fulfillment: shipping, delivery, service visits.

## 4. SYSTEM GUARANTEES
These are behaviors the system consistently enforces in code:

Authentication & access routing
- Users must be signed in to access non-auth screens; unauthenticated access is redirected to the login flow.
- After login, the system routes users into **either User mode or Admin mode** based on the account’s admin flag.

Order integrity (customer-facing)
- Checkout validates cart items for **availability**, **stock sufficiency**, and **material price changes** before the order is placed.
- When an order is placed, stock tracking (when enabled for a product) prevents overselling by validating and decrementing stock as part of the same “place order” operation.
- A user can cancel their own order only while it is **pending or confirmed** (not shipped/delivered). Cancellation restores stock for inventory-tracked products.

Admin-controlled workflows
- Admins can update service requests with explicit statuses (pending/assigned/in progress/resolved/completed/escalated/cancelled) and record assignment and completion timestamps.
- Admins can approve/deny warranty registrations; approval activates warranty status for the appliance.

Referral guardrails
- A user can redeem a referral code only once (a second redemption is rejected).
- A user cannot redeem their own referral code.

Notifications (behavioral)
- Users (non-admin) are configured to receive broadcast promotional notifications; admins are configured not to be subscribed to those broadcasts.
- The system tracks whether notifications are “read” (for both personal and broadcast notifications).

Data upload boundaries (when the shipped storage rules are deployed)
- Storage access requires authentication.
- User-specific uploads (e.g., bills/warranty cards/profile images) are restricted to the authenticated user’s own area.
- File size limits are enforced (images up to 10MB; audio up to 50MB).

## 5. NON-GUARANTEES
Outcomes the system does not (and cannot) ensure:

Real-world outcomes
- Delivery dates, service technician arrival, and service quality are not guaranteed by the system.
- “Resolved” or “completed” status reflects recorded workflow state, not an independently verified real-world result.

Data correctness depends on inputs
- Warranty correctness depends on the accuracy of user-provided purchase details and proof documents, and on admin validation decisions.
- Service request quality depends on issue description and evidence quality.

Notifications are best-effort
- Promotional push delivery depends on device OS permissions, network conditions, and platform constraints.
- Warranty expiry reminders are device-local; they can be missed if notifications are disabled or if the OS restricts scheduling.

Security/visibility depends on deployed backend rules
- This repo includes Firebase Storage rules, but does not include Firestore database rules. Data visibility guarantees (e.g., “users can only read their own orders”) ultimately depend on the backend rules actually deployed.

## 6. FAILURE & RECOVERY MODEL
How failures surface to users:
- Authentication failures show explicit messages (e.g., invalid/expired OTP, too many attempts).
- Operational failures typically surface as in-app error messages (e.g., “failed to validate cart”, “order not found”).
- Some failures may appear as missing/empty data views if the backend is unreachable or queries fail.

What recovery looks like:
- Retry-oriented recovery is built in: users can re-send OTP after a cooldown; pages support refresh behaviors; checkout can be retried after cart corrections.
- For order concurrency conflicts (admin updates), the system can reject a stale update and require refresh before retry.

When escalation is required:
- Repeated OTP blocking (“too many attempts”) requires waiting or support intervention.
- If notifications consistently fail across devices, escalation requires checking backend messaging setup and device permission policies.
- If data is unexpectedly visible/hidden, escalation requires reviewing deployed database access rules.

## 7. EXPECTED USER RESPONSIBILITIES
Customers must provide correctly:
- A valid phone number for OTP login.
- Accurate appliance details and purchase information when registering warranties.
- Service request details (issue type/description) and optional evidence when needed.

Customers must verify:
- Delivery address and order totals at checkout.
- Order status and cancellation eligibility before attempting cancellation.

Admins must provide and verify:
- Warranty approvals/rejections (including rejection reasons when applicable).
- Service request assignments and status updates.
- Payout completion confirmation before marking payouts as paid in the system.
- Report date ranges and report outputs before sharing externally.

Users should monitor:
- Warranty expiry reminders and appliance warranty status.
- Service ticket updates and required follow-ups.
- Referral payout balances (pending payout vs paid).

## 8. SUMMARY FOR DECISION MAKERS
When this system is a good fit:
- You need a **single system** that combines warranty registration/validation, service ticketing, and a basic commerce flow.
- You want **role-based operations** (customer vs admin) with clear workflow statuses.
- You want to run **referrals with payout tracking** and a simple “mark paid” admin flow.

When it is not a good fit:
- You need online payments (UPI/cards) as a primary checkout method (current flow is COD).
- You need fully automated service dispatching and SLA enforcement without human operators.
- You require strong contractual guarantees on notification delivery or device scheduling.

Key risks and dependencies:
- Requires a correctly configured backend (authentication, database, storage, and optional messaging). Missing or permissive database rules can materially change privacy/security outcomes.
- Admin access hinges on controlling the admin login credentials and the admin account’s privileges.
- Operational performance and reliability depend on network connectivity and device permission policies (especially for notifications and uploads).
