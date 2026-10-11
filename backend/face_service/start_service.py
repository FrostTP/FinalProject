"""Load the shared key from deployed PHP settings without printing or duplicating it."""
import json
import os
from pathlib import Path
import runpy
import subprocess

root = Path(__file__).resolve().parent
php = Path(os.environ.get('TIMEGUARD_PHP_EXE', r'C:\xampp\php\php.exe'))
config = Path(os.environ.get('TIMEGUARD_INTEGRATIONS_FILE', r'C:\xampp\htdocs\timeguard_api\config\integrations.php'))
settings = json.loads(subprocess.check_output(
    [str(php), '-r', 'echo json_encode(require $argv[1]);', str(config)],
    creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0),
))
key = settings.get('face_service_key', '')
if len(key) < 32:
    raise RuntimeError('Configure face_service_key in PHP integrations.local.php first')
os.environ['TIMEGUARD_FACE_SERVICE_KEY'] = key
os.environ['TIMEGUARD_FACE_PORT'] = '8091'
print('TimeGuard face service: http://127.0.0.1:8091', flush=True)
runpy.run_path(str(root / 'server.py'), run_name='__main__')
