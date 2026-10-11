# TimeGuard Web Back Office

PHP 8.1+, PDO MySQL, mbstring, sessions, fileinfo. Install next to the existing `timeguard_api` in XAMPP. PHP 8.1 is the minimum because the shared polygon rules use `array_is_list()`.

## Installation

1. Start Apache and MariaDB in XAMPP. Keep the current API/database/configuration.
2. From the project root run:

```powershell
C:/xampp/php/php.exe backend/install-backoffice.php --config=C:/xampp/htdocs/timeguard_api/config/database.php
C:/xampp/php/php.exe backend/install-backoffice.php --config=C:/xampp/htdocs/timeguard_api/config/database.php --apply
powershell -File backend/deploy-backoffice.ps1
```

3. Open http://localhost/timeguard_admin/ and sign in using an existing Admin, HR or Supervisor account. Only for databases imported from the supplied demo SQL: usernames `admin`, `hr`, `supervisor`, password `123456`. Change demo passwords before real use through Admin account management. Deployment never resets passwords or creates demo accounts in the existing database.

The installer adds only `tech_web_audit_logs`. It does not alter or reimport the 11 approved core tables. The real full table names follow `../timeguard_api/config/table_names.php` (E → employees, G → geofence_areas etc.). No generic users table is introduced.

The web uses the sibling API's `config/database.php` and its local/environment overrides. For a different layout set `TIMEGUARD_API_ROOT`, or create protected `config/local.php` returning `['api_root'=>'C:/path/to/timeguard_api']`. Never put credentials in JavaScript. Source preview requires selecting the deployed API config or supplying database environment overrides.

## Permissions

| Function | Admin | HR | Supervisor |
|---|---|---|---|
| Employee details | Organization | Organization | Own department |
| Create/edit/status employees | — | Yes | — |
| Manually update Google UID | Yes | Yes | — |
| Departments | Manage | Manage | — |
| Admin/HR/Supervisor accounts | Manage | — | — |
| Geofences and assignments | View | Manage | — |
| Face image/approval | — | Yes | — |
| Attendance/offsite | View | View | Own department, approve/reject |
| Reports and CSV | Organization | Organization | Own department |
| System settings | Manage | — | — |

Admin employee access is read-only except the explicitly requested Google UID maintenance. HR manages employees. Deactivation preserves history; no hard-delete of core records is offered. All detail/image/export/write handlers enforce permissions on the server. Supervisor scope follows the employee's **current** department (the approved schema has no historical department snapshots).

## Polygon workflow

### University + department layers (2 October 2026)

HR creates a university boundary as an existing G polygon (select its responsible department), then selects it as the campus layer in the geofence overview. The selector is protected HR/CSRF configuration stored in `config/campus-layer.local.json`; deployment preserves this file. No core columns, tables, or fake campus coordinates were added. All active department polygons appear as colored overlays with on/off controls, including in creation/editing and assignment previews. Only the selected polygon is editable; reference layers are read-only.

Normal mobile attendance now requires being inside **both** the chosen active campus polygon and an active assigned area of the employee's own department. Assigning the university polygon alone does not grant attendance access. Approved offsite requests retain their explicit time-bounded exception and generate outside events. If campus configuration is missing/invalid/inactive, attendance fails with a setup message until HR configures it. `timeguard_api/config/campus.php` reads the sibling web configuration; alternate installation paths can override `TIMEGUARD_CAMPUS_LAYER_FILE`. New active EA assignments must match the employee's department. Existing assignments are retained, but campus/cross-department assignments do not qualify for normal check-in/out.

HR → พื้นที่ปฏิบัติงาน → เพิ่ม → select department → pan/zoom or enter `latitude,longitude` → polygon tool → click at least three vertices → click first point/Finish → save. Edit tool moves vertices; trash removes the drawing so it can be redrawn. Deactivate a saved area using its status field rather than deleting referenced history. No paid API or radius-only conversion.

Coordinates remain an open array of `{lat,lng}` points. Backend imports the existing `config/rules.php` to reject invalid/self-intersecting polygons. Center is calculated server-side as the mean of vertices, used only for centering (not attendance authorization). Leaflet preview, editor and attendance map share `assets/js/maps.js`. Attendance maps display **current** geofence geometry, not a historical snapshot.

EA assignments serialize on the employee row, enforce one active primary, reject overlapping active assignments of the same area, and validate date ranges. Multiple secondary areas are supported. Mobile APIs are unchanged; older management API clients retain their original validation behavior.

## Approval and attendance

Face registrations retain `pending/approved/rejected`; HR ID is recorded in `approved_by`. Offsite and attendance retain Thai `รออนุมัติ/อนุมัติ/ปฏิเสธ`; Supervisor ID is recorded. Decisions, notices and audit entries commit together. Only pending records can be decided. Face encodings are never selected for the web UI. Images are served through an authenticated handler, not a storage URL.

The mobile API currently inserts successfully verified attendance as approved and refuses unauthorized outside-area check-ins. The web can review pending records when they exist; it does not change the mobile capture policy or manufacture pending attendance. AT remains one event per row. Face service/Google OAuth setup remains as documented in the root README.

## Reports and security

Date, employee, department, work area, check type, late, zone and approval filters; group reports by employee/department/area; CSV export and full filtered printable view (print cap 5,000 rows, CSV streams all). Counts distinguish events and distinct employees. Dashboard missing check-ins counts active employees and does not infer leave/holiday schedules.

HttpOnly, SameSite=Lax session cookies; Secure on HTTPS; session rotation on login; 30-minute idle/8-hour absolute expiry; active user revalidated on every request; password changes invalidate sessions. POST-only mutation/logout with CSRF. Prepared SQL, escaped HTML, CSP, no external script CDN required after install, restricted image filenames/types, spreadsheet formula escaping. Technical audit stores actor/action/record/changed field names without secret values. Apache must honor `.htaccess`; do not expose source config, database scripts or storage directories. Use HTTPS for nonlocal operation.

Bootstrap 5.3.3, Bootstrap Icons 1.11.3, Leaflet 1.9.4 and Leaflet.draw 1.0.4 are vendored locally. Map tiles require Internet, use OpenStreetMap with attribution; no address-search service is called. Follow https://operations.osmfoundation.org/policies/tiles/ for public deployment volume. Upstream references: https://leafletjs.com/reference and https://leaflet.github.io/Leaflet.draw/docs/leaflet-draw-latest.html .

## Test

```powershell
C:/xampp/php/php.exe backend/tests/backoffice_test.php
```

By default the harness reads deployed API connection credentials, creates a random `timeguard_webtest_*` database, imports synthetic fixtures, starts a temporary PHP server on 18766, tests authentication/CSRF/RBAC/CRUD/polygons/assignments/approvals/reports, then stops the server and drops **only that temporary database**. `TG_TEST_CONFIG` overrides the config path. Requires permission to create/drop the isolated database and write PHP sessions. It never modifies real employee records. For a temporary interactive fixture preview set `TG_WEB_PREVIEW=1` and run in a terminal; Enter stops and cleans up.
