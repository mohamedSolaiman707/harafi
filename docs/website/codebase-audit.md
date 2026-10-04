# Harafy Web — Codebase Audit & Technical Baseline

> **Audit Date:** 2026-09-22  
> **Auditor:** Antigravity  
> **Status:** Read-Only Inspection — No code was modified during this audit.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Folder Structure](#2-current-folder-structure)
3. [Architecture Audit](#3-architecture-audit)
4. [State Management](#4-state-management)
5. [Routing](#5-routing)
6. [Supabase / Backend Audit](#6-supabase--backend-audit)
7. [Current User Flows](#7-current-user-flows)
8. [Existing Public Pages](#8-existing-public-pages)
9. [SEO Audit](#9-seo-audit)
10. [Harafy SEO Requirements](#10-harafy-seo-requirements)
11. [Technician Public Profiles](#11-technician-public-profiles)
12. [Performance Audit](#12-performance-audit)
13. [Code Quality](#13-code-quality)
14. [Current vs Required](#14-current-vs-required)
15. [Recommended Changes](#15-recommended-changes)
16. [Implementation Risk](#16-implementation-risk)
17. [Final Architecture Proposal](#17-final-architecture-proposal)
18. [Final Audit Report](#18-final-audit-report)
19. [Decision Required](#decision-required)

---

## 1. Project Overview

### Framework and Version

| Property | Value |
|---|---|
| Framework | Flutter (multi-platform — Web is the primary concern) |
| Dart SDK | `>=3.10.1 <4.0.0` |
| Flutter Version | Not pinned explicitly (`pubspec.yaml` relies on SDK env) |
| Language | Dart |
| App Name | `حرفي \| صنايعي تثق فيه` (Harafi) |
| Version | `1.0.0+1` |

### Main Dependencies

| Package | Version | Purpose |
|---|---|---|
| `supabase_flutter` | ^2.8.3 | Backend — Auth, DB, Storage, Realtime |
| `flutter_riverpod` | ^2.6.1 | State management |
| `riverpod_annotation` | ^2.6.1 | Code generation for Riverpod |
| `go_router` | ^14.7.2 | Client-side SPA routing |
| `freezed_annotation` | ^2.4.4 | Immutable model generation |
| `json_annotation` | ^4.9.0 | JSON serialization |
| `intl` | ^0.20.2 | Internationalization / date formatting |
| `url_launcher` | ^6.3.1 | Phone calls and external URLs |
| `google_fonts` | ^6.2.1 | Typography |
| `flutter_web_plugins` | SDK | URL strategy (hash vs path) |
| `shared_preferences` | ^2.3.5 | Local storage / caching |
| `audioplayers` | ^6.1.0 | Audio (notification sounds) |
| `image_picker` | ^1.1.2 | Image upload |
| `fl_chart` | ^0.71.0 | Charts in admin dashboard |
| `http` | ^1.2.2 | HTTP calls (WhatsApp OTP API) |

### Build System

Standard Flutter build with `flutter_launcher_icons` and `build_runner` for code generation (`freezed`, `json_serializable`, `riverpod_generator`).

### State Management

**Riverpod** (flutter_riverpod ^2.6.1). Used as the primary state management solution throughout the application. The app wraps everything in a `ProviderScope` at `main.dart`.

### Routing Solution

**GoRouter** (^14.7.2). Configured as a single `appRouter` instance in `lib/core/router/app_router.dart`.

### Backend Technology

**Supabase** — a Firebase-like BaaS (Backend as a Service) using:
- **PostgreSQL** as the database
- **Supabase Auth** for admin and technician authentication
- **Supabase Storage** for images (portfolio, identity documents)
- **Supabase Realtime** via `stream()` — though the app primarily uses polling for order data

### Authentication Method

**Dual authentication system:**
- **Supabase Email/Password Auth** — Used for admins and technicians (standard JWT-based session)
- **WhatsApp OTP** — Used for customers (via UltraMsg third-party API, NOT Supabase Auth). Customers are NOT registered Supabase users; they authenticate via phone number + OTP stored in `SharedPreferences`.

### Database Integration

Direct Supabase client queries through the Repository pattern. Key tables identified:

- `orders` — Service requests
- `technicians` — Technician profiles
- `order_logs` — Order lifecycle audit trail
- `promo_codes` — Discount codes
- `order_messages` — In-order messaging (schema in `supabase/`)
- `wallet_recharges` — Technician wallet top-ups
- `warranty_claims` — Post-service warranty requests
- `job_outcomes` — AI/learning outcomes tracking

### Storage Integration

Supabase Storage via `StorageService` (`lib/core/services/storage_service.dart`). Used for:
- Technician profile photos
- Technician portfolio images
- Identity verification documents (national ID, criminal record)
- Order completion proof images

### Realtime Functionality

**Hybrid approach:**
- Supabase `.stream()` on `technicians` table → triggers a re-fetch via `asyncMap`
- Orders use **polling** via `Stream.periodic(Duration(seconds: 10))` — NOT true Realtime. This is a deliberate fallback documented in `AppConstants.pollingInterval`.

### Hosting / Deployment

- Hosted on **Vercel** (`vercel.json` present)
- All routes rewrite to `index.html` (SPA fallback)
- No server-side rendering; purely client-side Flutter Web

### Environment / Configuration

**CRITICAL FINDING:** Supabase credentials are **hardcoded** in `lib/core/constants/app_constants.dart`:

```dart
static const String supabaseUrl = 'https://afrvjkwcywbrbvzovkyi.supabase.co';
static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

The `lib/constants/app_constants.dart` file (a duplicate) uses `String.fromEnvironment` but the active file at `lib/core/constants/app_constants.dart` uses hardcoded values. The WhatsApp API token is also hardcoded in `whatsapp_otp_service.dart`.

### Communication Architecture

```
Web UI (Flutter Widgets)
        │
        ▼
Riverpod Providers (State + Business Logic)
        │
        ▼
Repository Layer (Abstract + Supabase Impl)
        │
        ▼
Supabase Flutter Client
        │
   ┌────┴─────┐
   │          │
Auth      Database (PostgreSQL)
              │
        ┌─────┴─────┐
     Storage      Realtime/Polling
```

---

## 2. Current Folder Structure

```
harafi/
├── lib/
│   ├── main.dart                    ← App entry point
│   ├── constants/                   ← DUPLICATE (stale, uses env vars)
│   │   └── app_constants.dart
│   ├── core/                        ← Cross-cutting concerns
│   │   ├── config/
│   │   │   └── supabase_config.dart
│   │   ├── constants/               ← ACTIVE constants file
│   │   │   └── app_constants.dart   ← Hardcoded credentials!
│   │   ├── either.dart              ← Custom Either monad
│   │   ├── failures.dart            ← Failure types
│   │   ├── providers/
│   │   │   └── location_provider.dart
│   │   ├── router/
│   │   │   └── app_router.dart      ← All routes defined here
│   │   ├── services/
│   │   │   ├── storage_service.dart
│   │   │   └── whatsapp_otp_service.dart  ← Hardcoded API token
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       ├── error_handler.dart
│   │       └── whatsapp_utils.dart
│   ├── features/
│   │   ├── admin/                   ← Admin panel (full Clean Architecture)
│   │   │   ├── data/
│   │   │   │   └── repositories/    ← orders_repository, techs_repository, etc.
│   │   │   ├── domain/
│   │   │   │   ├── business/        ← OrderLifecycle logic
│   │   │   │   ├── dtos/            ← Data Transfer Objects
│   │   │   │   ├── enums/           ← ServiceType, OrderStatus, TechStatus
│   │   │   │   └── models/          ← Technician (freezed), Order, etc.
│   │   │   └── presentation/
│   │   │       ├── providers/       ← All admin Riverpod providers
│   │   │       ├── screens/         ← Dashboard, Orders, Technicians, Promos
│   │   │       └── widgets/
│   │   ├── auth/                    ← Auth (presentation only, no domain/data)
│   │   │   └── presentation/
│   │   │       ├── providers/
│   │   │       └── screens/         ← LoginScreen, RoleSelectionScreen
│   │   ├── client/                  ← Customer-facing app (partial Clean Arch)
│   │   │   ├── data/
│   │   │   │   └── repositories/    ← smart_matching_repository only
│   │   │   ├── domain/
│   │   │   │   └── services/        ← technician_learning.dart only
│   │   │   └── presentation/
│   │   │       ├── providers/       ← Home, request, favorites, smart match
│   │   │       ├── screens/         ← 9 screens
│   │   │       └── widgets/         ← (empty folder)
│   │   ├── smart_assistant/         ← AI feature (data/domain/presentation)
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   └── tech/                    ← Technician-facing app (presentation only)
│   │       └── presentation/
│   │           ├── providers/
│   │           └── screens/         ← 6 screens
│   └── shared/
│       ├── providers/
│       └── widgets/                 ← 12 shared UI widgets
├── web/
│   ├── index.html                   ← Flutter Web entry, SEO meta tags
│   ├── manifest.json
│   └── icons/
├── supabase/
│   ├── functions/                   ← Edge Functions directory
│   └── *.sql                        ← Schema migrations
├── assets/
│   ├── images/
│   └── sounds/
├── vercel.json                      ← SPA rewrite config
├── pubspec.yaml
└── ROADMAP.md
```

### Directory Responsibilities

| Directory | Responsibility | Consistent? | Issues? |
|---|---|---|---|
| `lib/core/` | Shared infrastructure: router, theme, config, utils, providers | Yes | Two `app_constants.dart` files |
| `lib/features/admin/` | Admin dashboard — full Clean Architecture (data/domain/presentation) | Yes | Models shared with client feature (architectural coupling) |
| `lib/features/client/` | Customer-facing UI — partial Clean Architecture | Partial | Most business logic is in providers/screens, not domain layer |
| `lib/features/tech/` | Technician UI — presentation only, no data/domain layers | No | Missing data + domain layers; calls admin repositories directly |
| `lib/features/auth/` | Role selection + login — presentation only | Partial | No proper auth domain; auth handled ad-hoc via SharedPreferences |
| `lib/features/smart_assistant/` | AI feature | Unknown | Not fully inspected but has correct structure |
| `lib/shared/` | Reusable widgets and cross-feature providers | Yes | Clean |
| `web/` | Flutter Web entry point and PWA manifest | Yes | Good SEO meta tags but static only |
| `supabase/` | DB schema migrations and Edge Functions | Partial | Migrations are not version-numbered |

**Architectural Violations Identified:**
1. `lib/features/tech/` has NO data or domain layer — the tech screens call admin providers/repositories directly
2. `lib/features/auth/` has no domain layer — auth state is managed via `SharedPreferences` and global GoRouter redirect
3. `lib/constants/app_constants.dart` is a stale duplicate of `lib/core/constants/app_constants.dart`
4. Client feature's `presentation/` reaches into `admin/presentation/providers/` (cross-feature provider dependency)

---

## 3. Architecture Audit

### Actual Architecture

The project **partially follows Clean Architecture** on the admin feature, but is inconsistent across features.

```
Presentation Layer (Screens + Widgets)
          │
          ▼
Riverpod Providers (State + some Business Logic)
          │
          ▼
Repository (Abstract Interface + Supabase Implementation)
          │
          ▼
Supabase Flutter Client
          │
          ▼
     Supabase (PostgreSQL + Auth + Storage)
```

### Architecture Assessment Per Feature

| Feature | Data Layer | Domain Layer | Presentation Layer | Pattern |
|---|---|---|---|---|
| `admin` | ✅ Full repositories | ✅ Models, DTOs, enums, business | ✅ Providers + Screens | Clean Architecture |
| `client` | ⚠️ One repository only | ⚠️ One service only | ✅ Providers + Screens | Hybrid — mostly provider-heavy |
| `tech` | ❌ None | ❌ None | ✅ Providers + Screens | Presentation-only; borrows from admin |
| `auth` | ❌ None | ❌ None | ✅ Screens | Simple presentation |
| `smart_assistant` | ✅ Exists | ✅ Exists | ✅ Exists | Clean Architecture (unverified internals) |

### Summary

The project is **not consistently following one architecture**. The admin feature is the best-structured area with a clear Clean Architecture implementation. The client and tech features are presentation-heavy and lean directly on admin repositories. This is acceptable for an MVP but creates coupling issues as the product scales.

---

## 4. State Management

### Riverpod Usage

| Type | Examples | Count |
|---|---|---|
| `Provider` | `techsRepositoryProvider`, `ordersRepositoryProvider`, derived providers | Many |
| `StreamProvider` | `ordersStreamProvider`, `techniciansProvider`, `techOrdersStreamProvider` | Key |
| `FutureProvider` | `clientOrdersProvider`, `ordersProvider` | Some |
| `FutureProvider.family` | `clientOrdersProvider(phone)` | Some |
| `StreamProvider.family` | `techOrdersStreamProvider(techId)` | Some |
| `StateNotifierProvider` | `currentTechnicianProvider`, `CurrentTechNotifier` | Yes |
| `StateProvider` | `homeSearchQueryProvider`, `requestSelectedServiceProvider`, `requestLoadingProvider` | Many |

### Authentication State

Authentication state is **not managed via Riverpod**. Instead:
- **Role** is persisted to `SharedPreferences` as a string (`'client'`, `'tech'`, `'admin'`)
- **Session** is checked via `Supabase.instance.client.auth.currentUser != null` directly in GoRouter redirect
- No dedicated auth provider exists — auth state is checked inline, ad-hoc

### Loading / Error / Success Handling

Inconsistent:
- `StreamProvider`/`FutureProvider` expose `.isLoading` and `.error` via `AsyncValue` — this is the correct pattern
- Many screens call `.valueOrNull ?? []` and silently ignore errors
- Loading states for actions (e.g., `requestLoadingProvider`) are plain `StateProvider<bool>`
- Error handling in repositories returns `Either<Failure, T>` — not always mapped in UI

### Global vs Local State

| State | Scope | Where |
|---|---|---|
| All orders | Global | `ordersStreamProvider` |
| All technicians | Global | `techniciansProvider` |
| Current technician | Global | `currentTechnicianProvider` |
| User location | Global | `userLocationProvider` |
| Home search query | Screen-local (but global provider) | `homeSearchQueryProvider` |
| Request form state | Screen-local | `requestSelectedServiceProvider`, `requestLoadingProvider` |

### Findings

- **Duplicated data fetching**: `ordersProvider` (FutureProvider, fetches once) and `ordersStreamProvider` (polling stream) both exist and both fetch all orders. This causes double requests.
- **Polling instead of Realtime**: Orders use `Stream.periodic(10s)` to poll — not true Realtime. Supabase Realtime is available but not used for orders.
- **Business logic in providers**: The `topRatedTechsProvider` contains location scoring, rank scoring, and sorting — this is business logic that belongs in a domain service.
- **Business logic in UI**: `HomeScreen._smartNormalize()` and search filtering are implemented inside the widget file. Should be in domain services.
- **Auth state mismatch**: Technicians use Supabase Auth, customers use WhatsApp OTP + SharedPreferences. No unified auth abstraction.

---

## 5. Routing

### Router Implementation

GoRouter v14 configured in `lib/core/router/app_router.dart`. Uses:
- `redirect` callback for auth guards (async, reads SharedPreferences on every navigation)
- `ShellRoute` for the admin panel
- `pageBuilder` with custom `AppAnimations.fadeSlide` transitions throughout

### URL Strategy

**CRITICAL SEO FINDING:**

`usePathUrlStrategy()` is **commented out** in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تفعيل الروابط بدون علامة #
 // usePathUrlStrategy();  ← COMMENTED OUT

  await SupabaseConfig.initialize();
  runApp(const ProviderScope(child: MyApp()));
}
```

This means the application currently uses **hash-based URLs** (`/#/route`). All navigation happens after the `#` fragment, which search engine crawlers **cannot index**.

**Current URL format:** `https://harafi-eg.vercel.app/#/service/plumbing`  
**Required URL format:** `https://harafi-eg.vercel.app/service/plumbing`

### All Routes (as defined in `app_router.dart`)

| Route | Component | Auth Required | Auth Guard |
|---|---|---|---|
| `/welcome` | `RoleSelectionScreen` | No | Redirects away if role set |
| `/` | `HomeScreen` | No (but role=client needed) | None |
| `/smart-assistant` | `SmartAssistantScreen` | No | None |
| `/about` | `AboutScreen` | No | None |
| `/services` | `ServicesScreen` | No | None |
| `/all-techs` | `ServiceTechsScreen(service: null)` | No | None |
| `/service/:type` | `ServiceTechsScreen(service)` | No | None |
| `/request` | `RequestScreen` | No | None |
| `/track/:code` | `TrackScreen` | No | None |
| `/my-orders` | `ClientOrdersScreen` | No | None |
| `/favorites` | `FavoritesScreen` | No | None |
| `/tech/portfolio/:id` | `TechPortfolioScreen` | No | None |
| `/login` | `LoginScreen` (admin) | No | Redirects if logged in |
| `/tech/login` | `TechLoginScreen` | No | Redirects if logged in |
| `/tech/register` | `TechRegisterScreen` | No | None |
| `/tech/dashboard` | `TechDashboardScreen` | Yes (Supabase) | Redirects to `/tech/login` |
| `/tech/order/:id` | `TechOrderDetailScreen` | Yes (Supabase) | Inherited |
| `/tech/profile` | `TechProfileScreen` | Yes (Supabase) | Inherited |
| `/tech/wallet` | `TechWalletScreen` | Yes (Supabase) | Inherited |
| `/admin` | `DashboardScreen` (ShellRoute) | Yes (Supabase) | Redirects to `/login` |
| `/admin/orders` | `OrdersScreen` | Yes | ShellRoute |
| `/admin/order/:id` | `AdminOrderDetailScreen` | Yes | ShellRoute |
| `/admin/techs` | `TechniciansScreen` | Yes | ShellRoute |
| `/admin/promos` | `PromoCodesScreen` | Yes | ShellRoute |

### Dynamic Routes

- `/service/:type` — type is a `ServiceType.name` (enum name, e.g. `plumbing`, `ac`)
- `/track/:code` — tracking code (auto-generated)
- `/tech/portfolio/:id` — technician UUID
- `/tech/order/:id` — order UUID
- `/admin/order/:id` — order UUID

### 404 Handling

A `NotFoundScreen` widget exists at `lib/shared/widgets/not_found_screen.dart` but **is NOT registered in the router**. GoRouter's `onException` or `errorBuilder` is not configured. Unknown routes may produce unexpected behavior.

### Deep Linking

Vercel is configured to rewrite all routes to `index.html`. This enables direct URL access when using path URL strategy. However, since hash routing is currently active, deep links like `/tech/portfolio/uuid` would navigate correctly but return `https://harafi-eg.vercel.app/#/tech/portfolio/uuid` which is not SEO-crawlable.

### SEO Impact

Hash-based routing is the single largest SEO blocker in the current implementation. All routes are effectively invisible to search engines.

---

## 6. Supabase / Backend Audit

### Authentication

| Flow | Method | Status |
|---|---|---|
| Admin login | Supabase Email/Password | ✅ Implemented |
| Technician login | Supabase Email/Password | ✅ Implemented |
| Technician registration | Supabase `signUp` | ✅ Implemented |
| Customer authentication | WhatsApp OTP (UltraMsg API) + SharedPreferences | ✅ Implemented |
| Password reset | Not found in code | ❌ Not implemented |
| Session handling | `Supabase.instance.client.auth.currentUser` | Partial — no token refresh monitoring |
| User roles | Stored in `SharedPreferences` (`user_role` key) | ⚠️ Client-side only, no server-side enforcement |

### Database Tables

| Table | Purpose | Source |
|---|---|---|
| `orders` | All service requests | Used extensively |
| `technicians` | Technician profiles | Used extensively |
| `order_logs` | Lifecycle audit trail per order | Used |
| `order_messages` | In-order messages | Schema exists, limited usage found |
| `promo_codes` | Discount codes | Used |
| `wallet_recharges` | Technician wallet recharges | Schema + provider exists |
| `warranty_claims` | Warranty claim requests | Schema + provider exists |
| `job_outcomes` | AI learning outcomes | Schema exists; usage unclear |
| `scheduled_orders` | Scheduled order support | Schema exists; app supports scheduling |
| `technicians_verification` | Verification workflow | Schema exists |

### Identified Table Columns (from model inspection)

**`orders` table:**
```
id, tracking_code, client_name, client_phone, service, area, description,
tech_id, status, final_price, admin_notes, tech_notes, rating, rating_comment,
estimated_arrival, completed_at, order_logs (relation), completion_images,
inspection_fee, labor_fee, parts_fee, promo_code, discount_amount,
is_scheduled, scheduled_date, preferred_time_slot, created_at, updated_at
```

**`technicians` table:**
```
id, name, phone, spec, price_range, visit_price, area, status, rating,
total_jobs, photo_url, identity_proof_url, national_id_front_url,
national_id_back_url, criminal_record_url, bio, total_earnings, wallet_balance,
portfolio_images, is_verified, admin_note, created_at
```

### Queries

- **Direct Supabase queries** in repositories (clean, no raw SQL)
- **RPC functions**: Not observed in current code — all queries use `.from().select()` style
- **Pagination**: **Not implemented** — `getAll()` fetches entire tables on every poll
- **Filtering**: Done client-side (filter on `tech_id`, `status`, `spec` in repositories)
- **Search**: Done entirely client-side in Flutter code (home search, admin lists)

### Realtime

The `watchAll()` methods use `_client.from('table').stream(primaryKey: ['id']).asyncMap((_) => getAll())`. This triggers a re-fetch of ALL records when ANY row changes — highly inefficient at scale.

### Security

> **⚠️ FINDINGS — Read only, not fixing yet:**

1. **Hardcoded `anonKey` in source code** (`lib/core/constants/app_constants.dart`): The Supabase anon key is committed to the repository. This is expected for `anonKey` (it is public by design in Supabase) but is a risk if RLS is misconfigured.

2. **Hardcoded WhatsApp API token**: `WhatsAppOtpService.token = '2f92w8s3fow0ofku'` is committed in source. This token can send WhatsApp messages at the account's expense if discovered.

3. **No service-role key found** in client code — Good. Service role keys should never be in client code.

4. **Frontend-only role enforcement**: The `user_role` value in `SharedPreferences` is set entirely client-side (by the `RoleSelectionScreen`). There is no server-side verification that a user has admin rights. The admin panel redirect checks `Supabase.instance.client.auth.currentUser != null`, but this only verifies Supabase auth — not that the user is actually an admin. Any logged-in user with a Supabase session could navigate to `/admin`.

5. **Customer identity**: Customers are identified only by phone number stored in SharedPreferences. There is no server-side customer record. A customer can change their phone number in the form to view another person's orders if they know the tracking code.

6. **`client_phone` in orders is public data**: The `tech/portfolio/:id` screen calls `ref.watch(techOrdersStreamProvider(techId))` which fetches orders from the public path — these orders contain `clientName` and `clientPhone`. Whether RLS restricts this requires Supabase dashboard verification.

---

## 7. Current User Flows

### Customer Flow

```
1. ENTRY
   /welcome → Role selection (client / tech / hidden admin)
   → Sets 'user_role' in SharedPreferences
   → Redirects to /

2. HOME (/)
   → Search services by keyword OR name
   → See top-rated technicians near location
   → Smart Assistant card → /smart-assistant
   → Service category cards → /service/:type

3. BROWSE (/service/:type or /all-techs)
   → Filter technicians by service type and status
   → View tech mini-cards
   → Tech card → /tech/portfolio/:id

4. TECH PROFILE (/tech/portfolio/:id)
   → View name, specialty, area, rating, jobs, visit price
   → View bio, trust badges, portfolio images
   → View client reviews (from completed orders)
   → "Book this technician" → /request (with tech ID pre-selected)
   → "Direct call" → tel: link (EXPOSES PHONE NUMBER)

5. REQUEST (/request)
   → Select service type
   → Optional: choose specific technician
   → Select immediate or scheduled
   → Fill: name, phone, area, description
   → Optional: apply promo code
   → Submit → WhatsApp OTP verification (if new number)
   → Order created → WhatsApp confirmation sent
   → Success dialog shows tracking code
   → → /track/:code

6. TRACKING (/track/:code)
   → Real-time status via polling
   → See order lifecycle logs
   → Rate technician on completion
   → Warranty claim if needed

7. MY ORDERS (/my-orders)
   → Fetch orders by phone number from SharedPreferences
   → View all past orders

8. FAVORITES (/favorites)
   → Favorite technicians (locally stored)
```

**Incomplete / Broken Flows:**
- No dedicated customer account — no login/registration for customers
- Favorites are likely stored locally (SharedPreferences), not in Supabase — not verified across devices
- The `/smart-assistant` flow is present but its output/integration with `/request` is unclear from code inspection alone

### Technician Flow

```
1. REGISTRATION (/tech/register)
   → Fill: name, phone, speciality, area, visit price, bio
   → Upload: photo, ID front, ID back, criminal record
   → Supabase signUp (email = phone + domain, password = phone)
   → Status = 'pending' → awaiting admin approval

2. LOGIN (/tech/login)
   → Email/password login (Supabase Auth)
   → Redirects to /tech/dashboard

3. DASHBOARD (/tech/dashboard)
   → See pending/active/completed orders
   → Accept or reject incoming orders
   → Update order status (arrived, started, quoted, completed)
   → View wallet balance

4. ORDER DETAIL (/tech/order/:id)
   → Full order lifecycle management
   → Upload completion images
   → Add tech notes
   → Set final price breakdown (inspection, labor, parts)

5. PROFILE (/tech/profile)
   → Update bio, area, visit price
   → Upload portfolio images
   → View rank, stats, badges

6. WALLET (/tech/wallet)
   → View balance
   → View recharge history
   → (Presumably recharge mechanism exists)
```

**Incomplete / Missing:**
- No password reset flow for technicians
- No acceptance timer (mentioned in ROADMAP as upcoming)
- Reliability Score not yet implemented (ROADMAP Phase 2)
- No technician discovery by city/slug URL (no `/technicians/tanta` page)

### Admin Flow

```
1. LOGIN (/login)
   → Hidden 5-tap trigger on /welcome logo
   → Standard Supabase email/password

2. DASHBOARD (/admin)
   → Stats: total orders, pending, active, completed, revenue
   → Technician stats

3. ORDERS (/admin/orders)
   → Full order list with filters
   → /admin/order/:id → assign tech, update status, add notes

4. TECHNICIANS (/admin/techs)
   → Full technician management
   → Approve/reject, change status, update wallet

5. PROMO CODES (/admin/promos)
   → Create, manage promo codes
```

---

## 8. Existing Public Pages

> "Public" = accessible without Supabase auth. Note: with current hash routing, none are truly SEO-crawlable.

| URL | Purpose | Crawlable | Meaningful Content | Unique Title | Meta Description | H1 | Canonical | Structured Data | Dynamically Generated |
|---|---|---|---|---|---|---|---|---|---|
| `/#/welcome` | Role selection | ❌ (hash) | ❌ (UI-only) | ❌ | ❌ | ❌ | ❌ | ❌ | No |
| `/#/` | Home — services & techs | ❌ (hash) | ⚠️ (JS-rendered) | ❌ | ❌ | ❌ | ❌ | ❌ | Yes (JS) |
| `/#/services` | All services list | ❌ (hash) | ⚠️ (JS-rendered) | ❌ | ❌ | ❌ | ❌ | ❌ | Yes (JS) |
| `/#/service/:type` | Techs per service | ❌ (hash) | ⚠️ (JS-rendered) | ❌ | ❌ | ❌ | ❌ | ❌ | Yes (JS) |
| `/#/tech/portfolio/:id` | Technician profile | ❌ (hash) | ⚠️ (JS-rendered) | ❌ | ❌ | ❌ | ❌ | ❌ | Yes (JS) |
| `/#/request` | Book a service | ❌ (hash) | ❌ (form only) | ❌ | ❌ | ❌ | ❌ | ❌ | No |
| `/#/track/:code` | Order tracking | ❌ (hash) | ❌ (private data) | ❌ | ❌ | ❌ | ❌ | ❌ | Yes (JS) |
| `/#/about` | About page | ❌ (hash) | ⚠️ (JS-rendered) | ❌ | ❌ | ❌ | ❌ | ❌ | No |
| `/#/all-techs` | All technicians | ❌ (hash) | ⚠️ (JS-rendered) | ❌ | ❌ | ❌ | ❌ | ❌ | Yes (JS) |
| `/#/smart-assistant` | AI chat | ❌ (hash) | ❌ (interactive) | ❌ | ❌ | ❌ | ❌ | ❌ | No |

**Notes:**
- `index.html` has a single global title and meta description — applies to ALL pages
- Per-page meta is not set dynamically (Flutter Web cannot change `<title>` or `<meta>` tags without specific packages)
- The JSON-LD structured data in `index.html` is a `LocalBusiness` schema — static, applies to homepage only
- No `robots.txt` found in `web/` directory
- No `sitemap.xml` found

---

## 9. SEO Audit

### Technical SEO

| Check | Status | Notes |
|---|---|---|
| `robots.txt` | ❌ Not found | Not in `web/` directory |
| `sitemap.xml` | ❌ Not found | Does not exist |
| Canonical URLs | ❌ Missing | No `<link rel="canonical">` |
| Meta Title | ⚠️ Static only | Single title for all pages in `index.html` |
| Meta Description | ⚠️ Static only | Single description for all pages |
| Open Graph | ✅ Present | In `index.html` — static, homepage only |
| Twitter Card | ✅ Present | In `index.html` — static, homepage only |
| Semantic HTML | ❌ Not applicable | Flutter Web renders to `<canvas>` or `<flt-*>` tags — no semantic HTML |
| H1/H2 structure | ❌ Not in HTML | All headings are Flutter `Text` widgets inside canvas |
| 404 page | ⚠️ Widget exists | `NotFoundScreen` widget exists but not wired to GoRouter |
| Redirects | ✅ Vercel rewrites | All paths → `index.html` |
| index/noindex | ❌ Not configured | No `<meta name="robots">` tag |
| Duplicate URLs | ⚠️ Potential | `/#/` vs `/` both resolve to same content |
| URL Structure | ❌ Hash-based | `/#/service/plumbing` instead of `/service/plumbing` |
| Page Performance | ⚠️ Unknown | Flutter Web WASM/canvaskit bundle is typically large |
| Image optimization | ❌ Unknown | Images fetched from Supabase Storage URLs; no optimization pipeline |
| Mobile responsiveness | ✅ Implemented | App uses `MediaQuery` and `ConstrainedBox` for responsive layout |
| OG image URL | ⚠️ Wrong domain | Points to `https://7arafi.com/og-image.png` — domain appears different from live domain |

### Crawlability Assessment

**Flutter Web SPA with hash routing is not crawlable by search engines.**

Google's crawler can execute JavaScript and follow `pushState` URLs, but:
1. Hash fragments (`#/route`) are **not sent to the server** — they are client-side only
2. Even with `usePathUrlStrategy()`, Flutter Web renders to a canvas — there is **no semantic HTML** for crawlers to read
3. The full tech list, service categories, and technician profiles are loaded dynamically via Supabase API calls — the HTML returned to crawlers is effectively empty

**Required Solution for SEO:**
The application requires one of:
- **Pre-rendering / Static Site Generation (SSG)** — Generate static HTML for key public pages at build time
- **Server-Side Rendering (SSR)** — A server renders HTML before sending to the browser
- **Separate SEO landing pages** — A parallel set of HTML/Next.js pages for public SEO content, with the Flutter SPA handling the app experience

Given the Flutter Web constraint, the recommended approach is **Option 3: Separate static SEO pages** (e.g., Next.js or even plain HTML) that link into the Flutter app for interaction. This preserves the existing Flutter app while adding real crawlable content.

---

## 10. Harafy SEO Requirements

| Target URL | Exists? | Possible with Current Arch? | Requires Routing Changes? | Requires Backend Changes? | Requires SSR/SSG? | Notes |
|---|---|---|---|---|---|---|
| `/` | ✅ (as `/#/`) | ⚠️ Partial | Yes (remove hash) | No | Yes (pre-render homepage) | |
| `/services/plumbing` | ❌ | No | Yes (new route + slug mapping) | No | Yes | ServiceType uses enum names, not slugs |
| `/services/electricity` | ❌ | No | Yes | No | Yes | |
| `/services/washing-machine` | ❌ | No | Yes | No | Yes | |
| `/technicians/tanta` | ❌ | No | Yes (new route) | Yes (filter by area) | Yes | Requires area index in DB |
| `/technicians/kafr-el-zayat` | ❌ | No | Yes | Yes | Yes | |
| `/technicians/tanta/plumbing` | ❌ | No | Yes | Yes | Yes | |
| `/technicians/kafr-el-zayat/plumbing` | ❌ | No | Yes | Yes | Yes | |
| `/technician/{slug}` | ❌ | Partial (`/tech/portfolio/:id`) | Yes (slug vs UUID) | Yes (add slug field) | Yes | Currently uses UUID, not human-readable slug |

**Key Gap:** The technician profile page (`/tech/portfolio/:id`) uses a UUID identifier. For SEO purposes, a human-readable slug (e.g., `/technician/ahmed-ali-sbaak-tanta`) is required. This needs a `slug` field in the `technicians` table.

---

## 11. Technician Public Profiles

### Available Fields in `Technician` Model

| Field | Available? | Public Safe? | SEO Value? |
|---|---|---|---|
| `name` | ✅ | ✅ | ✅ High |
| `photo_url` | ✅ | ✅ | ✅ High |
| `spec` (specialty) | ✅ | ✅ | ✅ High |
| `area` (service area) | ✅ | ✅ | ✅ High |
| `rating` | ✅ (calculated) | ✅ | ✅ High |
| `total_jobs` | ✅ | ✅ | ✅ Medium |
| `bio` | ✅ | ✅ | ✅ High |
| `portfolio_images` | ✅ | ✅ | ✅ Medium |
| `is_verified` | ✅ | ✅ | ✅ Medium |
| `visit_price` | ✅ | ✅ | ✅ Medium |
| `price_range` | ✅ | ✅ | ✅ Medium |
| `status` | ✅ | ⚠️ (availability info) | Low |
| `created_at` | ✅ | ✅ | Low |

**Private fields (should NOT be exposed publicly):**
| Field | Risk |
|---|---|
| `phone` | CRITICAL — currently exposed via `/tech/portfolio` "Direct call" button |
| `identity_proof_url` | Documents — must stay private |
| `national_id_front_url` | Documents — must stay private |
| `national_id_back_url` | Documents — must stay private |
| `criminal_record_url` | Documents — must stay private |
| `wallet_balance` | Financial — must stay private |
| `total_earnings` | Financial — must stay private |
| `admin_note` | Internal — must stay private |

**Missing for SEO:**
- `slug` field — human-readable URL identifier (e.g., `ahmed-ali-plumbing-tanta`)
- Specific `service_areas` array — a technician may serve multiple cities
- `years_experience` — not present in model
- `availability_schedule` — not present, only `status` (available/busy/leave)

---

## 12. Performance Audit

### Bundle Size

Flutter Web generates a large initial bundle (typically 2–5MB for `canvaskit` renderer). No custom optimization has been applied.

### Data Fetching Issues

| Issue | Severity | Description |
|---|---|---|
| Fetches ALL orders on every poll | ⚠️ High | `ordersStreamProvider` calls `getAll()` every 10 seconds — fetches all records regardless of page/role |
| Fetches ALL technicians on every change | ⚠️ Medium | `techniciansProvider` via `watchAll()` re-fetches full table on any row change |
| Double fetch: `ordersProvider` + `ordersStreamProvider` | ⚠️ Medium | Both providers exist and both call `getAll()`. Both are watched in different screens |
| No pagination | ⚠️ High | All queries are unbounded. Will degrade with >1000 orders |
| No server-side filtering | ⚠️ Medium | Filtering by service type, area, status happens in Dart, not in Supabase queries |
| Client-side search | ℹ️ Low | Search in home screen tokenizes and matches in Dart — fine for small datasets |

### Caching

SharedPreferences-based caching is implemented for:
- All technicians list (`cached_techs_list`)
- All orders list (`cached_orders_list`)
- Per-tech orders (`tech_orders_$techId`)
- Current technician profile (`cached_tech_profile`)

This is a reasonable offline-first approach but the cache invalidation is only triggered by new data from polling — stale data could persist across sessions.

### Image Loading

- No lazy loading configuration
- No image compression pipeline
- Supabase Storage URLs used directly (no CDN optimization configured)
- Portfolio images in the tech portfolio screen have no size constraints or placeholders

### Unnecessary Rebuilds

- `HomeScreen` re-watches `ordersStreamProvider` (all orders) just to find the active order for the floating status bar — this is excessive
- `techniciansProvider` derived from `_rawTechsProvider` AND `ordersProvider` — adding orders dependency causes tech list to re-compute every 10 seconds

---

## 13. Code Quality

### Critical Issues

| Issue | Location | Description |
|---|---|---|
| Hardcoded Supabase credentials | `lib/core/constants/app_constants.dart` | Committed to version control; security risk |
| Hardcoded WhatsApp API token | `lib/core/services/whatsapp_otp_service.dart` | API token in source; financial/abuse risk |
| `usePathUrlStrategy()` commented out | `lib/main.dart` | Blocks ALL SEO — hash URLs make the site invisible to crawlers |
| No `robots.txt` | `web/` | Search engines have no indexing directive |
| No `sitemap.xml` | Project root | No sitemap for crawlers |
| Phone number exposed publicly | `tech_portfolio_screen.dart` L115 | `launchUrl(Uri.parse('tel:${tech.phone}'))` — tech phone is shown to any visitor |
| Frontend-only admin auth | `app_router.dart` redirect | Only checks Supabase session, not admin role server-side |
| `NotFoundScreen` not wired | `app_router.dart` | 404 screen exists but not registered |

### Important Issues

| Issue | Location | Description |
|---|---|---|
| Two `app_constants.dart` files | `lib/constants/` vs `lib/core/constants/` | The stale file at `lib/constants/` uses `String.fromEnvironment` but is not used |
| No pagination | Repository layer | All queries fetch full tables |
| Business logic in `HomeScreen` | `home_screen.dart` | `_smartNormalize`, stop words, search filtering in widget |
| Polling instead of Realtime | `orders_provider.dart` | 10-second polling creates unnecessary load |
| Tech feature missing data/domain | `lib/features/tech/` | Directly depends on admin repositories; no separation |
| `watchAll()` re-fetches all | `orders_repository.dart`, `techs_repository.dart` | `stream().asyncMap((_) => getAll())` — fetches everything on any change |
| `print()` in production code | `techs_repository.dart` L51 | `print('Error in getAll technicians...')` — should use `debugPrint` or logging |
| `client_phone` potentially exposed | `order_messages` queries | Order data includes phone; RLS state unknown |

### Nice to Have

| Issue | Location | Description |
|---|---|---|
| `statsProvider` and `dashboardStatsProvider` | `orders_provider.dart` | Redundant: `statsProvider` wraps `dashboardStatsProvider` with a map |
| `techsStreamProvider = techniciansProvider` | `techs_provider.dart` | Alias that serves no purpose |
| Missing error builder in GoRouter | `app_router.dart` | No `errorBuilder` registered |
| Inconsistent naming | Various | Mix of Arabic and English comments throughout |
| `_getAsset` duplicated | `home_screen.dart`, `request_screen.dart` | Same switch for service → asset name repeated in two places |
| `OG image` wrong domain | `web/index.html` | Points to `7arafi.com` but deployed on `harafi-eg.vercel.app` |

---

## 14. Current vs Required

| Area | Current State | Required State | Gap | Priority |
|---|---|---|---|---|
| **URL Strategy** | Hash routing (`/#/route`) — disabled `usePathUrlStrategy()` | Clean path URLs (`/route`) | One line uncommented, Vercel rewrites already in place | 🔴 Critical |
| **SEO: per-page meta** | Single static meta in `index.html` | Dynamic per-page title, description, canonical | No mechanism to set meta dynamically in Flutter Web | 🔴 Critical |
| **SEO: crawlability** | No indexable content (canvas render) | Crawlable HTML for public pages | Requires SSG/pre-rendering or parallel HTML pages | 🔴 Critical |
| **robots.txt** | Missing | Present with correct directives | Simple file to add | 🔴 Critical |
| **sitemap.xml** | Missing | Dynamic sitemap with all public URLs | Need backend-generated or build-time sitemap | 🔴 High |
| **404 handling** | Widget exists, not wired | Proper 404 page in GoRouter | Wire `NotFoundScreen` to GoRouter `errorBuilder` | 🟠 High |
| **Technician slug** | UUID (`/tech/portfolio/{uuid}`) | Human-readable slug (`/technician/{slug}`) | Requires DB migration + routing change | 🟠 High |
| **Service pages** | `/service/plumbing` (English enum name) | `/services/plumbing` with crawlable HTML | Routing + SSG | 🟠 High |
| **Location pages** | None | `/technicians/tanta`, `/technicians/tanta/plumbing` | New routes + DB query by area | 🟠 High |
| **Pagination** | None | Server-side pagination | Repository layer refactor | 🟡 Medium |
| **Realtime** | Polling every 10s | True Supabase Realtime | Provider refactor | 🟡 Medium |
| **Auth abstraction** | Ad-hoc SharedPreferences + Supabase | Unified auth provider | Architecture | 🟡 Medium |
| **Credentials** | Hardcoded in source | Environment variables | Build config change | 🟡 Medium |
| **Phone exposure** | Tech phone on public profile | Phone hidden; click-to-call via redirect | Small UI change | 🟡 Medium |
| **Admin role guard** | Frontend-only | Server-side role enforcement | Supabase RLS + role claim | 🟡 Medium |
| **Pagination UI** | None | Paginated tech/order lists | Both UI and repo changes | 🟡 Medium |
| **Structured data** | Static homepage LocalBusiness schema | Per-page schema (Service, Person, Review) | Dynamic injection | 🟡 Medium |
| **Performance** | Full-table polls | Paginated queries + Realtime | Refactor | 🟡 Medium |

---

## 15. Recommended Changes

### Must Change (Before Continuing)

1. **Enable `usePathUrlStrategy()`** in `main.dart` — This is a single line uncomment. Without it, all routing and SEO work is meaningless.

2. **Add `robots.txt`** to `web/` directory — Even a simple allow-all file is required. Currently missing.

3. **Wire `NotFoundScreen` to GoRouter** — Add `errorBuilder` to the router.

4. **Remove phone number from public tech profile** — `launchUrl(Uri.parse('tel:${tech.phone}'))` exposes tech phone to the public.

5. **Delete stale `lib/constants/app_constants.dart`** — It's unused and confusing. Only `lib/core/constants/app_constants.dart` should exist.

6. **Move credentials to environment / build args** — Supabase URL and anon key should use `--dart-define` at build time. The WhatsApp token should be in an Edge Function, not client code.

### Should Change (Improves SEO, Maintainability, Scalability)

7. **Implement SSG/pre-rendering for public pages** — Add a Next.js layer (or Vercel Edge Functions) that serves static HTML for:
   - `/` (homepage)
   - `/services/[slug]`
   - `/technicians/[city]`
   - `/technicians/[city]/[service]`
   - `/technician/[slug]`

8. **Add `slug` field to `technicians` table** — Required for SEO-friendly URLs.

9. **Add dynamic meta tag support** — Use `flutter_meta_seo` or integrate with the SSG layer to set per-page `<title>` and `<meta>` tags.

10. **Add `sitemap.xml` generation** — Generate dynamically via Supabase Edge Function or at build time.

11. **Implement server-side admin role enforcement** — Add `role` claim to Supabase JWT and enforce via RLS policies.

12. **Fix `watchAll()` inefficiency** — Use `stream().select(specificColumns).eq(filter)` in Supabase or proper Realtime subscriptions instead of re-fetching all rows.

13. **Add pagination** — Implement `.range(from, to)` in repository queries.

14. **Create unified auth provider** — Wrap both Supabase auth and WhatsApp OTP state in a single Riverpod provider.

### Could Change Later (Not Blocking Current Roadmap)

15. **Move tech feature to its own data/domain layers** — Currently borrowing admin's repositories.

16. **Replace `Stream.periodic` polling with true Supabase Realtime** — Reduces server load; better UX.

17. **Implement structured data (JSON-LD) dynamically** — Service schema, Person schema, Review schema per page.

18. **Add image optimization pipeline** — Compress/resize images via Supabase Storage transformations.

19. **Move search normalization to domain layer** — `_smartNormalize` and stop-word filtering belongs in a service, not a screen.

20. **Implement acceptance timer for technicians** — Mentioned in ROADMAP.

---

## 16. Implementation Risk

| Change | Files Affected | Modules | Backend Impact | DB Impact | Routing Impact | SEO Impact | Risk | Migration Required? |
|---|---|---|---|---|---|---|---|---|
| Enable path URL strategy | `main.dart` | Core | None | None | High — all `/#/` links become `/` | High positive | Low | No (Vercel already set up) |
| Add `robots.txt` | `web/robots.txt` (new) | Web | None | None | None | High positive | Low | No |
| Wire 404 to GoRouter | `app_router.dart` | Core/Router | None | None | Minor | Low | Low | No |
| Remove phone from portfolio | `tech_portfolio_screen.dart` | Client/Tech | None | None | None | Low | Low | No |
| Delete stale constants | `lib/constants/app_constants.dart` | Core | None | None | None | None | Low | No |
| Move credentials to env | `main.dart`, `app_constants.dart`, `whatsapp_otp_service.dart`, Vercel config | Core | WhatsApp API move to Edge Function | None | None | None | Medium | Requires Vercel env setup |
| Add SSG/pre-rendering layer | New Next.js project or Vercel Edge Function | Separate system | None | Read-only queries | None | Very high positive | Medium | No |
| Add `slug` to technicians | `technicians` table, `Technician` model, `techs_repository.dart`, `app_router.dart`, `tech_portfolio_screen.dart` | Admin/Client/Core | DB migration | Yes — add column | New route `/technician/:slug` | High positive | Medium | Yes |
| Add dynamic sitemap | New Edge Function or build script | Supabase/Vercel | Read-only | None | None | High positive | Low | No |
| Server-side admin role | Supabase Auth settings, RLS policies, `app_router.dart` | Auth/Admin | Yes | RLS changes | Auth redirect logic | None | High | Yes |
| Fix `watchAll()` | `orders_repository.dart`, `techs_repository.dart` | Admin/Data | Query changes | None | None | None | Medium | No |
| Add pagination | Repository layer, all list providers, all list screens | Admin/Client/Tech | Query changes | None | None | Low | High | No |

---

## 17. Final Architecture Proposal

After reviewing the existing codebase, the following target architecture is proposed. It adds a **public SEO layer** around the existing Flutter app without disrupting it.

```
                    HARAFY
                       │
          ┌────────────┴─────────────┐
          │                          │
      Mobile App               Web Platform
      (Flutter)                      │
                         ┌───────────┴──────────┐
                         │                      │
              Public SEO Pages (SSG)    Full Flutter Web App
              (Next.js / Vercel Edge)   (existing, unchanged)
                         │                      │
                         │              ┌───────┴───────┐
                         │              │               │
                    Static HTML    Flutter SPA      Auth Gate
                    crawlable      (Customer)       (Admin/Tech)
                         │
                         └─────────────┬──────────────────┘
                                       │
                                    Supabase
                                       │
                          ┌────────────┼────────────┐
                          │            │            │
                        Auth       Database      Storage
                    (Email/OTP)  (PostgreSQL)   (Images)
                          │            │
                    ┌─────┘    ┌───────┘
                    │          │
                Admin     Edge Functions
               (JWT Auth)  (AI/WhatsApp OTP)
```

**Key Principles:**
- The Flutter app continues to be the product — no replacement
- SEO pages are **read-only HTML** generated from Supabase data at build time or on-demand
- SEO pages link into the Flutter app for all interactive flows (booking, tracking, etc.)
- Supabase remains the single source of truth
- Mobile app behavior is preserved — it uses the same Supabase backend

---

## 18. Final Audit Report

### A. Current Architecture

Harafy is a **Flutter Web SPA** backed by Supabase. It serves three user types from a single codebase: customers (no Supabase auth, WhatsApp OTP only), technicians (Supabase auth), and admin (Supabase auth, hidden access). The admin feature follows Clean Architecture cleanly. The client and tech features are presentation-heavy, borrowing directly from admin repositories. State is managed with Riverpod, using a combination of stream providers (with 10-second polling for orders) and simple state providers for UI state. All routing is handled by GoRouter with hash-based URLs currently active.

### B. Current Structure

```
lib/
├── main.dart                    — Entry point, ProviderScope, commented-out path URL
├── core/                        — Router, theme, config, services, providers
│   ├── router/app_router.dart   — All 24 routes defined here
│   ├── constants/               — ACTIVE constants (hardcoded credentials)
│   └── services/                — Storage + WhatsApp OTP
├── features/
│   ├── admin/                   — Best structured: Clean Architecture throughout
│   ├── client/                  — Partial: rich presentation, thin domain
│   ├── tech/                    — Presentation-only; no data/domain
│   ├── auth/                    — Presentation-only; role stored in SharedPreferences
│   └── smart_assistant/         — Full structure (internals not deeply inspected)
└── shared/                      — 12 shared widgets
```

### C. Current Problems (Prioritized)

🔴 **Critical:**
1. `usePathUrlStrategy()` commented out — hash URLs block ALL SEO
2. No `robots.txt` — search engines have no indexing directive
3. Supabase credentials hardcoded in source code
4. WhatsApp API token hardcoded in source code
5. Tech phone number exposed publicly on profile screen

🟠 **High:**
6. `NotFoundScreen` not registered in GoRouter
7. No per-page meta tags (title, description, canonical)
8. No structured data per page
9. No sitemap
10. Frontend-only admin role enforcement
11. Duplicate `app_constants.dart` file

🟡 **Medium:**
12. No pagination — all queries fetch full tables
13. Polling-based "realtime" — 10-second intervals for all users
14. Tech feature has no data/domain layer (borrows from admin)
15. Business logic in UI (search normalization in `HomeScreen`)
16. Double-fetch: `ordersProvider` and `ordersStreamProvider` both active
17. OG image URL points to wrong domain
18. `_getAsset` switch duplicated across two screen files

### D. SEO Readiness

**Classification: ❌ Not Ready**

**Why:** The application is a JavaScript-rendered Flutter Web SPA using hash-based URLs. Search engine crawlers receive an empty `index.html` shell with no meaningful content. Even if path URLs were enabled, Flutter Web's canvas rendering means crawlers see `<flt-glass-pane>` elements rather than semantic HTML. There is no `robots.txt`, no `sitemap.xml`, no per-page meta tags, and no structured data beyond a static homepage `LocalBusiness` JSON-LD. The `index.html` has good baseline Open Graph and Twitter Card tags but they are identical for every page.

**What would make it Partially Ready:**
- Enable `usePathUrlStrategy()` (immediate fix)
- Add `robots.txt` (immediate fix)
- Pre-render public pages OR add a parallel SSG layer

**What would make it Ready:**
- A dedicated SSG/HTML layer for all public SEO pages
- Dynamic per-page meta tags
- Dynamic sitemap
- Structured data (Service, Person/Technician, Review schemas)
- Technician slug URLs

### E. Recommended Architecture

A **parallel layer pattern**:

1. **Flutter Web App** — remains the product for all interactive flows (booking, tracking, dashboard, admin). Enable `usePathUrlStrategy()`.

2. **Next.js / SSG Layer** (new, served from same domain via Vercel routing) — Generates static HTML pages for:
   - `/` — Landing page with service categories and links into Flutter app
   - `/services/[service-slug]` — Service category pages
   - `/technicians/[city]` — Technicians by city
   - `/technicians/[city]/[service-slug]` — Filtered by city + service
   - `/technician/[tech-slug]` — Individual technician profile page
   
   These pages link to the Flutter app for booking. They are built from Supabase data at build time or via Incremental Static Regeneration (ISR).

3. **Supabase Edge Functions** — Handle WhatsApp OTP (remove token from client), AI smart matching.

4. **Supabase remains the single backend** — No data duplication.

### F. Recommended Roadmap (based on actual codebase)

```
Phase 0 — Immediate Fixes (No architecture needed)
  - Uncomment usePathUrlStrategy()
  - Add web/robots.txt
  - Wire NotFoundScreen to GoRouter errorBuilder
  - Remove phone number from public tech profile
  - Delete stale lib/constants/app_constants.dart
  - Fix OG image URL in index.html

Phase 1 — Security Baseline
  - Move credentials to environment variables (Vercel env + --dart-define)
  - Move WhatsApp OTP sending to a Supabase Edge Function
  - Add server-side admin role check (Supabase JWT claims)

Phase 2 — SEO Foundation
  - Add slug field to technicians table (DB migration)
  - Auto-generate slug on technician creation
  - Wire /technician/:slug route to TechPortfolioScreen
  - Add robots.txt and basic sitemap

Phase 3 — Public SEO Pages (SSG Layer)
  - Set up Next.js/SSG project on same Vercel deployment
  - Build static homepage (/)
  - Build /services/[slug] pages (8 service types)
  - Per-page meta tags, canonical, Open Graph

Phase 4 — Technician & Location Pages
  - Build /technician/[slug] pages
  - Build /technicians/[city] pages
  - Build /technicians/[city]/[service] pages
  - Structured data: Person, Service, Review schemas

Phase 5 — Technical SEO
  - Dynamic sitemap generation
  - Per-page structured data (JSON-LD)
  - Image optimization via Supabase Storage transforms
  - Canonical URL enforcement

Phase 6 — Performance
  - Implement pagination in repositories
  - Replace polling with Supabase Realtime subscriptions
  - Reduce double-fetch (merge ordersProvider and ordersStreamProvider)

Phase 7 — Architecture Cleanup
  - Create tech feature's own data/domain layers
  - Create unified auth provider (Riverpod)
  - Move business logic out of UI (search normalization, location scoring)

Phase 8 — ROADMAP Alignment (Product)
  - Acceptance timer for technicians (ROADMAP Phase 2)
  - Reliability Score (ROADMAP Phase 2)
  - Full order lifecycle with extended statuses (ROADMAP Phase 3)
  - Learning/outcomes integration (ROADMAP Phase 4)
```

---

## Decision Required

The following changes require explicit approval before implementation begins:

| # | Decision | Why It Needs Approval | Impact |
|---|---|---|---|
| **D1** | Enable `usePathUrlStrategy()` | This changes ALL URLs in the live application. Any existing shared links (from WhatsApp messages, etc.) using `/#/` format will break. Requires coordinated release. | All existing deep links |
| **D2** | Add `slug` field to `technicians` table | Requires a database migration on the live Supabase instance. Technician URLs will change from UUID to slug. | DB schema, routing, existing portfolio URLs |
| **D3** | Approach for public SEO pages | Choose between: (a) Next.js parallel app on same domain, (b) Pre-rendered static HTML generated at build time, (c) Vercel Edge Middleware with HTML injection. Each has different complexity and cost. | Architecture, timeline, cost |
| **D4** | Move WhatsApp OTP to Edge Function | Changes the OTP flow. Token must be removed from client. Requires deploying and testing a Supabase Edge Function. If it fails, OTP breaks. | Customer booking flow |
| **D5** | Server-side admin role enforcement | Requires Supabase Auth configuration changes (custom claims or separate role check). Could lock out the current admin if misconfigured. | Admin access |
| **D6** | Replace polling with Realtime | Supabase Realtime has concurrent connection limits on the free/pro tier. Need to verify current plan allows the expected concurrent user count. | All real-time features |

> **Recommendation:** Start with Phase 0 fixes (D1 excluded until coordinated) and Phase 1 security baseline. These are low-risk and unblock all further work. Then schedule D1 (path URLs) as a coordinated release with the Phase 3 SSG work to avoid breaking existing links.
