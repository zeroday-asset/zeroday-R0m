#!/usr/bin/env python3
"""Set the SUSFS module default required by Droidspaces."""
import sys
from zipfile import ZipFile

source_path, output_path = sys.argv[1:]
old = b"hide_sus_mnts_for_all_or_non_su_procs=1"
new = b"hide_sus_mnts_for_all_or_non_su_procs=0"
with ZipFile(source_path) as source, ZipFile(output_path, "w") as output:
    config = source.read("config.sh")
    if config.count(old) != 1:
        raise SystemExit("Unexpected SUSFS module config. Refusing to modify it.")
    for entry in source.infolist():
        content = source.read(entry)
        if entry.filename == "config.sh":
            content = content.replace(old, new)
        output.writestr(entry, content)
