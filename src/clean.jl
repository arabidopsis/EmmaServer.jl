
function clean(directory::String, wait::Real; old=2.0, verbose=false)
    if !isdir(directory)
        error("not a directory: $directory")
    end
    @info "checking $directory: wait=$(wait)secs old=$(old)days"
    while true
        now = time()
        for (root, dirs, files) in walkdir(directory)
            for file in files
                f = joinpath(root, file)
                t = mtime(f)
                days = (now - t) / (60 * 60 * 24)
                if days > old
                    rm(f, force=true)
                    if verbose
                        @info "removed: $f"
                    end
                end

            end
        end
        sleep(wait)
    end
end


