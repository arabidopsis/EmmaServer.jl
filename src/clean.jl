import Dates: unix2datetime

function clean(directories::Vector{String}, wait::Real; old=2.0, verbose=false)

    while true
        now = time()
        nerr = 0
        try
            for directory in directories
                if !isdir(directory) # might have been deleted since last check
                    @warn "not a directory: $directory"
                    continue
                end
                for (root, dirs, files) in walkdir(directory)
                    for file in files
                        f = joinpath(root, file)
                        t = mtime(f)
                        days = (now - t) / (60 * 60 * 24)
                        if days > old
                            rm(f; force=true)
                            if verbose
                                @info "removed: $f"
                            end
                        end
                    end
                end
                open(joinpath(directory, ".clean"), "w") do out
                    write(out, "$(unix2datetime(now)): $(nerr)\n")
                end
            end
        catch e
            @error "walkdir: $(e)"
            nerr += 1
        end

        sleep(wait)
    end
end

function maxsize(directories::Vector{String}, wait_days::Real; max_mb::Real=100.0, verbose=false)
    days = wait_days * 60 * 60 * 24 # convert wait days to seconds
    while true
        maxsize(directories; max_mb=max_mb, verbose=verbose)
        sleep(days)
    end
end

function maxsize(directories::Vector{String}; max_mb::Real=100.0, verbose=false)
    total = 0.0
    files = Tuple{String,Float64,Float64}[]
    for directory in directories
        if !isdir(directory) # might have been deleted since last check
            @warn "not a directory: $directory"
            continue
        end
        for (root, dirs, files) in walkdir(directory)
            for file in files
                f = joinpath(root, file)
                st = stat(f)
                size_mb = st.size / (1024 * 1024)
                total += size_mb
                push!(files, (f, size_mb, st.mtime))
            end
        end
    end
    if total < max_mb
        if verbose
            @info "total size: $(round(total, digits=2)) MB < $(max_mb) MB"
        end
        return
    end
    files = sort(files; by=x->x[3]) # sort by mtime
    nfiles = 0
    for (f, size_mb, mtime) in files
        rm(f; force=true)
        nfiles += 1
        total -= size_mb
        if total < max_mb
            if verbose
                @info "total size (after deleting $nfiles files): $(round(total, digits=2)) MB < $(max_mb) MB"
            end
            return
        end
    end
end
