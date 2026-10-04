# Harafy Web — Architecture Decision Record

> **Verification Date:** 2026-09-22  
> **Pass:** Second — Read-Only Verification & Decision  
> **Status:** Evidence-based. All findings traced to specific files and line numbers.  
> **No code was modified during this pass.**

---

## D1 — Routing Decision

### Current State (as of this verification)

The USER has **already enabled** `usePathUrlStrategy()` in `main.dart` line 14 during this session. The call is now **active** (no longer commented out):

```dart
// lib/main.dart, line 14
usePathUrlStrategy();
```

**Evidence:** Confirmed by reading `lib/main.dart` in full. The diff shown in context confirms the change.

### Existing URL Patterns Found

| Pattern | Source | URL Format | Safe After Change? |
|---|---|---|---|
| `context.go('/')` | `track_screen.dart` L37 | Path-based | ✅ No issue |
| `context.go('/track/${result.trackingCode}')` | `request_screen.dart` L244 | Path-based | ✅ No issue |
| `context.push('/request', extra: {...})` | `client_orders_screen.dart` L540 | Path-based | ✅ No issue |
| `context.push('/track/${order.trackingCode}')` | `client_orders_screen.dart` L514 | Path-based | ✅ No issue |
| `context.push('/request', extra: {...})` | `tech_portfolio_screen.dart` L108 | Path-based | ✅ No issue |
| `context.go('/')` | `not_found_screen.dart` L38 | Path-based | ✅ No issue |
| `context.go('/login')` | `role_selection_screen.dart` L38 | Path-based | ✅ No issue |
| `context.push('/login')` | `role_selection_screen.dart` L38 | Path-based | ✅ No issue |
| `context.go('/tech/login')` | `role_selection_screen.dart` L23 | Path-based | ✅ No issue |

**Finding:** No internal navigation uses hardcoded `/#/` fragments. All GoRouter navigation calls use path strings. Zero hash-URL references found in Dart code (confirmed via grep of `"/#/"` across all `lib/` files — zero results).

### External Links Containing `https://7arafi.com/track/...`

**This is the critical finding for D1.**

`lib/core/utils/whatsapp_utils.dart` contains hardcoded tracking links sent to customers and technicians over WhatsApp:

```dart
// whatsapp_utils.dart, lines 27-28
'تابع طلبك: https://7arafi.com/track/$trackingCode'

// whatsapp_utils.dart, lines 32-33
'تابع: https://7arafi.com/track/$trackingCode'

// whatsapp_utils.dart, lines 45-46
'https://7arafi.com/track/$trackingCode'
```

These three places generate links that customers receive by WhatsApp. They point to `7arafi.com`, **not** `harafi-eg.vercel.app`. This means:

1. **Domain mismatch** — The links reference `7arafi.com` which may or may not be the production domain. The OG tags in `index.html` reference `harafi-eg.vercel.app`. The app is deployed to Vercel. These are two different domains.
2. **Any previously sent WhatsApp links** go to `7arafi.com` — which works only if that domain hosts the app or redirects to Vercel.
3. If `7arafi.com` is the **intended production domain** (and `harafi-eg.vercel.app` is the Vercel preview), then all currently sent links are already pointing to the correct domain — and are **unaffected by the path URL strategy change** since they use path URLs already (no `/#/`).
4. If `7arafi.com` is NOT set up, all historical tracking links sent to customers are broken regardless of this change.

**The `usePathUrlStrategy()` change itself does NOT break any existing WhatsApp links**, because those links already use clean paths (`/track/CODE`), not hash fragments.

### Vercel Compatibility

`vercel.json` is:

```json
{
  "rewrites": [
    { "source": "/:path*", "destination": "/index.html" }
  ]
}
```

This is a wildcard SPA rewrite. All paths are served `index.html`. This is **fully compatible** with path URL strategy. Direct URL access to `/track/ABC123` or `/tech/portfolio/uuid` will work correctly — Vercel returns `index.html`, Flutter hydrates, GoRouter reads the path and renders the correct screen.

There is also no conflict with `<base href="/">` in `index.html` (line 4) — this is correct for Flutter Web with path URLs.

### window.location / Uri.base Usage

Zero instances of `window.location` or `Uri.base` manipulation found in Dart source code (confirmed via grep). GoRouter handles all navigation.

### Is Switching to Path URLs Safe Now?

**YES — with one caveat.**

The switch is safe for the Flutter application itself. All internal navigation already uses path format. Vercel's rewrite rule already supports path URLs. No hash fragments were found anywhere in Dart code.

**The one caveat:** The `7arafi.com` domain question. If that domain is active and serves the app, it also needs the same Vercel rewrite config. But this is NOT introduced by the path URL change — it was already the case.

### External / Shared Links Risk

**No historical links exist in hash format** — since the app was previously on hash routing, any links that customers shared by copy-pasting the browser URL would have contained `/#/`. Those links will now return 404 if the user revisits them, because GoRouter will try to match `/#/track/CODE` as a literal path (not found).

**Mitigation:** Add a redirect in Vercel (or a GoRouter `redirect`) that detects `/#/` and strips the hash. This is low-effort and low-risk. But it is optional — most users won't have saved hash URLs.

### Required Changes After Enabling Path URLs

| Item | Status | File | Priority |
|---|---|---|---|
| Enable `usePathUrlStrategy()` | ✅ DONE by user | `main.dart` | Done |
| Vercel rewrite for SPA | ✅ Already correct | `vercel.json` | Done |
| `<base href="/">` in HTML | ✅ Already correct | `web/index.html` | Done |
| Wire 404 screen to GoRouter | ❌ Not done | `app_router.dart` | High |
| Optional: hash-to-path redirect for historical links | ❌ Not done | `vercel.json` | Low |
| Fix domain in WhatsApp tracking links | ❌ Not done | `whatsapp_utils.dart`, `whatsapp_otp_service.dart` | Medium |

### Summary

Path URL strategy is now correctly enabled. The Vercel infrastructure already supports it. No internal navigation used hash fragments. The only items remaining are the 404 wiring and the domain inconsistency (`7arafi.com` vs `harafi-eg.vercel.app`) in WhatsApp messages.

---

## D2 — SEO Architecture Decision

### What Flutter Web Can Realistically Do for SEO

| SEO Capability | Flutter Web (SPA) | Notes |
|---|---|---|
| Clean path URLs | ✅ Now possible (path URL enabled) | GoRouter + Vercel rewrite |
| `robots.txt` | ✅ Can be added to `web/` | Simple file |
| `sitemap.xml` | ⚠️ Static only or build-time | Cannot be dynamic without a server |
| Per-page `<title>` tag | ❌ Not possible natively | Flutter renders to canvas, cannot mutate `<title>` |
| Per-page `<meta description>` | ❌ Not possible natively | Same reason |
| Per-page `<link rel="canonical">` | ❌ Not possible natively | Same reason |
| Semantic HTML (H1, H2, etc.) | ❌ Not possible | Canvas rendering; no HTML structure |
| Open Graph per-page | ❌ Not possible natively | Static only in `index.html` |
| Structured data (JSON-LD) per-page | ❌ Not possible natively | Static only |
| Image alt text for crawlers | ❌ Not possible | Images are inside canvas |
| Google crawlability (content) | ⚠️ Partial | Googlebot can execute JS; may index some text |
| Bing/Other crawlability | ❌ Very limited | These do not wait for JS heavily |
| Core Web Vitals (LCP/CLS) | ⚠️ Poor initially | Large WASM bundle; blank until loaded |
| Social media link previews | ❌ Static only | OG tags are global, not per-page |

### Option Comparison

| Criteria | Option A: Flutter Only | Option B: Flutter + Prerender | Option C: Flutter + Next.js SSG |
|---|---|---|---|
| **SEO capability** | 15-20% | 40-60% | 90-100% |
| **Google crawlability** | Partial (JS-dependent) | Good (static HTML) | Excellent (SSR/SSG HTML) |
| **Per-page meta** | ❌ No | ✅ Via prerender | ✅ Via getStaticProps |
| **Technician pages** | ❌ UUID only, no content | ✅ Can generate slug HTML | ✅ Full HTML with schema |
| **Service pages** | ❌ No content for crawlers | ✅ Static HTML | ✅ Full HTML |
| **Location pages** | ❌ Not possible | ⚠️ Build-time only, stale | ✅ ISR (on-demand) |
| **Dynamic sitemap** | ❌ No | ⚠️ Build-time only | ✅ API route |
| **Structured data** | ❌ Static only | ✅ Per-page injection | ✅ Per-page |
| **Initial dev complexity** | Low | Medium | High |
| **Maintenance complexity** | Low | Medium | Medium-High |
| **Hosting cost** | Current (free Vercel) | Current + prerender service | Additional Next.js project on Vercel |
| **Deployment complexity** | Simple | Medium | Two separate deployments or monorepo |
| **Customer/tech flows** | ✅ Unchanged | ✅ Flutter handles interaction | ✅ Flutter handles interaction |
| **Admin flow** | ✅ Unchanged | ✅ Unchanged | ✅ Unchanged |
| **Performance (Time to Content)** | Poor (WASM load) | Good (prerendered HTML first) | Excellent (SSG HTML first) |
| **Long-term scalability** | Poor | Medium | Excellent |
| **Sitemap** | ❌ | ⚠️ Build-time | ✅ Dynamic |
| **Canonical URLs** | ❌ | ✅ | ✅ |

### 1. What Can Realistically Be Achieved with Current Flutter Web Architecture

Without any additional layer:

- Clean path URLs: ✅ Now done
- `robots.txt`: ✅ Can be added (2 minutes)
- A single static `sitemap.xml`: ✅ Can be added manually and updated periodically
- Static structured data for the homepage: ✅ Already in `index.html`
- Improved homepage OG tags: ✅ Can be updated in `index.html`

That is the realistic ceiling for pure Flutter Web SPA. Everything above this list requires either a server or pre-rendering.

### 2. What Flutter Web Cannot Do Well for SEO

Flutter Web renders all content inside a `<flt-glass-pane>` canvas element. The HTTP response body from the server (before JavaScript executes) contains only the Flutter bootstrap JS and the loading spinner. The meaningful content (technician names, services, descriptions, prices) is rendered by Dart/WASM at runtime.

This means:
- Any crawler that does not execute JavaScript (Bing, many social crawlers) sees zero content
- Even Googlebot, which executes JavaScript, sees the content with a delay and may not follow all dynamic routes
- Technician profiles at `/tech/portfolio/uuid` return empty HTML until Flutter loads and fetches the tech from Supabase
- The meta title and description cannot change per-page — every page returns the same `<title>حرفي | صنايعي تثق فيه</title>`

### 3. Is Prerendering Enough?

**Partially.** Prerendering (e.g., using a headless browser service like Prerender.io, or a build-time puppeteer script) intercepts crawler requests and serves a snapshot of the rendered HTML.

Benefits:
- Works for static or low-frequency-change pages (service category pages)
- No changes to the Flutter application
- Works with the existing Vercel deployment

Limitations:
- Requires a separate paid service or custom build step
- Dynamic content (technician profiles, live availability) will be stale in prerendered snapshots
- Cannot generate truly semantic HTML — the "snapshot" is still the canvas-rendered output, just captured after JavaScript ran
- Build-time prerender does not update when technicians change
- Complex to set up correctly for Arabic RTL content

**Conclusion on prerendering:** Prerendering is a stop-gap. It helps Google index the homepage and fixed service pages. It does NOT solve technician profile SEO at scale (hundreds of profiles that change frequently).

### 4. When Does a Separate SSG/SSR Layer Become Justified?

A separate layer becomes justified when **the pages that need SEO have dynamic content that changes per-URL**:

- `/technician/ahmed-ali-sbaak` — unique content per technician
- `/technicians/tanta` — content depends on which techs serve Tanta
- `/technicians/tanta/plumbing` — intersection of city + service

These pages cannot be pre-rendered correctly at build time because the data changes (technicians become verified, change areas, update portfolios). This is the point where a server-rendered layer (Next.js with ISR) becomes the correct solution.

### 5. Whether Next.js Should Be Introduced Now or Later

**Not now. Later — when the first SEO pages are ready to build.**

**Reason to wait:**
- Next.js is a significant new codebase to maintain alongside Flutter
- The immediate SEO wins (robots.txt, sitemap, path URLs, OG fix) do not require Next.js
- The Flutter app still needs the 404 fix, WhatsApp domain fix, and phone number protection first
- The `technicians` table does not yet have a `slug` field — Next.js pages cannot be built for `/technician/[slug]` until that exists

**Trigger condition to introduce Next.js:**
When the `slug` field is added to the `technicians` table AND the decision is made to build SEO landing pages. At that point, a minimal Next.js deployment on Vercel becomes the correct tool.

### 6. Recommended Architecture

**Phased approach: Flutter-first, Next.js later when SEO pages are ready to build.**

```
Phase 1 (NOW) — Flutter Web improvements:
  - robots.txt  
  - Static sitemap.xml (manually maintained)  
  - Fix OG image URL (7arafi.com → harafi-eg.vercel.app or real domain)  
  - Wire 404 to GoRouter  
  - Fix WhatsApp tracking link domain  
  - Remove phone number from public tech portfolio

Phase 2 (Next Sprint) — DB + slugs:
  - Add `slug` field to technicians table  
  - Auto-generate slug on registration  
  - New GoRouter route: /technician/:slug (in addition to current /tech/portfolio/:id)  
  - Flutter renders the slug-based URL correctly

Phase 3 (SEO Layer) — Next.js on same Vercel:
  - Create Next.js project in /seo/ subdirectory  
  - Static pages: /, /services/[slug], /technician/[slug]  
  - Next.js reads Supabase data at build time (ISR for freshness)  
  - Vercel routing: Next.js serves /services/* and /technician/*  
                    Flutter serves everything else (booking, tracking, admin)  
  - Dynamic sitemap via Next.js API route  
  - Canonical URLs, structured data per page
```

**Why this sequence:**
- Phase 1 delivers measurable SEO improvements with zero risk and zero new dependencies
- Phase 2 is a prerequisite for Phase 3 — Next.js pages need slugs
- Phase 3 introduces Next.js only after the foundation (slugs, security) is correct

---

## D3 — Database Changes

> See security-audit.md D7 section for database change recommendations.

---

## D4 — SEO URL Structure Evaluation

### Proposed Structure vs Current Application

```
/                             ✅ Flutter renders this now; pre-render for SEO
/services/plumbing            ❌ Current route is /service/plumbing (singular)
/services/electricity         ❌ Same — plural vs singular mismatch
/technicians/tanta            ❌ Does not exist; needs new route + city-based DB query
/technicians/kafr-el-zayat    ❌ Same
/technicians/tanta/plumbing   ❌ Does not exist
/technician/{slug}            ❌ Current is /tech/portfolio/{uuid}; needs slug field
```

### Route Analysis

| Proposed URL | Indexable? | DB-Backed? | Thin Content Risk? | Notes |
|---|---|---|---|---|
| `/` | ✅ Yes | No (static) | No | Already exists; needs prerender |
| `/services/[slug]` | ✅ Yes | Partially | Low risk | 8 fixed pages, rich description possible |
| `/technicians/[city]` | ✅ Yes | Yes | Medium risk | May be thin if city has 1-2 techs |
| `/technicians/[city]/[service]` | ⚠️ Selective | Yes | High risk | Many combinations; most will have 0 techs |
| `/technician/[slug]` | ✅ Yes | Yes | No | Each tech is unique content |

### Canonicalization Risk

`/technicians/tanta/plumbing` and `/technicians/kafr-el-zayat/plumbing` could create thin or near-duplicate content. These pages need unique content (actual technician bios, reviews, prices) to avoid penalties.

**Recommendation:** Do NOT generate city×service pages unless each page shows at least 2-3 real technicians with profiles. Empty pages or pages with 1 tech are thin content.

### Route Naming Correction

Current Flutter route: `/service/:type` (singular)  
Proposed SEO route: `/services/[slug]` (plural)

These should be aligned. The Flutter route should also use the plural `/services/` when the SEO layer is built, or a redirect from `/services/plumbing` → `/service/plumbing` (Flutter) should be configured in Vercel.

### Which Routes Should Be Application-Only (Not Indexed)

| Route | Action |
|---|---|
| `/request` | `noindex` — transactional form |
| `/track/:code` | `noindex` — private order data |
| `/my-orders` | `noindex` — private |
| `/favorites` | `noindex` — private |
| `/tech/login`, `/tech/register` | `noindex` |
| `/login` | `noindex` |
| `/admin/*` | `noindex` or block in robots.txt |
| `/welcome` | `noindex` |
| `/smart-assistant` | `noindex` — interactive tool |

---

## Final Decision Matrix

| Decision | Current State | Evidence | Risk | Recommendation | Priority |
|---|---|---|---|---|---|
| **Path URLs** | ✅ Enabled by user | `main.dart` L14 | Low — Vercel rewrite already correct | Done. Wire 404 next | Done |
| **SEO Architecture** | Flutter SPA only | Audit finding | Medium | Phased: Flutter fixes → Slug → Next.js | High |
| **Next.js** | Not present | N/A | Medium | Introduce in Phase 3, not now | Deferred |
| **Prerendering** | Not configured | N/A | Low-Medium | Use as optional stop-gap if needed | Optional |
| **Technician slug** | Not in schema | `technician.dart` L18-41 | Medium (DB migration) | Required for SEO pages | High (Phase 2) |
| **Public tech profiles** | Exist at UUID URL | `app_router.dart` L134 | Low tech risk, phone exposure is medium | Slug URL + phone removal | High |
| **Supabase RLS** | Extremely weak | All SQL files | **CRITICAL** | See security-audit.md | 🔴 Critical |
| **Customer identity** | SharedPreferences + OTP | `client_orders_screen.dart` | Medium | See security-audit.md | High |
| **Admin authorization** | Frontend-only | `app_router.dart` L42-60 | **CRITICAL** | See security-audit.md | 🔴 Critical |
| **WhatsApp API token** | Hardcoded in client | `whatsapp_otp_service.dart` L11-12 | High | Move to Edge Function | High |
| **Realtime vs polling** | Polling every 10s | `orders_provider.dart` L55 | Low (current scale) | Defer until user count requires | Low |
| **Pagination** | None | Repository layer | Medium (future scale) | Defer | Low |
| **Architecture cleanup** | Tech has no domain layer | Directory structure | Low | Defer | Low |

### Launch Blockers

None that prevent the app from working — the app is live and functional.

### Security Blockers

1. Admin protection is frontend-only (no RLS on `orders` or `technicians` for admin operations)
2. Any authenticated Supabase user can read/write all orders and technicians
3. WhatsApp API token is exposed in client bundle — extractable by anyone with browser devtools
4. Customer phone numbers exposed to any visitor via tech portfolio "call" button

### SEO Blockers

1. ~~Hash URLs~~ — **RESOLVED** by user enabling path URLs
2. No `robots.txt` — crawlers have no guidance
3. Flutter canvas rendering — no semantic HTML; per-page meta impossible without SSG layer
4. No `sitemap.xml`
5. OG image URL points to `7arafi.com` (possibly wrong domain)
6. No technician slugs — `/tech/portfolio/uuid` is not a good SEO URL

### Performance Improvements

1. Orders provider fetches all orders every 10 seconds for all users
2. Both `ordersProvider` and `ordersStreamProvider` exist and both fetch all records
3. No pagination anywhere

### Long-Term Architecture Improvements

1. Tech feature should have its own data/domain layer
2. Unified auth provider (Riverpod)
3. Replace polling with Supabase Realtime subscriptions
4. Move business logic (search normalization) out of UI widgets
