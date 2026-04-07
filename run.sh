#!/bin/bash
exec julia --startup-file=no --project=. --threads=4 \
    srvr.jl --console --use-threads --level=info \
    --sleep-hours=1 --watch=~/github/emma-website/instance/datadir
