# TimeGuard HTML/JavaScript + JSON API

Entry pages are index.html (DirectoryIndex index.html). The browser requests JSON from api/index.php using fetch and same-origin PHP session cookies.

- index.html and each section/index.html: static HTML, CSS/Bootstrap/Leaflet imports, login template and loading shell. No PHP template tags.
- assets/js/frontend.js: browser routing, JSON loading, safe rendering, forms via fetch, CSV/print links and map initialization.
- assets/js/maps.js: existing Leaflet/Leaflet.draw polygon editing, department layers over campus boundary; unchanged.
- api/index.php: session, login, logout, page, save, review, delete, campus, link and export actions.
- api/models.php: role-scoped JSON view models. Password hashes and face encodings are never returned.
- controllers/: existing PHP server validation and data preparation, now respond with JSON for API calls.
- includes/repository.php, events.php: existing persistence, approvals and supervisor department restrictions.
- attendance/image.php: authenticated, authorized image endpoint (existing).
- config/: existing database/session/RBAC configuration.
- views/: protected legacy templates retained as reference/fallback; the HTML/JS frontend does not fetch these templates.

Old .php page URLs redirect to HTML directory URLs. Static pages may be opened anonymously, but every data API enforces server authentication/authorization. CSRF is attached to every mutation. No CORS, frontend build, new database tables or mobile API changes are required.

Base URL: http://localhost/timeguard_admin/
Keep the base element in index.html in sync if changing this deployment directory.

Tests ran against an isolated database: save/edit employee, department, geofence and department polygon; delete; campus selection; HR account creation; approval/rejection of offsite, attendance and biometrics; repeated-review blocking; CSV; CSRF; RBAC and department isolation. JavaScript rendering, escaping and fetch submission were checked with JSON models for all roles. Chrome checks covered login/dashboard and available Admin/HR pages, plus department creation. Full browser polygon completion and the remaining browser checks were not completed because the final Chrome launch was rejected. Do not describe these as fully passed browser tests.

Snapshot before this change: projectapp/build/html-js-api/backup (private local files; do not publish). Test credentials and data stay under ignored build/. Do not copy them to XAMPP.
