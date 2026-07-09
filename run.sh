#!/bin/bash
workers=8
use_threads='--use-threads'
exec julia --startup-file=no --project=. --threads=$workers \
    srvr.jl --console --tee --level=info --workers=$workers $use_threads \
    --sleep-hours=1 --watch=~/github/emma-website/instance/datadir
