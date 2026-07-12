module EmmaServer
export main, get_model_lengths, missing_executables

include("utils.jl")
include("clean.jl")
include("dist.jl")
include("endpoints_emma.jl")
include("endpoints_chloe2.jl")
include("cmd.jl")

(@main)(args=ARGS) = emma_main(args)

# need this available in the main module so that the distributed workers can call it
import .EndpointsChloe2: get_model_lengths, missing_executables

end # module EmmaServer
