#!/bin/bash
julia --startup-file=no --project=. --threads=8 \
    srvr.jl --workers=2 --port=9998 --console
