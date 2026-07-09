#!/bin/bash
workers=8

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -w, --workers <number>    Set the number of workers [default: $workers]"
    echo "  -t, --use-threads         Use Julia's multi-threading [default: use Distributed.jl workers]"
    echo "  -h, --help                Display this help message"
    exit 1
}

# Loop through all arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--workers)
            if [[ -n "$2" && "$2" != -* ]]; then
                workers="$2"
                shift 2
            else
                echo "Error: Argument for $1 is missing." >&2
                exit 1
            fi
            ;;
        -t|--use-threads)
            use_threads="--use-threads"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Invalid option '$1'." >&2
            usage
            ;;
    esac
done
exec julia --startup-file=no --project=. --threads=$workers \
    srvr.jl --tee --level=info --workers=$workers $use_threads
