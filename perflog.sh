#!/bin/bash
# Logs system stats every 5s to perflog.csv
# Usage: ./perflog.sh [network_interface]
# Find your interface with: ip -br link

IFACE="${1:-wlan0}"
OUT="perflog.csv"

echo "timestamp,cpu_temp_C,cpu_freq_MHz,cpu_pct,mem_pct,rx_KBps,tx_KBps,load1" > "$OUT"

prev_rx=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
prev_tx=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)

while true; do
  sleep 5
  ts=$(date '+%Y-%m-%d %H:%M:%S')

  # Temp: highest thermal zone reading in °C
  temp=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
  temp=$(awk "BEGIN {printf \"%.1f\", $temp/1000}")

  # Average CPU frequency across cores
  freq=$(awk '/MHz/ {s+=$4; n++} END {if(n>0) printf "%.0f", s/n}' /proc/cpuinfo)

  # CPU% (1s sample) and mem%
  cpu=$(top -bn2 -d 0.5 | grep "Cpu(s)" | tail -1 | awk '{print 100 - $8}')
  mem=$(free | awk '/Mem:/ {printf "%.1f", $3/$2*100}')

  # Network throughput in KB/s
  rx=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
  tx=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
  rx_kbps=$(awk "BEGIN {printf \"%.1f\", ($rx-$prev_rx)/1024/5}")
  tx_kbps=$(awk "BEGIN {printf \"%.1f\", ($tx-$prev_tx)/1024/5}")
  prev_rx=$rx
  prev_tx=$tx

  load=$(awk '{print $1}' /proc/loadavg)

  echo "$ts,$temp,$freq,$cpu,$mem,$rx_kbps,$tx_kbps,$load" | tee -a "$OUT"
done
