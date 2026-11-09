#!/bin/bash

detik="${1:-60}"
echo "job_lama: menunggu $detik detik"
sleep "$detik"
echo "job_lama selesai"
