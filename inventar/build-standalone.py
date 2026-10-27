# Erzeugt Inventar.html: eine einzelne Datei ohne Abhängigkeiten (Icon eingebettet,
# kein Manifest/Service Worker), die man per Doppelklick im Browser öffnen kann.
# Aufruf: python3 build-standalone.py
import base64, pathlib

here = pathlib.Path(__file__).parent
html = (here / 'index.html').read_text(encoding='utf-8')
icon = 'data:image/png;base64,' + base64.b64encode((here / 'icon-180.png').read_bytes()).decode()

html = html.replace('<link rel="manifest" href="manifest.webmanifest">\n', '')
html = html.replace('icon-180.png', icon)
(here / 'Inventar.html').write_text(html, encoding='utf-8')
print('Inventar.html erzeugt')
