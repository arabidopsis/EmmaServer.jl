#!/bin/bash
workers=4
use_threads="--use-threads"
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -w, --workers <number>    Set the number of workers [default: $workers]"
    echo "  -d, --use-distributed     Use Julia's Distributed.jl workers [default: use threads as workers]"
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
        -d|--use-distributed)
            unset use_threads
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

exec julia  --project=. --startup-file=no --threads=$workers \
     -m EmmaServer --tee --level=info --workers=$workers $use_threads
