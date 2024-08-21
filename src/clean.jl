import Dates: unix2datetime

function clean(directory::String, wait::Real; old=2.0, verbose=false)
    if !isdir(directory)
        error("not a directory: $directory")
    end
    @info "checking $directory: wait=$(wait)secs old=$(old)days"

    while true
        now = time()
        nerr = 0
        try
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
        catch e
            @error "walkdir: $(e)"
            nerr += 1
        end
        open(joinpath(directory, ".clean"), "w") do out
            write(out, "$(unix2datetime(now)): $(nerr)\n")
        end
        sleep(wait)
    end
end
