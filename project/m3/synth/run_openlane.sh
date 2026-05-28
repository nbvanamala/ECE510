#!/bin/bash
PROJECT=/mnt/c/Users/navee/ECE510/project
PDK_DIR=$HOME/.volare
LOG="${PROJECT}/m3/synth/openlane_run.log"

docker run --rm \
  -v "${PROJECT}:${PROJECT}" \
  -v "${PDK_DIR}:/root/.volare" \
  ghcr.io/efabless/openlane2:2.3.10 \
  python3 -m openlane \
    --pdk sky130A \
    --pdk-root /root/.volare \
    "${PROJECT}/m3/synth/config.json" 2>&1 | tee "$LOG"

echo "OpenLane exit: $?"
