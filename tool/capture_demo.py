"""Capture a fictional clinic walkthrough from a built demo; needs ChromeDriver, Chromium, ImageMagick and ffmpeg."""
import argparse
import atexit
import base64
import functools
import http.server
import socket
import subprocess
import threading
import json
import time
import urllib.request
from pathlib import Path
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--build-directory', type=Path, default=Path('build/web'))
parser.add_argument('--output', type=Path, default=Path('/tmp/mediflow-showcase'))
parser.add_argument('--screenshots', type=Path, default=Path('docs/media'))
parser.add_argument('--chrome', default='/usr/bin/chromium')
args = parser.parse_args()
if not (args.build_directory / 'main.dart.js').is_file():
    parser.error('Build the default demo with flutter build web --release first.')

def request(path, data=None, method=None):
    req = urllib.request.Request(BASE + path, data=None if data is None else json.dumps(data).encode(), headers={'Content-Type': 'application/json'}, method=method)
    with urllib.request.urlopen(req, timeout=40) as response:
        return json.load(response)['value']
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(args.build_directory.resolve()))
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
demo_url = f'http://127.0.0.1:{server.server_port}/#/login'
driver_log = open('/tmp/mediflow-capture-driver.log', 'w')
with socket.socket() as probe:
    probe.bind(('127.0.0.1', 0))
    driver_port = probe.getsockname()[1]
driver = subprocess.Popen(['chromedriver', f'--port={driver_port}'], stdout=driver_log, stderr=subprocess.STDOUT)
atexit.register(driver.terminate)
BASE = f'http://127.0.0.1:{driver_port}'
for attempt in range(50):
    if driver.poll() is not None:
        raise RuntimeError('ChromeDriver exited before startup; see its log.')
    try:
        request('/status')
        break
    except Exception:
        time.sleep(0.1)
caps = {'browserName': 'chrome', 'goog:chromeOptions': {'binary': args.chrome, 'args': ['--headless', '--no-sandbox', '--disable-dev-shm-usage', '--window-size=1280,960']}, 'goog:loggingPrefs': {'browser': 'ALL', 'performance': 'ALL'}}
sid = request('/session', {'capabilities': {'alwaysMatch': caps}})['sessionId']
p = '/session/' + sid
request(p + '/goog/cdp/execute', {'cmd': 'Emulation.setDeviceMetricsOverride', 'params': {'width': 432, 'height': 768, 'deviceScaleFactor': 2.5, 'mobile': True}})
request(p + '/goog/cdp/execute', {'cmd': 'Network.enable', 'params': {}})
request(p + '/goog/cdp/execute', {'cmd': 'Network.setBlockedURLs', 'params': {'urls': ['*fonts.googleapis.com*', '*fonts.gstatic.com*', '*gstatic.com/flutter-canvaskit*', '*firebase*', '*googleapis.com*']}})
out = args.output
out.mkdir(parents=True, exist_ok=True)
frames = out / 'frames'
frames.mkdir(exist_ok=True)
media = args.screenshots
media.mkdir(parents=True, exist_ok=True)
lock = threading.Lock()
stop = threading.Event()
errors = []
samples = []
chapters = []

def call(endpoint, data=None):
    with lock:
        return request(p + endpoint, data)

def js(script, args=()):
    return call('/execute/sync', {'script': script, 'args': args})

def capture():
    try:
        while not stop.is_set():
            at = time.monotonic()
            data = call('/screenshot')
            name = f'{len(samples):05}.png'
            (frames / name).write_bytes(base64.b64decode(data))
            samples.append((name, at))
            stop.wait(0.2)
    except Exception as e:
        errors.append(str(e))
        stop.set()

def click(text):
    script = "const q=[...document.querySelectorAll('[role=button],[role=tab],[role=checkbox]')];\n const e=q.find(e=>e.textContent===arguments[0]||e.getAttribute('aria-label')===arguments[0]);\n if(!e) throw Error('Missing '+arguments[0]); e.click(); return true;"
    js(script, [text])
    time.sleep(0.6)

def shot(name):
    data = base64.b64decode(call('/screenshot'))
    (out / (name + '.png')).write_bytes(data)
    subprocess.run(['magick', str(out / (name + '.png')), '-resize', '432x768', str(media / (name + '.png'))], check=True)

def chapter(label, seconds=4):
    chapters.append({'seconds': round(time.monotonic() - began, 2), 'label': label})
    print(label, flush=True)
    time.sleep(seconds)
call('/url', {'url': demo_url})
call('/refresh', {})
time.sleep(4)
js("document.querySelector('flt-semantics-placeholder')?.click();")
time.sleep(0.5)
if 'Demo role' not in js("return document.querySelector('flt-semantics-host').textContent;"):
    raise RuntimeError('Capture requires the fictional demo, not a connected clinic.')
began = time.monotonic()
thread = threading.Thread(target=capture)
thread.start()
try:
    chapter('Explore the fictional clinic', 3)
    click('Sign In')
    chapter('Patient overview')
    shot('patient')
    click('Doctors')
    chapter('Doctor directory')
    shot('doctors')
    js("Array.from(document.querySelectorAll('[role=button]')).find(e=>e.textContent.startsWith('Dr. Ahmed Hassan')).click();")
    time.sleep(0.6)
    js("Array.from(document.querySelectorAll('[role=button]')).find(e=>/^[A-Z][a-z]{2}\\n[0-9]+\\n/.test(e.textContent)).click();")
    time.sleep(0.6)
    click('09:00 AM')
    chapter('Choose an available half-hour visit')
    shot('booking')
    click('Confirm Booking')
    chapter('Reservation appears in appointments')
    shot('appointments')
    click('Profile')
    time.sleep(0.3)
    click('Logout')
    time.sleep(0.3)
    click('Doctor')
    click('Sign In')
    chapter('Doctor overview')
    shot('doctor')
    click('Schedule')
    chapter('Schedule follows the new reservation')
    shot('schedule')
    click('Profile')
    time.sleep(0.3)
    click('Logout')
    time.sleep(0.3)
    click('Admin')
    click('Sign In')
    chapter('Clinic administration')
    shot('admin')
    call('/actions', {'actions': [{'type': 'wheel', 'id': 'wheel', 'actions': [{'type': 'scroll', 'x': 216, 'y': 420, 'deltaX': 0, 'deltaY': 490, 'duration': 900, 'origin': 'viewport'}]}]})
    chapter('Analytics from clinic records')
    shot('analytics')
    click('Doctors')
    chapter('Manage doctor profiles')
    shot('management')
    click('Billing')
    chapter('Consultation invoice records')
    shot('billing')
    chapter('Three roles, one clinic workflow', 3)
finally:
    stop.set()
    thread.join()
    if len(samples) > 1:
        lines = []
        for i, (name, at) in enumerate(samples):
            lines.append("file 'frames/" + name + "'")
            duration = samples[i + 1][1] - at if i + 1 < len(samples) else 0.25
            lines.append(f'duration {duration:.6f}')
        lines.append("file 'frames/" + samples[-1][0] + "'")
        (out / 'capture.txt').write_text('\n'.join(lines) + '\n')
        (out / 'chapters.json').write_text(json.dumps(chapters, indent=2) + '\n')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(out / 'capture.txt'), '-vf', 'scale=720:1280,fps=24', '-c:v', 'libx264', '-crf', '20', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(out / 'mediflow-demo.mp4')], check=True)
    if errors:
        raise RuntimeError(errors)
    logs = call('/log', {'type': 'browser'})
    failures = [v for v in logs if v['level'] == 'SEVERE']
    performance = call('/log', {'type': 'performance'})
    external = []
    for entry in performance:
        event = json.loads(entry['message'])['message']
        if event['method'] == 'Network.requestWillBeSent':
            url = event['params']['request']['url']
            if url.startswith('http') and (not url.startswith(f'http://127.0.0.1:{server.server_port}/')):
                external.append(url)
    (out / 'browser-evidence.json').write_text(json.dumps({'severeErrors': failures, 'externalRequests': external}, indent=2) + '\n')
    if failures or external:
        raise RuntimeError('Browser capture found errors or external requests; inspect browser-evidence.json.')
    request(p, method='DELETE')
    server.shutdown()
    print('Recording saved', len(samples), 'frames', flush=True)
