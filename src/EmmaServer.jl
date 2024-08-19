module EmmaServer
export task_emma, init_workers, get_args, main, BGLogger, set_global_logger, reset_log, emmatwo

include("clean.jl")
include("cmd.jl")
include("dist.jl")
include("endpoints.jl")
include("bglogger.jl")

end # module EmmaServer
