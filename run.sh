#!/bin/bash
exec julia --startup-file=no --project=. --threads=4 \
    srvr.jl --console \
    --sleep-hours=.1 --use-threads \
    --watch=/home/ianc/github/emma-website/instance/datadir
