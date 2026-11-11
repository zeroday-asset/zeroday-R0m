#!/bin/bash
set -euo pipefail
name=c2s-docker-fixture
results=$(realpath runtime-results)
root=$(realpath .runtime)
cleanup() {
    status=$?
    trap - EXIT
    if [ -d "/mnt/Droidspaces/$name/fixture" ]; then
        cp "/mnt/Droidspaces/$name/fixture/"*.log "$results/" 2>/dev/null || true
        cat "/mnt/Droidspaces/$name/fixture/init.log" 2>/dev/null || true
    fi
    droidspaces --name="$name" run cat /fixture/dockerd.log > "$results/dockerd.log" 2>&1 || true
    droidspaces --name="$name" run cat /fixture/init.log > "$results/init.log" 2>&1 || true
    droidspaces --name="$name" run cat /fixture/docker-info.txt > "$results/docker-info.txt" 2>&1 || true
    droidspaces --name="$name" run journalctl -u docker.service --no-pager > "$results/docker-journal.txt" 2>&1 || true
    droidspaces --name="$name" info > "$results/container-info.txt" 2>&1 || true
    timeout 45 droidspaces --name="$name" stop > "$results/stop.log" 2>&1 || true
    mkdir -p "$root/readback"
    if mount -o loop,ro "$root/rootfs.img" "$root/readback"; then
        cp "$root/readback"/fixture/*.log "$results/" 2>/dev/null || true
        cat "$root/readback/fixture/init.log" 2>/dev/null || true
        umount "$root/readback"
    fi
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
    --init=/sbin/init --net=nat --dns="$(cat "$root/dns-server")" \
    --memory=2G --cpus=2 --pids-limit=1024 --allow-sandboxing start
# The runner already runs Docker with nftables, while this Droidspaces backend
# manages legacy iptables directly. Permit only the test's ds-prefixed links
# through the independent nft filter as well; retain the existing host policy.
iptables-nft -I FORWARD 1 -i ds+ -j ACCEPT
iptables-nft -I FORWARD 1 -o ds+ -j ACCEPT
iptables-nft -S FORWARD
for attempt in $(seq 1 100); do
    if [ -f "/mnt/Droidspaces/$name/fixture/init-ready" ]; then break; fi
    sleep 0.1
done
echo 'Host view of processes blocking root delegation:'
cat "/sys/fs/cgroup/droidspaces/$name/cgroup.procs"
while read -r task_pid; do
    ps -p "$task_pid" -o pid,ppid,comm,args
done < "/sys/fs/cgroup/droidspaces/$name/cgroup.procs"
echo 'Host view of session leaf:'
cat "/sys/fs/cgroup/droidspaces/$name/ds-enter/cgroup.procs" || true
timeout 300 droidspaces --name="$name" run /fixture/guest-docker.sh
# A clean stop and another boot must also work on the same persistent image.
timeout 45 droidspaces --name="$name" stop
timeout 120 droidspaces --name="$name" start
timeout 300 droidspaces --name="$name" run /fixture/guest-docker.sh
echo 'PASS: repeated stop/start and Docker workloads'
