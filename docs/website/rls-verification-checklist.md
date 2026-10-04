# RLS Verification Checklist — Harafy Database

> **Document Type:** Security Verification Matrix & RLS Checklist  
> **Status:** 100% VERIFIED (Repository + Supabase Dashboard Export)  
> **Date:** September 23, 2026

---

## 1. RLS Policy Inventory & Verification Status Matrix

All tables in `public` schema have **`rls_enabled: true`**. However, due to permissive policies with `USING (true)`, effective access is wide open across multiple tables:

| Table | RLS Enabled? | SELECT | INSERT | UPDATE | DELETE | Dashboard Policy Name & Expression | Verified Status |
|---|---|---|---|---|---|---|---|
| `orders` | ✅ Enabled | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | Admin only | `public_read_own_order` (`USING true`), `public_insert_orders` (`CHECK true`), `Allow clients to rate their orders` (`USING true`) | ✅ **VERIFIED (ALL OPEN)** |
| `technicians` | ✅ Enabled | `anon`, `auth` | `auth` | `auth` | `auth` | `Allow public read access on technicians` (`USING true`), `Enable manage for authenticated users` (`USING true`) | ✅ **VERIFIED (ALL OPEN)** |
| `order_logs` | ✅ Enabled | `anon`, `auth` | `anon`, `auth` | None | None | `Allow select for all users` (`USING true`), `Allow insert for all users` (`CHECK true`) | ✅ **VERIFIED** |
| `order_messages` | ✅ Enabled | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | `Allow all access to order_messages` (`USING true`) | ✅ **VERIFIED** |
| `wallet_recharges` | ✅ Enabled | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | `Allow all access to wallet_recharges` (`USING true`) | ✅ **VERIFIED** |
| `warranty_claims` | ✅ Enabled | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | `Allow all access to warranty_claims` (`USING true`) | ✅ **VERIFIED** |
| `job_outcomes` | ✅ Enabled | `anon`, `auth` | `auth` | `auth` | None | `Allow public read access on job_outcomes` (`USING true`), `Allow authenticated write/update` (`USING true`) | ✅ **VERIFIED** |
| `promo_codes` | ✅ Enabled | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | `anon`, `auth` | `Allow all access to promo_codes` (`USING true`) | ✅ **VERIFIED** |
| `services` | ✅ Enabled | `anon`, `auth` | `auth` | `auth` | `auth` | `Allow public read access on services` (`USING true`), `Allow admin all access on services` (`TO authenticated USING true`) | ✅ **VERIFIED** |

---

## 2. Table-by-Table Detailed Breakdown (Dashboard Verified)

### Table: `orders`
- **RLS Enabled:** YES
- **Policies in Dashboard:**
  1. `public_read_own_order` (SELECT for `anon, authenticated`): `USING (true)` — **CRITICAL:** Despite the policy name, any user can SELECT all orders.
  2. `public_insert_orders` (INSERT for `anon, authenticated`): `WITH CHECK (true)` — Anyone can create orders.
  3. `Allow clients to rate their orders` (UPDATE for `public`): `USING (true) WITH CHECK (true)` — **CRITICAL:** Any anonymous user can update any order (cancel, change status, alter customer details).
  4. `authenticated_update_orders` & `admin_update_orders` (UPDATE for `public`): `USING (auth.role() = 'authenticated')`.
  5. `admin_only_orders` (ALL for `public`): `USING (auth.email() = 'mohamedsolaiman707@gmail.com')`.
- **Effective Access:**
  - `SELECT`: **PUBLIC (ALL ORDERS)**
  - `INSERT`: **PUBLIC**
  - `UPDATE`: **PUBLIC (ANY ORDER)**
  - `DELETE`: Admin only (`mohamedsolaiman707@gmail.com`)
- **Status:** ✅ **100% VERIFIED — CRITICAL VULNERABILITY EXPOSED**

---

### Table: `technicians`
- **RLS Enabled:** YES
- **Policies in Dashboard:**
  1. `Allow public read access on technicians` (SELECT for `public`): `USING (true)` — **CRITICAL:** Any anonymous visitor can select all columns (phone, national ID URLs, criminal record URL, wallet balance, total earnings, admin notes).
  2. `Allow authenticated users to read technicians` (SELECT for `public`): `USING (auth.role() = 'authenticated')`.
  3. `Enable manage for authenticated users` (ALL for `authenticated`): `USING (true) WITH CHECK (true)` — **CRITICAL:** Any authenticated technician (or any logged-in user) can update or delete any technician's record (e.g. modify wallet balances, change verification status).
  4. `admin_only_techs` (ALL for `public`): `USING (auth.email() = 'admin@example.com')`.
- **Effective Access:**
  - `SELECT`: **PUBLIC (ALL COLUMNS & RECORDS)**
  - `INSERT`: **ANY AUTHENTICATED USER**
  - `UPDATE`: **ANY AUTHENTICATED USER**
  - `DELETE`: **ANY AUTHENTICATED USER**
- **Status:** ✅ **100% VERIFIED — CRITICAL VULNERABILITY EXPOSED**

---

### Table: `order_logs`
- **RLS Enabled:** YES
- **Policies in Dashboard:**
  1. `Allow select for all users` (SELECT for `public`): `USING (true)`.
  2. `Allow insert for all users` (INSERT for `public`): `WITH CHECK (true)`.
- **Effective Access:** Public read and public insert.
- **Status:** ✅ **VERIFIED**

---

### Table: `order_messages`
- **RLS Enabled:** YES
- **Policies in Dashboard:** `Allow all access to order_messages` (ALL for `public`): `USING (true) WITH CHECK (true)`.
- **Effective Access:** Fully open to anonymous public read/write/update/delete.
- **Status:** ✅ **VERIFIED**

---

### Table: `wallet_recharges`
- **RLS Enabled:** YES
- **Policies in Dashboard:**
  1. `Allow all access to wallet_recharges` (ALL for `public`): `USING (true)`.
  2. `Allow admin all access on wallet_recharges` (ALL for `authenticated`): `USING (true)`.
  3. `Allow authenticated insert on wallet_recharges` (INSERT for `authenticated`): `WITH CHECK (true)`.
  4. `Allow public select on wallet_recharges` (SELECT for `public`): `USING (true)`.
- **Effective Access:** Fully open to anonymous public read/write/update/delete via policy #1.
- **Status:** ✅ **VERIFIED**

---

### Table: `warranty_claims`
- **RLS Enabled:** YES
- **Policies in Dashboard:** `Allow all access to warranty_claims` (ALL for `public`): `USING (true)`.
- **Effective Access:** Fully open to anonymous public read/write/update/delete.
- **Status:** ✅ **VERIFIED**

---

### Table: `promo_codes`
- **RLS Enabled:** YES
- **Policies in Dashboard:** `Allow all access to promo_codes` (ALL for `public`): `USING (true)`.
- **Effective Access:** Fully open to anonymous public read/write/update/delete.
- **Status:** ✅ **VERIFIED**

---

### Table: `services`
- **RLS Enabled:** YES
- **Policies in Dashboard:**
  1. `Allow public read access on services` (SELECT for `public`): `USING (true)`.
  2. `Allow admin all access on services` (ALL for `authenticated`): `USING (true)`.
- **Effective Access:** Public read. Any logged-in user (`authenticated`) can insert/update/delete services.
- **Status:** ✅ **VERIFIED**

---

### Table: `job_outcomes`
- **RLS Enabled:** YES
- **Policies in Dashboard:**
  1. `Allow public read access on job_outcomes` (SELECT for `public`): `USING (true)`.
  2. `Allow authenticated write on job_outcomes` (INSERT for `authenticated`): `WITH CHECK (true)`.
  3. `Allow authenticated update on job_outcomes` (UPDATE for `authenticated`): `USING (true) WITH CHECK (true)`.
- **Effective Access:** Public read. Authenticated insert/update.
- **Status:** ✅ **VERIFIED**

---

## 3. Summary of Confirmed Findings

With the dashboard export, **100% of security findings are now CONFIRMED VULNERABILITIES**:

1. **`orders` table isolation is ZERO:** `public_read_own_order` has `USING (true)` and `Allow clients to rate their orders` has `USING (true)`. Any anonymous API call can read all orders and cancel or modify any order.
2. **`technicians` table isolation is ZERO:** `Allow public read access on technicians` has `USING (true)` exposing all sensitive PII and ID documents. `Enable manage for authenticated users` has `USING (true)` allowing any logged-in tech to edit any other tech's wallet or profile.
3. **`admin_only_orders` policy email mismatch:** Uses `mohamedsolaiman707@gmail.com`, while `admin_only_techs` uses `admin@example.com` — proving hardcoded ad-hoc admin policies with zero central role enforcement.
