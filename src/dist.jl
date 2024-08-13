import Distributed
import Distributed: addprocs, @everywhere
function arm(procs)

    @everywhere procs begin
        # If we have a raw 'import EmmaServer' here then
        # precompilation (of the EmmaServer package) tries to recurse and 
        # compile EmmaServer *again* (I think) and fails.
        # "hiding" the import inside a quote seems to work.
        eval(quote
            using EmmaServer
        end)

    end

end
# function busywait(seconds)
#     tstart = time_ns()
#     while (time_ns() - tstart) / 1e9 < seconds
#     end
# end

function init_workers(nworkers::Int)
    addprocs(nworkers; topology=:master_worker, exeflags="--project=$(Base.active_project())")
    procs = filter(w -> w != 1, Distributed.workers())
    @info "background=$(procs)"
    arm(procs)
end


