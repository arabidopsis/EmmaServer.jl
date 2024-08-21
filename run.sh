#!/bin/bash
julia --startup-file=no --project=. --threads=4 \
    srvr.jl --workers=4 --port=9998 --console -x \
    --sleep=.1 --use-threads \
    --watch=/home/ianc/github/emma-website/instance/datadir
