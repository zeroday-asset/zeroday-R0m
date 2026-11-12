#!/usr/bin/env python3
"""Apply explicit c2s recovery settings to the pinned ExtremeXT tree."""
from pathlib import Path
import sys

tree = Path(sys.argv[1])
board = tree / 'BoardConfig.mk'
text = board.read_text()
assert 'TW_DEVICE_VERSION := ExtremeXT_v4' in text
text = text.replace('TW_DEVICE_VERSION := ExtremeXT_v4', 'TW_DEVICE_VERSION := N986B-source-r1')
# This affects the recovery kernel only. The ROM keeps its enforcing policy.
text = text.replace('loop.max_part=7', 'loop.max_part=7 androidboot.selinux=permissive')
board.write_text(text)

flags = tree / 'recovery/root/system/etc/twrp.flags'
text = flags.read_text()
assert not any(line.split()[:1] == ['/data'] for line in text.splitlines())
text += '\n# Explicit TWRP controls for the actual c2s userdata and metadata partitions.\n'
text += '/data f2fs /dev/block/by-name/userdata flags=display="Data";backup=1;wipeingui;wipeduringfactoryreset;length=-20480\n'
text += '/metadata ext4 /dev/block/by-name/metadata flags=display="Metadata";backup=1\n'
flags.write_text(text)

# No automatic stock-boot repacking or writes to any boot partition.
script = tree / 'recovery/root/system/bin/postrecoveryboot.sh'
assert 'dd if=' in script.read_text()
script.write_text('#!/sbin/sh\n# Recovery must not modify the installed boot image.\nexit 0\n')

# Assert correct target geometry, rather than substituting a different model.
c2s = (tree / 'c2s/BoardConfig.mk').read_text()
assert 'BOARD_RECOVERYIMAGE_PARTITION_SIZE := 69009408' in c2s
assert 'BOARD_SUPER_PARTITION_SIZE := 10276044800' in c2s
assert 'BOARD_BOOTIMAGE_PARTITION_SIZE := 61865984' in c2s
print('Explicit userdata/metadata controls and no automatic boot modification: applied')
