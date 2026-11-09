#!/bin/bash

detik="${1:-5}"
akhir=$((SECONDS + detik))
putaran=0

while [ "$SECONDS" -lt "$akhir" ]; do
    putaran=$((putaran + 1))
done

echo "job_ringan selesai: $putaran putaran dalam $detik detik"
