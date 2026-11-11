#!/bin/bash
set -euo pipefail
name=c2s-docker-fixture
results=$(realpath runtime-results)
root=$(realpath .runtime)
cleanup() {
    status=$?
    trap - EXIT
    droidspaces --name="$name" run cat /fixture/dockerd.log > "$results/dockerd.log" 2>&1 || true
    droidspaces --name="$name" run cat /fixture/docker-info.txt > "$results/docker-info.txt" 2>&1 || true
    droidspaces --name="$name" info > "$results/container-info.txt" 2>&1 || true
    timeout 45 droidspaces --name="$name" stop > "$results/stop.log" 2>&1 || true
    if [ "$status" -eq 0 ]; then
        echo 'PASS: Linux Droidspaces/Docker integration' > "$results/result.txt"
    else
        echo "FAIL: Linux Droidspaces/Docker integration, exit $status" > "$results/result.txt"
    fi
    echo 'SUSFS/Android/N986B runtime: NOT TESTED' >> "$results/result.txt"
    exit "$status"
}
trap cleanup EXIT
droidspaces check | tee "$results/check.txt"
timeout 120 droidspaces --name="$name" --rootfs-img="$root/rootfs.img" \
    --init=/sbin/fixture-init --net=nat --dns="$(cat "$root/dns-server")" \
    --memory=2G --cpus=2 --pids-limit=1024 --allow-sandboxing start
timeout 300 droidspaces --name="$name" run /fixture/guest-docker.sh
# A clean stop and another boot must also work on the same persistent image.
timeout 45 droidspaces --name="$name" stop
timeout 120 droidspaces --name="$name" start
timeout 300 droidspaces --name="$name" run /fixture/guest-docker.sh
echo 'PASS: repeated stop/start and Docker workloads'
