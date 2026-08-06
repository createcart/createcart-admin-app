# CreateCart Admin

A Flutter admin console for the **CreateCart** platform. One app, two roles:

| Role | Signs in with | Can do |
| --- | --- | --- |
| **Platform owner** (you) | owner username + **admin key** | Onboard businesses (tenants, auto-provisions their tables), set/reset their usernames & passwords, set their website URL, **delete a business** |
| **Business admin** (each tenant) | business **username (slug)** + **password** | Manage the menu (add / edit / delete one item, **stage stock toggles then Save**, **delete the whole menu**, price) and manage orders (accept → prepare → assign a delivery partner → delivered, or cancel) |

It is a thin client over the **same `createcart-api`** (Vercel + Supabase) the storefronts use — no new backend, no separate database. Everything happens through the existing multi-tenant API.

---

## How sign-in works

The login screen has a **Business / Platform owner** toggle.

### Business
- **Username** = the tenant slug, e.g. `brahmana-naivedyam`
- **Password** = the password the platform owner set for that business
- Validated by `GET /api/{tenant}/admin/me` with the `X-Tenant-Key` header.

### Platform owner
- **Username** = a display label (default `admin`)
- **Admin key** = the API's `CREATECART_ADMIN_KEY` (set in Vercel)
- Validated against `GET /api/_tenants` with the `X-Admin-Key` header.

> **Security note:** Business passwords are stored **hashed** (PBKDF2) on the server and are *never* returned. The platform console can **set or reset** a password but can never **show** an existing one. A tenant card shows only *“Password set”* / *“No password”*.

The signed-in session (role + credentials) is persisted on the device with `shared_preferences`, so the console reopens already logged in until you sign out.

---

## Typical first run

1. **Platform owner** signs in (username `admin`, your admin key).
2. The **Businesses** screen lists every tenant. Tap **Add business** to onboard one (this auto-creates all its per-tenant tables), or tap an existing tenant to **reset its password**, set its **website URL**, or **delete it** (Danger zone — drops all its data, type the name to confirm).
3. Hand the business its username (slug) + password.
4. The **business** signs in (Business tab) and manages its **Orders** and **Menu**.

---

## Menu editing (business)

- **One item:** tap it → editor → **🗑** to delete, or edit any field and **Save**.
- **Stock toggles are staged:** flip any number of items in/out of stock, then a **Save bar** applies them together and re-queries — so rapid toggles never race or show stale state. **Discard** reverts.
- **Whole menu:** **⋮ → Delete entire menu** (type `DELETE`) removes every item + combo (keeps categories).
- **Weight (grams):** set per item — drives accurate delivery quotes and the declared shipment weight. Blank uses the platform default.

---

## Order lifecycle

The action button on an order adapts to its status (state machine enforced by the API):

```
placed  ->  confirmed  ->  preparing  ->  out_for_delivery  ->  delivered
(New)       (Accept)       (Prepare)      (Assign partner)       (Mark delivered)
   \---------------- Cancel (any non-terminal state) ----------------/
```

- **Assign partner & dispatch** captures the delivery partner's name/phone, then moves the order to *out for delivery* — for your own riders.
- **Ship via Delhivery** (shown instead, once the order has a confirmed pincode from checkout) manifests a real courier shipment — generates a waybill, assigns "Delhivery" as the courier with a tracking link, then dispatches. The order card then shows the waybill, live courier status, and **Track** / **Refresh** actions.
- **Request pickup** (Orders → 🚚 icon) asks the courier to collect the day's manifested shipments.
- Order detail shows the customer (one-tap **Call** and **Map**), itemised bill, the delivery partner or shipment, and a full status timeline.
- Cancelling a shipped order also cancels the courier-side shipment (best-effort).

> Shipping runs on a **mock courier** until you configure `DELHIVERY_API_TOKEN` + `DELHIVERY_PICKUP_LOCATION` on the API — see that repo's README. The mock is fully functional for testing the whole flow end-to-end.

---

## Project layout

```
lib/
  main.dart                       AuthGate routes by role
  config.dart                     API base + app constants
  theme.dart                      CreateCart admin theme (indigo)
  session.dart                    Session (ChangeNotifier) + persistence
  api.dart                        AdminApi REST client (platform + tenant)
  models.dart                     Tenant, MenuItem, Category, Order, ...
  widgets.dart                    StatusChip, states, BrandMark, PoweredBy
  screens/
    login_screen.dart
    platform/tenants_screen.dart  list / add / manage tenants
    tenant/tenant_shell.dart      Orders - Menu - Account
    tenant/orders_screen.dart     list + filters + summary
    tenant/order_detail_screen.dart  status actions + courier + timeline
    tenant/menu_admin_screen.dart    list, out-of-stock toggle, item editor
```

---

## Run / build

Requires Flutter (3.3+) and JDK 17.

```bash
flutter pub get
dart run flutter_launcher_icons          # launcher icon
dart run flutter_native_splash:create    # branded splash
flutter run --release                    # on a connected device
# or
flutter build apk --release              # build/app/outputs/flutter-apk/app-release.apk
```

On Windows you can use the helper: `./build.ps1` (sets JAVA_HOME + builds + installs on the attached phone).

**API endpoint** is in `lib/config.dart` (`AppConfig.apiBase`, default the production Vercel API). For a local API use the Android emulator host `http://10.0.2.2:8000`, or your PC's LAN IP on a physical device.

`applicationId` is `in.createcart.createcart_admin`.

---

## Related repos

- **createcart-api** — the multi-tenant FastAPI service (this app's backend)
- **createcart-sdks** — the reusable Python SDKs the API is built from
- **brahmana-naivedyam-app** — a tenant storefront (customer-facing companion)

_Powered by CreateCart._
