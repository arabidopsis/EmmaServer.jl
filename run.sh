#!/bin/bash
julia --startup-file=no --project=. --threads=8 \
    srvr.jl --workers=2 --port=9998 --console -x \
    --sleep=.1 \
    --watch=/home/ianc/github/emma-website/instance/datadir
