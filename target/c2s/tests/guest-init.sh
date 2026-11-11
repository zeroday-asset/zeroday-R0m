#!/bin/sh
exec >> /fixture/init.log 2>&1
set -ex
# A small PID 1 for a controlled container fixture; no host network manager.
# Delegate cgroup-v2 controllers as systemd normally does. A bare sleep PID 1
# leaves processes in the cgroup root and prevents child controller delegation.
if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    mkdir -p /sys/fs/cgroup/init.scope
    echo "$$" > /sys/fs/cgroup/init.scope/cgroup.procs
    echo '+cpu +memory +pids' > /sys/fs/cgroup/cgroup.subtree_control
fi
touch /fixture/init-ready
trap 'exit 0' TERM INT
while :; do sleep 60 & wait "$!"; done
