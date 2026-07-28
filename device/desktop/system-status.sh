#!/bin/sh
set -eu

while :; do
    read -r total_a idle_a <<EOF
$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5+$6}' /proc/stat)
EOF
    sleep 1
    read -r total_b idle_b <<EOF
$(awk '/^cpu / {print $2+$3+$4+$5+$6+$7+$8, $5+$6}' /proc/stat)
EOF
    cpu=$(awk -v t="$((total_b-total_a))" -v i="$((idle_b-idle_a))" \
        'BEGIN { if (t > 0) printf "%.0f", 100*(t-i)/t; else print 0 }')
    mem=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "%.0f", 100*(t-a)/t}' /proc/meminfo)
    temp="n/a"
    if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
        temp=$(awk '{printf "%.1fC", $1/1000}' /sys/class/thermal/thermal_zone0/temp)
    fi
    printf '\033[H\033[2J  equipo: %-12s  CPU: %3s%%  RAM: %3s%%  temp: %-7s  uptime: %s\n' \
        "$(hostname)" "$cpu" "$mem" "$temp" "$(cut -d. -f1 /proc/uptime)s"
done
