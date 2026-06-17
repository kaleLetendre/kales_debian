#!/bin/sh
# i3bar status wrapper: prepend average CPU core temperature to i3status.
#
# Why a wrapper: i3status' native cpu_temperature module reads a single
# hwmon input file and can't average. This averages every "Core N" sensor
# exposed by the kernel coretemp driver, then prepends it to each i3status
# line. i3status here runs in plain-text ("none") mode, so we just splice
# strings -- no JSON to parse.
#
# Wired up in ~/.config/i3/config:  bar { status_command ~/.config/i3/statusline.sh }

# Average of all per-core temps, rounded to whole degrees C. Globs the
# hwmon number (hwmonN is not stable across reboots) and selects sensors
# by their "Core N" label, so the package sensor and any non-core temps
# are excluded. Prints "?" if no core sensors are found (e.g. a machine
# without the coretemp driver) rather than dividing by zero.
core_temp_avg() {
    sum=0
    n=0
    for label in /sys/devices/platform/coretemp.*/hwmon/hwmon*/temp*_label; do
        [ -e "$label" ] || continue
        case "$(cat "$label")" in
            'Core '*)
                sum=$((sum + $(cat "${label%_label}_input")))
                n=$((n + 1))
                ;;
        esac
    done
    if [ "$n" -gt 0 ]; then
        printf '%d' "$(( (sum / n + 500) / 1000 ))"
    else
        printf '?'
    fi
}

i3status | while read -r line; do
    printf 'T: %s°C | %s\n' "$(core_temp_avg)" "$line"
done
