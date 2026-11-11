#!/bin/bash
set -euo pipefail
mark() { echo "PASS: $*"; }
for attempt in $(seq 1 100); do
    if [ -f /fixture/init-ready ]; then break; fi
    sleep 0.1
done
systemctl --no-pager --failed || true
systemctl is-system-running || true
test -f /fixture/init-ready
uname -a
cat /sys/fs/cgroup/cgroup.controllers
cat /sys/fs/cgroup/cgroup.subtree_control
test "$(readlink /proc/1/ns/pid)" = "$(readlink /proc/self/ns/pid)"
mark 'container processes see their own PID namespace'
unshare --user --map-root-user --mount --pid --fork --mount-proc \
    sh -c 'test "$$" -eq 1 && test -r /proc/self/mountinfo'
mark 'nested user, mount and PID namespaces; new procfs'
python3 - <<'PY'
import os
mounts={line.split()[0] for line in open('/proc/self/mountinfo')}
fd=os.open('/etc/os-release',os.O_RDONLY)
info=dict(line.rstrip().split(':',1) for line in open('/proc/self/fdinfo/'+str(fd)))
assert info['mnt_id'].strip() in mounts
os.close(fd)
print('PASS: fdinfo mount ID is present in mountinfo')
PY
# The cgroupfs driver needs controllers delegated through its Docker parent
# as well as the Droidspaces root. Keep this explicit in the small init fixture.
mkdir -p /sys/fs/cgroup/docker
echo '+cpu +memory +pids' > /sys/fs/cgroup/docker/cgroup.subtree_control
cat /sys/fs/cgroup/docker/cgroup.controllers
cat /sys/fs/cgroup/docker/cgroup.subtree_control
curl --fail --max-time 20 --silent http://example.com/ > /fixture/outer-http-result
mark 'outer Droidspaces container has DNS and outbound HTTP'
nohup dockerd > /fixture/dockerd.log 2>&1 < /dev/null &
for attempt in $(seq 1 90); do
    if docker info > /fixture/docker-info.txt 2>&1; then break; fi
    sleep 1
done
docker info
mark 'Docker daemon is ready inside Droidspaces'
docker load -i /fixture/busybox-image.tar
test "$(docker run --rm busybox:1.36 echo nested-docker-ok)" = nested-docker-ok
mark 'Docker creates and runs a nested container'
docker run --rm --memory 64m --pids-limit 64 --cpus 0.5 busybox:1.36 sh -ec '
    test "$(cat /sys/fs/cgroup/memory.max)" = 67108864
    test "$(cat /sys/fs/cgroup/pids.max)" = 64
    test "$(cat /sys/fs/cgroup/cpu.max)" = "50000 100000"
'
mark 'memory, PID and CPU limits are present in the nested kernel cgroup'
docker volume create fixture-data
docker run --rm -v fixture-data:/data busybox:1.36 sh -c 'echo durable > /data/value'
test "$(docker run --rm -v fixture-data:/data busybox:1.36 cat /data/value)" = durable
mark 'Docker volume persists across containers'
docker run -d --name fixture-web -p 18080:8080 busybox:1.36 \
    sh -c 'mkdir -p /www; echo docker-http-ok >/www/index.html; exec httpd -f -p 8080 -h /www'
for attempt in $(seq 1 15); do
    if curl --fail --silent http://127.0.0.1:18080/ > /fixture/http-result; then break; fi
    sleep 1
done
grep -Fx docker-http-ok /fixture/http-result
mark 'Docker bridge networking and published port'
cat /etc/resolv.conf
docker run --rm busybox:1.36 cat /etc/resolv.conf
docker run --rm busybox:1.36 nslookup example.com
docker run --rm busybox:1.36 wget -T 20 -qO /dev/null http://example.com
mark 'nested container DNS and outbound HTTP'
docker rm -f fixture-web
docker volume rm fixture-data
rm -f /fixture/init-ready
mark 'Docker resources cleaned up'
