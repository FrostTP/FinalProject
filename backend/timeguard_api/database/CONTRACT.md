# Approved Data Dictionary contract

Source: `docs/approved-data-dictionary.txt` at the project root. It takes precedence over the original prototype and README history.

Naming amendment (2026-09-24): the user explicitly requested full physical table names instead of DD aliases. `config/table_names.php` defines that mapping. The original source document is preserved; the schema contract test applies only the name mapping, then still checks all 100 fields, their types, primary keys and foreign keys. Existing ID prefixes remain unchanged.

The 11 core tables are **employees, admins, human_resources, supervisors, departments, system_configurations, face_biometrics, geofence_areas, employee_work_areas, offsite_work_requests, attendance_logs**. `timeguard.sql` uses the exact approved column names, varchar lengths, temporal types and decimal(10,6) coordinates. Primary/foreign identifiers remain varchar(10), including in PHP and Dart. No employee password, radius, check_in_time or check_out_time column is added.

## Explicit interpretations (no additional core columns)

- Core `status`: `active` / `inactive`; `face_biometrics.approval_status`: `pending` / `approved` / `rejected`. `offsite_work_requests.approval_status`: **รออนุมัติ / อนุมัติ / ปฏิเสธ**. `attendance_logs.check_type`: **เข้างาน / ออกงาน**. `attendance_logs.zone_status`: `inside` / `outside`. These vocabularies fill unspecified varchar domains; offsite_work_requests and check types follow the provided values exactly.
- `attendance_logs.area_id` is required. For an offsite event it references the employee's active assigned primary area (or first secondary area if no primary), while `zone_status=outside` and `offsite_request_id` record the exception. Employees without any valid employee_work_areas cannot record attendance until HR assigns an area. No fictitious geofence_areas is created and no nullable area column is substituted.
- face_biometrics allows historical registrations. admins retry after rejection inserts a new face_biometrics row and makes the previous active row inactive; it does not erase approval history. The API serializes enrollment per employees and permits one current active face registration. Images and encodings remain server-side; ordinary JSON responses omit face_encoding.
- HR alone approves face_biometrics because approved_by references human_resources; Supervisor alone approves offsite_work_requests because approved_by references supervisors. Admin does not impersonate either FK role. Supervisors are scoped to employees in the same departments because the approved employees table has no supervisor_id.
- employee_work_areas date bounds are inclusive; end_date=NULL means open-ended. The API serializes assignment writes on employees and permits only one primary row whose status is active. Set an old primary inactive or secondary before replacing it. Secondary areas remain independent.
- One check-in and one check-out per employee per Bangkok calendar day, with checkout requiring check-in. PHP locks employees and checks existing attendance_logs events before INSERT. These checks cover API writes; direct SQL imports must follow the same rules. No date or paired-time column is added just to create a unique index.
- The attendance system_configurations row (`config_type=attendance`) provides start_time and start_late. Missing times block attendance; time strictly after start_late marks check-in late. Checkout is never marked late. Other system_configurations types retain the DD fields; there is no invented generic value column.
- Valid events are automatically recorded with attendance_logs.approval_status=อนุมัติ and approved_by/approved_date=NULL (no human approval asserted). Manual review API supports pending attendance_logs rows if separately created, but this release does not create invalid attendance to be approved later.
- No absence figure is inferred: the approved tables do not include a work calendar, leave or absence model. Dashboard returns absent=null and displays “—”.
- Polygon JSON is an open ring of 3–200 `{lat,lng}` vertices, no duplicated closing vertex, no self intersections, no holes or antimeridian crossings. Boundary is inside. Center coordinates are for display and never replace polygon validation.

## Technical supporting tables

- `tech_auth_tokens`: hash-only bearer sessions, with separate nullable FKs to employees/admins/human_resources/supervisors and a check requiring exactly one identity. This is not a unified users table.
- `tech_notifications`: notifications with FK to employees.
- `tech_login_attempts`: login rate limiting.
- `tech_id_sequences`: generation of <=10-character string IDs without a racing MAX(id)+1 query.

## Mapping from the old prototype

| Old storage | Approved replacement / migration requirement |
|---|---|
| users | Split by role into employees/admins/human_resources/supervisors; assign and record string ID mappings. Only admins/human_resources/supervisors keep password hashes. employees needs real Google subject binding. |
| departments | departments; provide approved department_code/status/created_date. |
| biometric_enrollments | Does **not** qualify as face_biometrics. Device-auth approval has no face image or encoding. Employees must enroll faces anew. |
| work_areas with radius | Does **not** define geofence_areas polygon. HR must supply actual approved vertices. Do not silently approximate a circle. |
| employee_work_areas | employee_work_areas with string IDs, is_primary, effective_date, end_date and status. |
| outside_work_requests | offsite_work_requests; map real employee/supervisor IDs and approved date range. Old sub-day restrictions cannot be represented exactly; review before migration. No hidden start/end time fields are added. |
| attendance paired row | Split into attendance_logs check-in/check-out events only after mapping employees/geofence_areas/offsite_work_requests and verifying available evidence/method. Do not label old device-auth records as face_recognition or invent missing photos. |
| system_settings | system_configurations; map start_time and explicitly select start_late. |
| auth_tokens / notifications | Reissue tokens; map notifications into technical table only if required. |

No destructive or speculative legacy-data conversion runs automatically. Export the existing database before manual migration. Historical rows lacking required evidence/identity/polygon mappings should remain archived rather than fabricated as compliant records.

Deploy application and PHP together after importing this schema into a reviewed target database. The copy under `C:/xampp/htdocs/timeguard_api` is **not automatically synchronized** with the workspace.
