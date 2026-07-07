#!/bin/bash
exec julia --startup-file=no --project=. --threads=4 \
    srvr.jl --console --level=info --workers=4 \
    --sleep-hours=1 --watch=~/github/emma-website/instance/datadir
