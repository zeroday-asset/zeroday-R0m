#!/bin/bash
set -euo pipefail
mark() { echo "PASS: $*"; }
uname -a
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
docker run --rm --memory 64m --pids-limit 64 busybox:1.36 sh -c 'test -r /proc/self/status'
mark 'Docker container with memory and PID limits'
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
docker run --rm busybox:1.36 nslookup example.com
docker run --rm busybox:1.36 wget -qO /dev/null http://example.com
mark 'nested container DNS and outbound HTTP'
docker rm -f fixture-web
docker volume rm fixture-data
mark 'Docker resources cleaned up'
