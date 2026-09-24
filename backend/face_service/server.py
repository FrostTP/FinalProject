"""Private CPU face-embedding service. Deploy separately from PHP, normally on Linux.
No liveness/PAD is implemented: a matching photograph may pass.
Embeddings are face_recognition/dlib 128-dimensional vectors; do not mix model versions.
"""
import base64
import hmac
import io
import json
import math
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

import face_recognition
import numpy as np
from PIL import Image

KEY = os.environ.get('TIMEGUARD_FACE_SERVICE_KEY', '')
THRESHOLD = float(os.environ.get('TIMEGUARD_FACE_THRESHOLD', '0.5'))
if len(KEY) < 32:
    raise RuntimeError('Set TIMEGUARD_FACE_SERVICE_KEY (32+ characters)')
if not 0 < THRESHOLD <= 0.6:
    raise RuntimeError('Threshold must be greater than 0 and no more than 0.6')
Image.MAX_IMAGE_PIXELS = 4096 * 4096


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, payload):
        content = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_POST(self):
        if not hmac.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + KEY):
            self.reply(401, {'error': 'unauthorized'})
            return
        if self.path not in ('/encode', '/verify'):
            self.reply(404, {'error': 'not found'})
            return
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 6000000:
                raise ValueError('request size')
            body = json.loads(self.rfile.read(length))
            raw = base64.b64decode(body['image_base64'], validate=True)
            if len(raw) > 4194304:
                raise ValueError('image size')
            image = Image.open(io.BytesIO(raw))
            if image.format not in ('JPEG', 'PNG') or min(image.size) < 80 or max(image.size) > 4096:
                raise ValueError('image format or dimensions')
            rgb = np.asarray(image.convert('RGB'))
            locations = face_recognition.face_locations(rgb, model='hog')
            if len(locations) != 1:
                raise ValueError('exactly one face required')
            vector = face_recognition.face_encodings(rgb, known_face_locations=locations)[0]
            if self.path == '/encode':
                self.reply(200, {'encoding': vector.tolist()})
            else:
                reference = body['reference_encoding']
                if not isinstance(reference, list) or len(reference) != 128 or not all(isinstance(v, (int, float)) and math.isfinite(v) for v in reference):
                    raise ValueError('invalid reference')
                distance = float(np.linalg.norm(vector - np.asarray(reference)))
                self.reply(200, {'verified': distance <= THRESHOLD})
        except (ValueError, KeyError, TypeError, IndexError, OSError, Image.DecompressionBombError):
            self.reply(422, {'error': 'invalid image, face count, or reference'})

    def log_message(self, fmt, *args):
        pass  # Never log request bodies, images, or encodings.


if __name__ == '__main__':
    HTTPServer(('127.0.0.1', int(os.environ.get('TIMEGUARD_FACE_PORT', '8091'))), Handler).serve_forever()
