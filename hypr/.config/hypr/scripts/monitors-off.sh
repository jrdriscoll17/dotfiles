#!/usr/bin/env bash
# Blank all DDC/CI monitors via VCP D6 (power mode) as a fallback for the
# broken `dpms off` (aquamarine bug: screens never blank on lock).
#
# D6=02 -> DPMS Standby: panel goes fully dark but the monitor's DDC/i2c
# controller stays awake, so monitors-on.sh (D6=01) can wake it. Confirmed
# blank+wake on the AW3225QF OLEDs (2026-07-20).
#
# Do NOT use D6=04 (DPMS Off): on these panels it puts the DDC controller too
# deep to receive the D6=01 wake, leaving the monitors stranded in standby
# until a manual power cycle. That was the long-standing wake regression.
#
# Runs sequentially (not parallel) to avoid ddcutil i2c flock contention.
# Display numbers are hardcoded — this rig is a stable 3x AW3225QF setup;
# skipping `ddcutil detect` also avoids its slow full-bus probe.

set -u

OFF=02
DISPLAYS="1 2 3"

for d in $DISPLAYS; do
    for i in 1 2 3; do
        ddcutil -d "$d" --noverify setvcp D6 "$OFF" 2>/dev/null && break
        sleep 0.3
    done
done
