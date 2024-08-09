module EmmaServer
export task_emma, init_workers, get_args, main, logger


include("cmd.jl")
include("dist.jl")
include("endpoints.jl")

end # module EmmaServer
