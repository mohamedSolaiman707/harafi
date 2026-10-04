# Harafy Web — Security Audit

> **Verification Date:** 2026-09-22  
> **Pass:** Second — Read-Only Security Verification  
> **Evidence sources:** All SQL files in `supabase/`, Dart source in `lib/`, Edge Function TypeScript in `supabase/functions/`  
> **No code was modified during this pass.**

---

## 1. Supabase RLS Verification

> **IMPORTANT CLARIFICATION:** The Supabase `anon` key in the Flutter client is **expected and normal**. The security question is not whether the key is present, but whether the RLS policies correctly protect data when the anon key is used.

### Complete RLS Policy Inventory

The following SQL files were inspected in `supabase/`:

| Table | RLS Enabled | Policies Found | Effective Access |
|---|---|---|---|
| `orders` | NOT VERIFIED | NOT IN REPO | See note below |
| `technicians` | NOT VERIFIED | NOT IN REPO | See note below |
| `order_logs` | NOT VERIFIED | NOT IN REPO | See note below |
| `order_messages` | ✅ Enabled | `FOR ALL USING (true)` | **Fully open — anyone** |
| `wallet_recharges` | ✅ Enabled | `FOR ALL USING (true)` | **Fully open — anyone** |
| `warranty_claims` | ✅ Enabled | `FOR ALL USING (true)` | **Fully open — anyone** |
| `job_outcomes` | ✅ Enabled | Public SELECT, Authenticated INSERT/UPDATE | Public read of all AI analysis data |
| `scheduled_orders` | NOT VERIFIED | ALTER TABLE only, no CREATE POLICY | Likely inherits `orders` policy |
| `technicians_verification` | N/A | ALTER TABLE only (adds columns to `technicians`) | Inherits `technicians` policy |
| `promo_codes` | ✅ Enabled | `FOR ALL USING (true)` | **Fully open — anyone** |
| `services` | ✅ Enabled | Public SELECT ✅, Authenticated ALL ⚠️ | Any logged-in user can modify |

> **NOT VERIFIED — evidence unavailable:** The primary `orders` and `technicians` tables do not have SQL migration files in the repository. Their schema and RLS policies were applied directly to Supabase without being committed to the repo. This is the single most important gap in the audit.

### What the Evidence Tells Us About `orders` and `technicians` RLS

Even without the SQL files, the Flutter Dart code reveals the effective behavior:

**`orders` table evidence:**
- `TrackScreen` (line 30-42): Watches `ordersStreamProvider`, then filters by `trackingCode` **in Dart** — meaning all orders are fetched client-side and filtered locally. This proves the Supabase query returns all orders visible to the current session.
- `client_orders_screen.dart` `clientOrdersProvider`: Fetches orders by phone number — the Supabase query filters by `client_phone`. But there is no server-enforced guarantee that Customer A cannot query with Customer B's phone number.
- `TrackScreen` allows cancel via `adminActionsProvider.cancelOrder()` — this is the same action the admin uses. There is no customer-vs-admin distinction on the write path.

**`technicians` table evidence:**
- `smart-match/index.ts` (line 185): Uses `SUPABASE_SERVICE_ROLE_KEY` to query technicians — correct for an Edge Function.
- But `techniciansProvider` in Flutter reads from `SupabaseTechniciansRepository` using the anon key. All technician fields (including `phone`, `wallet_balance`, `total_earnings`, `national_id_front_url`, `national_id_back_url`, `criminal_record_url`, `admin_note`) are fetched and used in the client. The `toJson()`/`fromJson()` on the model maps all these fields.

---

## 2. Access Scenario Analysis (D4 — Customer Identity & Order Security)

### Scenario A: Can Customer B access Order A knowing only the tracking code?

**YES — HIGH severity.**

Evidence: `TrackScreen.build()` (line 30-42):

```dart
final ordersStream = ref.watch(ordersStreamProvider);
// ...
final order = orders.where((o) => o.trackingCode == code).firstOrNull;
```

`ordersStreamProvider` fetches **all** orders (or all orders accessible to the current session). The tracking code filter is done **in Flutter/Dart**, not in Supabase. This means:

1. The client receives all orders from Supabase
2. Dart finds the one with the matching tracking code
3. That order is displayed to whoever loaded the URL

**If RLS on `orders` is `USING (true)` (likely, given the pattern of all other tables):** Any person who knows any tracking code can view that order's full details — including `clientName`, `clientPhone`, `address`, `service`, all status updates, messages, and cost.

**If RLS correctly restricts orders to authenticated users only:** The anonymous user would still see the order if the query is made with the anon key and the policy allows anon reads. This needs verification in Supabase dashboard.

**Severity: 🔴 Critical** — tracking codes are sent over WhatsApp to customers. They can be forwarded or guessed.

---

### Scenario B: Can Customer A query orders for phone number B?

**YES — HIGH severity.**

`client_orders_screen.dart` `clientOrdersProvider` accepts a phone number and searches for all orders with that phone. The OTP verification only happens on the **device** (SharedPreferences check) — not server-side. If the OTP code is bypassed (e.g., by calling the Supabase API directly with the anon key), any phone number can be queried.

Evidence:
```dart
// client_orders_screen.dart line 257
ref.watch(clientOrdersProvider(submittedPhone))
```

The `clientOrdersProvider` is a Riverpod provider that calls the repository with a phone number string. The repository calls Supabase. There is no Supabase Auth JWT associated with the customer — customers are anonymous from Supabase's perspective.

**Severity: 🔴 Critical** — A direct API call with any phone number returns all orders for that phone, with no OTP.

---

### Scenario C: Can a customer modify another customer's order?

**YES — HIGH severity.**

`TrackScreen` calls `adminActionsProvider.cancelOrder()` on any order returned by the stream. There is no ownership check before calling cancel. If an attacker loads `/track/{code}` for another customer's order and sees it, they can cancel it.

Evidence: `track_screen.dart` line 255:
```dart
await ref.read(adminActionsProvider).cancelOrder(order, ...);
```

The `adminActionsProvider.cancelOrder()` calls `ordersRepositoryProvider.updateOrderStatus()` which calls Supabase directly. If the `orders` table RLS allows any session to update any order, this works cross-customer.

**Severity: 🔴 Critical** — Order cancellation requires no ownership proof.

---

### Scenario D: Can Customer A see Customer B's private data via tech portfolio?

**PARTIALLY — MEDIUM to HIGH severity.**

`tech_portfolio_screen.dart` `_ReviewItem` widget (line 346):

```dart
Text(order.clientName, style: AppTextStyles.titleMed),
```

The tech portfolio page shows customer `clientName` next to their rating. This is a **public page** — no authentication required, no OTP.

`clientName` exposure: **Medium** — first name only in most cases, but still PII.

`clientPhone`, `address`: **NOT exposed** in the portfolio review widget. Only `clientName` and `ratingComment` are shown. ✅ Acceptable.

However, the underlying data model (`Order`) that is fetched for the portfolio contains the full order including `clientPhone`, `clientAddress` etc. Whether the Flutter code renders it or not, the data is transmitted to the client. An attacker could read the raw Supabase response.

**Severity: 🟠 High** — Customer names are exposed without consent. Full order data (including phone) is transmitted even if only name is rendered.

---

### Scenario E: Can a technician access another technician's orders?

**YES — MEDIUM severity.**

`TechOrderDetailScreen` accepts an `orderId` as a path parameter. `app_router.dart` line 161:

```dart
GoRoute(
  path: '/tech/order/:id',
  pageBuilder: (context, state) => AppAnimations.fadeSlide(
    child: TechOrderDetailScreen(orderId: state.pathParameters['id']!),
  ),
),
```

The route guard (line 58) only checks `isLoggedIn` — not which technician is logged in. Any authenticated technician who knows another technician's order ID can navigate to `/tech/order/{other_tech_order_id}`.

Whether the Supabase query for that order succeeds depends on the RLS policy on `orders`. Given the pattern of other tables, it likely succeeds.

**Severity: 🟠 Medium** — Requires authenticated technician session + knowledge of the order UUID.

---

### Scenario F: Can a technician access private customer information?

**YES — MEDIUM severity.**

`whatsapp_utils.dart` line 40-41:

```dart
'📞 الرقم: ${order.clientPhone}'
```

The tech notification message includes the customer's phone number. This is by design — the tech needs to call the customer. The risk is not the notification itself, but that once the tech has the order in `TechDashboardScreen`, the full order model (including phone, name, address) is available.

The tech's dashboard shows only their own orders filtered by `techId`. But as noted in Scenario E, a tech can potentially access other orders via direct URL.

**Severity: 🟡 Medium** — By-design for assigned orders. Problematic only if cross-order access (Scenario E) is possible.

---

### Protection Source Summary

| Protection Type | Used | Tables/Routes Protected |
|---|---|---|
| **GoRouter redirect** | ✅ Yes | `/admin/*`, `/tech/dashboard`, `/tech/order/*`, `/tech/profile`, `/tech/wallet` |
| **Supabase Auth JWT** | ✅ Yes | Tech/Admin login — Supabase Auth session required |
| **RLS policies** | ⚠️ Weak / NOT VERIFIED for core tables | `order_messages`, `wallet_recharges`, `warranty_claims`, `promo_codes` all use `USING (true)` |
| **SharedPreferences (OTP)** | ✅ Client-side only | Customer phone verification — bypassable via API |
| **Flutter UI conditions** | ✅ Yes (only) | Cancel button shown only for own orders by intent — not enforced server-side |
| **Database constraints** | ✅ For FK integrity only | Not used for authorization |
| **Edge Functions** | ✅ smart-match uses service role | Correct. analyze-problem has no auth check |

---

## 3. Admin Authorization Verification

### Admin Login Flow

Supabase Auth is used for admin login (`LoginScreen`). The GoRouter guard checks:

```dart
// app_router.dart, lines 37, 58-59
final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
// ...
if (isAdminRoute && !isLoggedIn) return '/login';
```

The check is: **any authenticated Supabase user** passes the guard. There is no role check.

### Admin Role Representation

`app_router.dart` line 36:

```dart
final userRole = prefs.getString('user_role');
```

The role is stored in `SharedPreferences` on the device. `SharedPreferences` is not transmitted to Supabase — it is a client-side key-value store. Supabase has no knowledge of it.

Evidence in the router: The `userRole` is used to decide where to redirect the user (`/admin` vs `/` vs `/tech/dashboard`). It is NOT used to check admin authorization on data operations.

### If an Attacker Bypasses the Flutter UI and Calls Supabase Directly

**Answer: Nothing prevents it for the tables with `USING (true)` RLS.**

Specifically:
- `wallet_recharges` — `FOR ALL USING (true)` → any anon user can approve a recharge
- `warranty_claims` — `FOR ALL USING (true)` → any anon user can update claim status
- `promo_codes` — `FOR ALL USING (true)` → any anon user can create, update, or delete promo codes including setting `is_active = false` on all codes
- `order_messages` — `FOR ALL USING (true)` → any anon user can write messages to any order
- `services` — `FOR authenticated USING (true)` → any authenticated user (even a tech) can modify service definitions

For `orders` and `technicians`: NOT VERIFIED. If they follow the same `USING (true)` pattern:
- Any authenticated user (tech or admin) can read, update, or delete any order
- Any authenticated user can update any technician's `wallet_balance`

### Admin Role Check — NOT VERIFIED for DB-Level

There is no `profiles` table, no `user_metadata`, no custom JWT claims in the repository. The admin role exists only in `SharedPreferences`. No Supabase RLS policy checks `auth.uid()` against an admin table.

**Severity: 🔴 Critical** — The admin panel is protected only by the Flutter router. A Supabase API call with a valid tech JWT can execute all admin operations.

---

## 4. WhatsApp API Token Verification

`lib/core/services/whatsapp_otp_service.dart` — Evidence from previous audit:

The UltraMsg API token is hardcoded directly in the Flutter Dart source. Flutter Web compiles to JavaScript (WASM + JS). The API token exists in the compiled JS bundle served to every browser.

### Extraction Method

1. Open browser DevTools
2. Navigate to Sources tab → find compiled Flutter JS
3. Search for the token string pattern
4. Token is in plaintext within the bundle

### Abuse Scenarios

1. Extract token from bundle
2. Call UltraMsg API directly with the token
3. Send arbitrary WhatsApp messages from the platform's account to any phone number
4. Generate fake OTP messages (identical format to real ones) to phone numbers
5. If UltraMsg charges per message, rapidly send thousands of messages

### Recommended Fix (Not Implemented)

Move to a Supabase Edge Function:
- Flutter calls `/functions/v1/send-otp` with just the phone number
- Edge Function reads the UltraMsg token from `Deno.env.get("ULTRAMSG_TOKEN")` (Supabase secrets, not the bundle)
- Edge Function sends the WhatsApp message
- Rate limiting can be applied in the Edge Function

This pattern is already in use correctly for `OPENAI_API_KEY` in both existing Edge Functions (line 93 in `analyze-problem/index.ts` and line 92 in `smart-match/index.ts`).

**Severity: 🔴 Critical** — Token is publicly extractable and enables message sending abuse.

---

## 5. Technician Public Profile Safety

### Fields in `Technician` Model (from `technician.dart` lines 18-41)

| Field | Type | Currently Shown on Portfolio | Public-Safe? | Notes |
|---|---|---|---|---|
| `id` | UUID | ✅ In URL | ⚠️ Safe but not ideal | Prefer slug for SEO |
| `name` | String | ✅ Yes | ✅ Public-safe | |
| `phone` | String | ✅ YES — as call button | 🔴 **NOT public-safe** | Direct link: `tel:${tech.phone}` |
| `spec` (ServiceType) | Enum | ✅ Yes | ✅ Public-safe | |
| `priceRange` | String? | ✅ Shown in UI | ✅ Public-safe | |
| `visitPrice` | int | ✅ Yes — stats row | ✅ Public-safe | |
| `area` | String? | ✅ Yes | ✅ Public-safe | |
| `status` | TechStatus | ✅ Shown as availability | ✅ Public-safe | |
| `rating` | double | ✅ Yes | ✅ Public-safe | |
| `totalJobs` | int | ✅ Yes | ✅ Public-safe | |
| `photoUrl` | String? | ✅ Yes | ✅ Public-safe | |
| `identityProofUrl` | String? | Not rendered on portfolio | 🔴 **NOT public-safe** | ID document URL |
| `nationalIdFrontUrl` | String? | Not rendered on portfolio | 🔴 **NOT public-safe** | National ID image |
| `nationalIdBackUrl` | String? | Not rendered on portfolio | 🔴 **NOT public-safe** | National ID back |
| `criminalRecordUrl` | String? | Not rendered on portfolio | 🔴 **NOT public-safe** | Criminal record document |
| `bio` | String? | ✅ Yes | ✅ Public-safe | |
| `totalEarnings` | int | Not rendered on portfolio | 🔴 **NOT public-safe** | Financial data |
| `walletBalance` | int | Not rendered on portfolio | 🔴 **NOT public-safe** | Financial data |
| `portfolioImages` | List\<String\> | ✅ Yes | ✅ Public-safe | Must not include ID docs |
| `isVerified` | bool | ✅ Yes | ✅ Public-safe | |
| `adminNote` | String? | Not rendered on portfolio | 🔴 **NOT public-safe** | Internal admin data |
| `createdAt` | DateTime | Not rendered | ⚠️ Neutral | Not sensitive |

### Critical Finding: All Fields Are Transmitted to the Client

Even though the portfolio page does NOT render `nationalIdFrontUrl`, `walletBalance`, `totalEarnings`, `adminNote`, `criminalRecordUrl`, the entire Technician JSON object is fetched from Supabase and deserialized in Flutter. The data is present in the browser's memory and in the raw Supabase API response.

An attacker using browser DevTools → Network → Supabase requests can see all fields in the JSON response.

**This means all private technician fields are currently exposed to any visitor of any page that loads the technicians list.**

### Phone Number on Portfolio (Current Issue)

Evidence: `tech_portfolio_screen.dart` line 115:

```dart
onTap: () => launchUrl(Uri.parse('tel:${tech.phone}')),
```

The phone number is rendered as a clickable `tel:` link on every public portfolio page. This exposes the technician's personal phone number to all website visitors.

**Severity: 🟠 High** — Technicians may not have consented to their personal phone being publicly listed on the web. If technician profiles are indexed by Google, their phone number becomes publicly searchable.

### `portfolioImages` vs ID Documents Risk

`fix_tech_avatars.sql` reveals there was a historical bug where `photo_url` was set to the same URL as `national_id_front_url` — displaying the tech's national ID card as their profile photo. The migration fixed this, but it implies `portfolioImages` could also potentially contain ID document URLs if uploaded incorrectly.

**Recommendation (not implemented):** Validate that no image in `portfolioImages` matches `nationalIdFrontUrl`, `nationalIdBackUrl`, `identityProofUrl`, or `criminalRecordUrl` before displaying.

---

## 6. Security + SEO Interaction Risks

> These are situations where SEO requirements could accidentally expose private data.

| SEO Goal | Private Data Risk | Mitigation Required |
|---|---|---|
| Index `/technician/[slug]` pages | Phone number currently on portfolio | Remove `tel:` from public portfolio before indexing |
| Index `/technician/[slug]` pages | National ID, criminal record URLs in Supabase JSON | Create a public-only Supabase view with safe fields only, or restrict `SELECT` policy |
| Index `/technician/[slug]` pages | Wallet balance, earnings, admin notes in response | Same — restricted SELECT projection |
| Show customer reviews on portfolio | `clientName` is shown next to review | Use first name only + last initial, or "ع.م" style anonymization |
| Show customer reviews on portfolio | `clientPhone` in underlying Order object | Ensure phone is NOT included in Supabase query for public profile data |
| Dynamic sitemap | Order tracking codes | NEVER include tracking codes in sitemap |
| Location pages `/technicians/[city]` | Aggregated tech phone numbers | Same restriction as portfolio |
| OG image for tech profiles | If OG image is fetched from Supabase Storage private URL | Use only public bucket URLs |

### Worst Case: Public Supabase API Call Exposes Everything

If `technicians` table has `USING (true)` RLS (likely based on pattern):

```bash
curl "https://[project].supabase.co/rest/v1/technicians?select=*" \
  -H "apikey: [anon_key]"  # anon key is in the Flutter bundle
```

This returns every technician's: name, phone, national_id_front_url, national_id_back_url, criminal_record_url, wallet_balance, total_earnings, admin_note.

**Before any SEO work, this query must be restricted.**

---

## 7. D7 — Required Database Changes

### Fields That Already Exist

| Field | Exists | Location |
|---|---|---|
| `name` | ✅ | `technician.dart` + DB |
| `phone` | ✅ | `technician.dart` + DB |
| `area` (service area) | ✅ | `technician.dart` + DB |
| `spec` (service type) | ✅ | `technician.dart` + DB |
| `bio` | ✅ | `technician.dart` + DB |
| `rating` | ✅ | `technician.dart` + DB |
| `total_jobs` | ✅ | `technician.dart` + DB |
| `visit_price` | ✅ | `technician.dart` + DB |
| `price_range` | ✅ | `technician.dart` + DB |
| `is_verified` | ✅ | `technician.dart` + DB |
| `portfolio_images` | ✅ | `technician.dart` + DB |
| `photo_url` | ✅ | `technician.dart` + DB |
| `national_id_front_url` | ✅ | Verification migration |
| `national_id_back_url` | ✅ | Verification migration |
| `criminal_record_url` | ✅ | Verification migration |
| `wallet_balance` | ✅ | `technician.dart` + DB |
| `total_earnings` | ✅ | `technician.dart` + DB |
| `admin_note` | ✅ | `technician.dart` + DB |

### Fields That Do Not Exist

| Field | Exists | Needed for SEO | Needed for Product | Notes |
|---|---|---|---|---|
| `slug` | ❌ | ✅ Yes — for `/technician/[slug]` URL | ✅ Useful — cleaner share links | Required. Can be derived from `name` |
| `years_experience` | ❌ | ⚠️ Nice to have | ⚠️ Nice to have | Not blocking |
| `working_schedule` | ❌ | ❌ No | ✅ Useful for customers | Not for SEO |
| `seo_description` | ❌ | ⚠️ Nice to have | ❌ No | `bio` already serves this purpose |
| `languages_spoken` | ❌ | ❌ No | ❌ No | Not needed |
| `certifications` | ❌ | ⚠️ Structured data | ⚠️ Marketing | Not blocking |

### Required Now

- **`slug`** — Required for SEO URL strategy. Can be `AUTO GENERATED` from `name` (e.g., `ahmed-ali` → `ahmed-ali-sbaak`). Must be `UNIQUE`.

### Required Later

- **`years_experience`** — Useful for structured data on tech profile pages when Next.js layer is built.

### Not Required

- `working_schedule` — Product feature, not SEO
- `seo_description` — `bio` is sufficient
- `languages_spoken` — Not needed

### Required DB Security Change (NOT a new field)

Create a **Supabase database view** named `technicians_public` that includes ONLY:

```sql
id, name, slug, spec, area, rating, total_jobs, photo_url,
bio, is_verified, visit_price, price_range, portfolio_images, status, created_at
```

This view must be used for all public/unauthenticated reads. The full `technicians` table must have its SELECT policy restricted to authenticated users (or specific roles).

---

## 8. Severity Classification Summary

| Finding | Severity | Evidence File | Action Required Before SEO |
|---|---|---|---|
| Tracking code gives full order access | 🔴 Critical | `track_screen.dart` L30-42 | Yes — add Supabase ORDER filter |
| Customer can query any phone's orders via API | 🔴 Critical | `client_orders_screen.dart` L257 | Yes — needs Edge Function or RLS |
| Order cancel has no ownership check | 🔴 Critical | `track_screen.dart` L255, `admin_actions_provider.dart` L163 | Yes |
| Admin panel frontend-only protection | 🔴 Critical | `app_router.dart` L36-52 | Yes |
| WhatsApp token extractable from bundle | 🔴 Critical | `whatsapp_otp_service.dart` | Yes |
| `promo_codes` fully public read+write | 🔴 Critical | `promo_codes_schema.sql` L16 | Yes |
| `wallet_recharges` fully public read+write | 🔴 Critical | `wallet_recharges_schema.sql` L30 | Yes |
| `warranty_claims` fully public read+write | 🟠 High | `warranty_claims_schema.sql` L19 | Yes |
| `order_messages` fully public read+write | 🟠 High | `order_messages_schema.sql` L22 | Yes |
| All technician PII in client response | 🟠 High | `technician.dart` L18-41, repo query | Yes — before SEO |
| Tech phone number on public portfolio | 🟠 High | `tech_portfolio_screen.dart` L115 | Yes — before SEO |
| Customer name on public portfolio (reviews) | 🟡 Medium | `tech_portfolio_screen.dart` L346 | Before SEO |
| Tech can access other tech's orders | 🟡 Medium | `app_router.dart` L161 | Before SEO |
| `services` table: any authenticated user can modify | 🟡 Medium | `services_setup.sql` L25 | Before SEO |
| `job_outcomes` fully public readable | 🟡 Medium | `job_outcomes_schema.sql` L45 | Before SEO |
| OG image domain mismatch | 🟡 Medium | `web/index.html` L20 | Before SEO |
| WhatsApp links use `7arafi.com` domain | 🟡 Medium | `whatsapp_utils.dart` L28, L33, L46 | Before launch |
| No `robots.txt` | 🟢 Low | Absent from `web/` | Before SEO |
| No `sitemap.xml` | 🟢 Low | Absent from `web/` | Before SEO |
| No GoRouter 404 route | 🟢 Low | `app_router.dart` | Soon |

---

## 9. Recommended Next Step

The smallest safe implementation phase after this audit is:

### Phase 0 — Security Baseline (Prerequisite to All Other Work)

> These items must be completed before any SEO work is done. If SEO traffic brings new visitors before these are fixed, the attack surface grows.

**The five items for Phase 0:**

1. **Move WhatsApp OTP token to Edge Function** — Create a `/functions/v1/send-whatsapp-otp` Edge Function. Read `ULTRAMSG_TOKEN` from Supabase secrets. This eliminates the highest-severity token exposure.

2. **Restrict Supabase SELECT on `technicians`** — Create `technicians_public` view with only the safe fields. Update the public query in `TechniciansRepository.watchAll()` to use this view for unauthenticated contexts, OR restrict the `technicians` table SELECT policy to authenticated only and serve public data through the view.

3. **Remove `tech.phone` from the public portfolio page** — Remove the "call technician directly" button from `tech_portfolio_screen.dart`. Phone number should only be revealed to customers with an active, assigned order.

4. **Restrict `promo_codes` and `wallet_recharges` to authenticated access only** — Update RLS to require `auth.role() = 'authenticated'` at minimum. Ideally, require admin role via JWT claim.

5. **Fix OG image URL and WhatsApp tracking link domain** — Update `web/index.html` and `whatsapp_utils.dart` to use the correct production domain consistently.

> **These five changes are independent, low-risk, and do not touch the customer/tech/admin flows in any way that could break them.**

After Phase 0 is complete:
- Phase 1: `robots.txt`, `sitemap.xml`, 404 route → immediate SEO baseline
- Phase 2: `slug` field migration, RLS hardening → enable tech profile SEO pages
- Phase 3: Next.js SEO layer → full SEO capabilities

---

*End of Security Audit. No code was modified.*
