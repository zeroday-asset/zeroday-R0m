#!/usr/bin/env python3
"""Inspect the unchanged, pinned Artisan c2s Odin recovery package."""
import gzip
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tarfile

package = Path(sys.argv[1])
report_path = Path(sys.argv[2])

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

with tarfile.open(package, 'r:*') as archive:
    members = {m.name: m for m in archive.getmembers() if m.isfile()}
    allowed = {'recovery.img', 'recovery.img.lz4', 'vbmeta.img', 'vbmeta.img.lz4'}
    if not set(members) <= allowed:
        raise ValueError(f'Unexpected Odin payload: {list(members)}')
    def image(name):
        key = name if name in members else name + '.lz4'
        data = archive.extractfile(members[key]).read()
        if key.endswith('.lz4'):
            data = unpack(data)
        return data
    recovery, vbmeta = image('recovery.img'), image('vbmeta.img')

assert recovery.startswith(b'ANDROID!'), 'Invalid recovery boot header'
assert len(recovery) <= 69009408, 'Recovery exceeds previously measured stock image size'
kernel_size, = struct.unpack_from('<I', recovery, 8)
ramdisk_size, = struct.unpack_from('<I', recovery, 16)
page_size, = struct.unpack_from('<I', recovery, 36)
assert page_size in (2048, 4096, 8192, 16384, 65536)
offset = page_size + ((kernel_size + page_size - 1) // page_size) * page_size
assert ramdisk_size > 0 and offset + ramdisk_size <= len(recovery)
files = cpio(unpack(recovery[offset:offset + ramdisk_size]))
recovery_bins = [v for k, v in files.items() if k in ('sbin/recovery', 'system/bin/recovery')]
assert recovery_bins and any(b'twrp' in blob.lower() for blob in recovery_bins), 'Not a TWRP ramdisk'
props = '\n'.join(v.decode(errors='replace') for k, v in files.items()
                  if k.endswith('.prop') or k.endswith('prop.default'))
assert 'c2s' in props or 'SM-N986B' in props, 'Recovery device identity is not c2s/N986B'
fstabs = {k: v.decode(errors='replace') for k, v in files.items() if 'fstab' in k}
print('Recovery filesystem tables:', json.dumps(fstabs, indent=2), flush=True)
# Mount entries can be split between Android and TWRP tables. Samsung's block
# partition names may be uppercase even when the recovery mountpoint is not.
all_fstabs = '\n'.join(fstabs.values()).lower()
assert '/data' in all_fstabs and '/boot' in all_fstabs, 'Missing expected recovery mount entries'
assert vbmeta.startswith(b'AVB0'), 'Invalid vbmeta header'
flags, = struct.unpack_from('>I', vbmeta, 120)
assert flags & 2, 'Odin package does not disable AVB verification'
report = {
    'publisher_package': package.name,
    'members': list(members),
    'recovery_bytes': len(recovery),
    'recovery_sha256': hashlib.sha256(recovery).hexdigest(),
    'ramdisk_files': len(files),
    'device_and_twrp_properties': [l for l in props.splitlines()
                                  if any(x in l for x in ('ro.product.', 'ro.twrp.', 'ro.build.display.id'))],
    'fstabs': fstabs,
    'vbmeta_bytes': len(vbmeta),
    'vbmeta_flags': flags,
    'validation': 'Offline structure/device checks; not boot-tested on the phone.'
}
report_path.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
