# Private Face Recognition service

`server.py` computes dlib/face_recognition embeddings and compares Euclidean distance to a configurable threshold (default 0.5). PHP calls it; Flutter never supplies a trusted embedding or verification boolean. Both registration and attendance require exactly one detected face. Changing the embedding model requires re-enrollment; do not compare vectors from different models.

Install in a separate Python virtual environment, preferably Linux/WSL because dlib's Windows build needs native compilation tools. No dependencies or model runtime have been installed by this refactor.

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export TIMEGUARD_FACE_SERVICE_KEY='<random-secret-at-least-32-characters>'
python server.py
```

The service binds **127.0.0.1:8091**. For PHP running on Windows and the service in WSL, verify Windows-to-WSL localhost forwarding or set the PHP face_service_url to an explicitly reachable private address. Do not expose this development HTTP server publicly; deploy behind authenticated TLS/service networking for other hosts. Use the same key in PHP `config/integrations.local.php`. The key is never included in Flutter.

Contract (JSON with `Authorization: Bearer <shared key>`):

- `POST /encode`: `{image_base64}` → `{encoding: [128 finite numbers]}`
- `POST /verify`: `{image_base64, reference_encoding: [128 numbers]}` → `{verified: boolean}`
- 401: invalid service key; 422: invalid image/reference or face count; unavailable service causes PHP to fail closed (503).

Images: JPEG/PNG, at most 4 MB, each dimension 80–4096 pixels. PHP stores the original validated image in protected storage and the encoding in face_biometrics. Registration approval is entirely separate and requires HR.

**Limitations:** this implementation is face similarity, not liveness/PAD. admins photograph or replay may pass. Camera-only selection in Flutter does not prove a live person to the server. Before real deployment evaluate false accept/reject rates with consented representative data, add a validated liveness mechanism, and set retention/access policies. No claim of production biometric accuracy is made.

The API integration suite uses `backend/tests/face_stub.php` with synthetic PNGs. That stub is outside the deployable PHP API and is never a production fallback. It tests contracts, authorization and failure handling; it does not test this recognition model.

Primary implementation reference: [face_recognition](https://github.com/ageitgey/face_recognition).
