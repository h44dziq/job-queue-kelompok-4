#!/bin/bash

JUMLAH="${1:-5}"

if [[ ! "$JUMLAH" =~ ^[0-9]+$ ]] || [ "$JUMLAH" -lt 1 ] || [ "$JUMLAH" -gt 60 ]; then
    echo "Pemakaian: $0 [jumlah_sampel 1-60]" >&2
    exit 2
fi

for ((i = 1; i <= JUMLAH; i++)); do
    echo "== $(date '+%H:%M:%S') =="
    ps -eo pid,ppid,user,stat,%cpu,%mem,rss,etime,args | awk 'NR == 1 || $10 ~ /\/jobs\/job_/'
    sleep 1
done
exit 0
