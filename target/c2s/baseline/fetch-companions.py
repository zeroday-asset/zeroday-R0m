#!/usr/bin/env python3
"""Fetch immutable, checksum-pinned companion packages on the Actions runner."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

output = Path(sys.argv[1]).resolve()
manifest = json.loads((Path(__file__).parent / 'companions.json').read_text())
for item in manifest:
    target = output / item['name']
    target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error',
                    '--retry', '3', '--max-time', '300', item['url'], '-o', str(target)], check=True)
    actual = hashlib.file_digest(target.open('rb'), 'sha256').hexdigest()
    if actual != item['sha256']:
        raise SystemExit(f"Checksum mismatch for {target.name}: {actual}")
    if target.suffix in ('.zip', '.apk'):
        with zipfile.ZipFile(target) as archive:
            if archive.testzip() is not None:
                raise SystemExit(f'Corrupt ZIP/APK: {target.name}')
    print(f'Verified companion: {target.name}', flush=True)
(output / 'companion-sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
