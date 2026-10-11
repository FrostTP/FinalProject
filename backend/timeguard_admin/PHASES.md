# Implementation and verification record — 1 October 2026

## Inspection

- Flutter employee app: `lib/app.dart`, screens/services/models/config; Google sign-in, face capture, polygon checks and one-event attendance API.
- PHP API: `auth/`, `management/`, `attendance/`, `biometric/`, `outside_work/`, configuration and shared `config/rules.php`.
- Existing MySQL connection loaded from `timeguard_api/config/database.php` with local/environment overrides.
- Approved DD preserved in `docs/approved-data-dictionary.txt`; current SQL maps its aliases to the full table names already adopted by this project. All existing core columns and meanings retained.
- Back-office APIs previously existed; web pages did not. New web authentication uses sessions and the same staff password hashes, rather than borrowing a mobile bearer token.

## Phase 1 — authentication, authorization, layout, dashboard

Created `config/database.php`, `config/auth.php`, `includes/bootstrap.php`, shared header/sidebar/footer, `auth/`, `dashboard/`, local assets and index. Real scoped SQL dashboard, active-account checks, password_verify, session regeneration, CSRF, POST logout, timeout and revocation on credential changes.

Database changes: none. Configuration: existing API sibling or `TIMEGUARD_API_ROOT`; Apache/PHP sessions need a writable session directory. Initial HTTP tests: **17 passed**, including login for all roles, dashboard, CSRF, unauthenticated redirects and logout.

## Phase 2 — employees, departments, staff

Created `config/entities.php`, `includes/repository.php`, `includes/crud.php`, employees, departments, users/admins, users/hr, users/supervisors. Shared metadata excludes password hashes from display. Details, search, department/status filtering and pagination; Google link status and explicit Admin link action; deactivate rather than delete.

Database changes: installation SQL for **one technical table `tech_web_audit_logs`**, applied only to isolated test databases so far. Mutations require this table. Configuration: run `backend/install-backoffice.php --apply` against the selected connection when installing. Tests: **31 cumulative passed**, including employee writes/duplicates and Supervisor department isolation. Later staff password/XSS/revocation test cases were added but execution was not authorized; they are not counted as passed.

## Phase 3 — polygon geofences and employee areas

Created `geofences/`, `work_areas/`, `assets/js/maps.js`; extended CRUD/repository with Leaflet.draw and server-authoritative validation imported from the existing API. Create/edit/clear/redraw polygon, coordinate location, fit bounds, saved polygon preview, server-calculated center. Transactional primary/duplicate/date validation and employee area details.

Database changes: none beyond Phase 2 audit. Configuration: Internet for OpenStreetMap tiles; JS/CSS/fonts/icons are local. No paid map API. Tests: **47 cumulative passed**, including create/update, malformed/self-crossing polygons, derived center, denied Admin mutations and assignment date/duplicate/primary checks. Browser visual/drawing QA is still pending: the available computer-use runtime reported no browsers or apps after retry.

## Phase 4 — face approval

Created biometrics page and shared `includes/events.php`, `includes/event_page.php`, authenticated `attendance/image.php`. Encodings are never selected for the UI; only HR can view face registration images and approve/reject active pending registrations.

Database changes: none. Configuration: existing API storage; no new upload handler. Tests passed in the 81-check cumulative suite: encoding not exposed, Admin denied, HR attribution and repeated review rejected. Real face-service accuracy and real image display were not retested.

## Phase 5 — offsite review

Created `offsite/`; pending/approved/rejected filters, request details and Supervisor approval with transactional notification/audit.

Database changes: none. Configuration: none. Tests passed in the cumulative suite: same-department approval attribution and denied cross-department detail/write access.

## Phase 6 — attendance review and maps

Created `attendance/` pages and protected image handler. Event-per-row lists, date/employee/department/type/late/zone/approval filters, pagination, details and current polygon + recorded GPS map. Supervisor decisions on pending events only.

Database changes: none. Configuration: existing protected storage and current geofence coordinates. Tests passed: map data rendered in HTML, cross-department detail/image denied, rejection persisted, invalid date rejected. Current mobile acceptance policy remains unchanged; it does not create pending outside-area logs automatically.

## Phase 7 — reports and settings

Created `reports/`, `settings/`: seven report views, filters, group totals, streamed CSV with formula escaping, full filtered print view (5,000 row print cap), configurable attendance start/late times.

Database changes: none. Configuration: existing CFG attendance entry; only Admin may edit settings. Tests: **81 cumulative passed**, including all report modes, scoped CSV, print response, settings permission and invalid late-time threshold.

## Phase 8 — security and delivery

Created installer/deployer, README, this record and additional security test cases. Added `.gitignore` entry for local web config. Local vendor assets are present (including fonts, draw sprites and marker images). PHP syntax checks for all web files and installer/test harness passed. Existing polygon/attendance rules unit suite: **19 passed**. JavaScript syntax checks recorded in the task final report.

Remaining validation: added staff password/XSS/session-revocation tests, full mobile integration regression, real browser visual/interactive map QA, actual XAMPP deployment smoke test. Further privileged test execution was declined; no attempt was made to bypass it. `backend/tests/run_mobile_regression.php` is provided but not run in this task. Flutter source and API source were not modified; this alone is not a substitute for regression execution.

## Local state and delivery boundary

Installed after the user's instruction to finish without further testing: `tech_web_audit_logs` was created in the existing `timeguard_db`, and the site was copied to `C:/xampp/htdocs/timeguard_admin`. Open `http://localhost/timeguard_admin/`. Installer and deployer completed successfully; no further test suite or browser smoke test was run. Existing demo usernames/passwords work only if those seeded accounts still exist and were not changed.

A synthetic preview on `http://127.0.0.1:18766/` was started during testing. The request to send Enter to end it was declined, so it may still be running with its isolated `timeguard_webtest_*` database. Ending the test harness normally with Enter closes its PHP server and drops its own test database. The normal web test refuses an occupied port; set `TG_TEST_PORT` to an unused port if intentionally keeping preview open. No real employee data was copied into the preview.
