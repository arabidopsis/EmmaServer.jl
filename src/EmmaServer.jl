module EmmaServer
export init_workers, get_args, main, BGLogger, set_global_logger, reset_log, get_model_lengths

include("utils.jl")
include("clean.jl")
include("dist.jl")
include("bglogger.jl")
include("emma_endpoints.jl")
include("chloe2_endpoints.jl")
include("cmd.jl")

# need this available in the main module so that the distributed workers can call it
import .Chloe2Endpoints: get_model_lengths

end # module EmmaServer
