import Dates: unix2datetime

function clean(directories::Vector{String}, wait::Real; old=2.0, verbose=false)
    for directory in directories
        if !isdir(directory)
            error("not a directory: $directory")
        end
        @info "checking $directory: wait=$(wait)secs old=$(old)days"
    end

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
