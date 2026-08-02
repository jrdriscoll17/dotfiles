#!/usr/bin/env bash
# Wake all DDC/CI monitors powered off by monitors-off.sh (VCP D6=01).
# Sequential to avoid ddcutil i2c flock contention. See monitors-off.sh.

set -u

ON=01
DISPLAYS="1 2 3"

for d in $DISPLAYS; do
    for i in 1 2 3; do
        ddcutil -d "$d" --noverify setvcp D6 "$ON" 2>/dev/null && break
        sleep 0.3
    done
done
