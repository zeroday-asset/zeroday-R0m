#!/bin/sh
# A small PID 1 for a controlled container fixture; no host network manager.
trap 'exit 0' TERM INT
while :; do sleep 60 & wait "$!"; done
