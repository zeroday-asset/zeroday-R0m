#!/usr/bin/env python3
"""Inspect the compiled image, including explicit TWRP Data controls."""
import gzip
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
def unpack(data):
    if data.startswith(b'\x1f\x8b'):
        return gzip.decompress(data)
    if data[:4] in (b'\x04\x22\x4d\x18', b'\x02\x21\x4c\x18'):
        return subprocess.run(['lz4', '-d', '-c'], input=data,
                              stdout=subprocess.PIPE, check=True).stdout
    if data.startswith(b'07070'):
        return data
    raise ValueError(f'Unknown compression: {data[:8].hex()}')

def cpio(data):
    files = {}
    pos = 0
    while pos + 110 <= len(data):
        header = data[pos:pos + 110]
        if header[:6] not in (b'070701', b'070702'):
            raise ValueError(f'Invalid cpio header at {pos}')
        fields = [int(header[6 + i * 8:14 + i * 8], 16) for i in range(13)]
        size, name_size = fields[6], fields[11]
        if name_size < 1 or pos + 110 + name_size > len(data):
            raise ValueError('Invalid cpio name')
        name = data[pos + 110:pos + 110 + name_size - 1].decode()
        pos = (pos + 110 + name_size + 3) & ~3
        if name == 'TRAILER!!!':
            return files
        if pos + size > len(data):
            raise ValueError('Truncated cpio member')
        files[name.removeprefix('./')] = data[pos:pos + size]
        pos = (pos + size + 3) & ~3
    raise ValueError('Missing cpio trailer')


image = Path(sys.argv[1])
kernel = Path(sys.argv[2]).read_bytes()
recovery = image.read_bytes()
assert recovery.startswith(b'ANDROID!')
assert len(recovery) <= 69009408, 'Recovery exceeds c2s partition'
kernel_size, = struct.unpack_from('<I', recovery, 8)
ramdisk_size, = struct.unpack_from('<I', recovery, 16)
page_size, = struct.unpack_from('<I', recovery, 36)
assert page_size in (2048, 4096, 8192, 16384)
assert recovery[page_size:page_size + kernel_size] == kernel, 'Image uses a different kernel'
offset = page_size + ((kernel_size + page_size - 1) // page_size) * page_size
files = cpio(unpack(recovery[offset:offset + ramdisk_size]))
recovery_bins = [v for k, v in files.items() if k in ('sbin/recovery', 'system/bin/recovery')]
assert recovery_bins and any(b'twrp' in b.lower() for b in recovery_bins)
assert any(len(b) > 20 and b[:4] == b'\x7fELF' and struct.unpack_from('<H', b, 18)[0] == 183 for b in recovery_bins), 'Recovery is not an ARM64 ELF'
flags = [v.decode() for k,v in files.items() if k.endswith('twrp.flags')]
assert len(flags) == 1
lines = [l.split() for l in flags[0].splitlines() if l.strip() and not l.startswith('#')]
data = [l for l in lines if l[0] == '/data']
assert len(data) == 1 and data[0][1:3] == ['f2fs', '/dev/block/by-name/userdata']
assert 'display="Data"' in ' '.join(data[0]) and 'wipeingui' in ' '.join(data[0])
assert any(l[0] == '/metadata' for l in lines)
post = [v for k,v in files.items() if k.endswith('/postrecoveryboot.sh')]
assert len(post) == 1 and b'exit 0' in post[0] and b'dd ' not in post[0]
props = '\n'.join(v.decode(errors='replace') for k,v in files.items() if k.endswith('.prop') or k.endswith('prop.default'))
assert 'c2s' in props
report = {'image': image.name, 'bytes': len(recovery), 'sha256': hashlib.sha256(recovery).hexdigest(),
          'kernel_matches_source_build': True, 'explicit_userdata_control': data[0],
          'no_automatic_boot_rewrite': True, 'ramdisk_files': len(files),
          'fstabs': {k:v.decode(errors='replace') for k,v in files.items() if 'fstab' in k or k.endswith('twrp.flags')},
          'validation': 'Offline inspection only; no physical phone boot, mount, format or decryption test.'}
Path(sys.argv[3]).write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
