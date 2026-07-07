module EmmaServer
export init_workers, get_args, main, BGLogger, set_global_logger, reset_log

include("utils.jl")
include("clean.jl")
include("dist.jl")
include("bglogger.jl")
include("emma_endpoints.jl")
include("cmd.jl")

end # module EmmaServer
