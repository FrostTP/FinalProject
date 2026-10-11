# Google employee automatic linking

Deployed auth/google.php verifies the Google ID token signature, audience, issuer and expiry using the existing verifier, before calling config/google_employee_link.php.

Within one transaction, lookup sub as google_uid first (including inactive employees). Existing active bindings keep working even if email changes. If no UID match exists, use only the email from the verified token, not an email sent separately by Flutter. Auto-link is allowed for verified @gmail.com or verified Google Workspace email whose hd matches its domain.

Find exactly one employee by case-insensitive trimmed email. Require active status and empty/null google_uid. Lock the row, conditionally update google_uid, issue the existing employee access token and commit together. Unknown/duplicate/inactive/conflicting accounts are rejected. No new employee is created and no existing UID is overwritten. Non-Google-hosted external emails require manual HR binding because email_verified alone does not prove current ownership, per Google's guidance.

No schema change, no reset of existing UID, no Flutter API contract change. Source of deployment is C:/xampp/htdocs/timeguard_api. Backup: build/google-auto-link/google-before.php. Tested 13 binding scenarios with a temporary table shadowing employees on one test connection. No live employee rows changed during tests. An actual new Google sign-in is needed to verify the full Google-to-Flutter flow.
