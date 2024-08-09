import ArgParse: ArgParseSettings, @add_arg_table!, parse_args
import JuliaWebAPI: APIInvoker, run_http, process, create_responder
import Logging
function get_args(args::Vector{String}=ARGS)
    distributed_args = ArgParseSettings(prog="EmmaServer", autofix_names=true)  # turn "-" into "_" for arg names.

    @add_arg_table! distributed_args begin

        "--workers", "-w"
        arg_type = Int
        default = 3
        help = "number of distributed processes"
        "--nchannels", "-c"
        arg_type = Int
        default = 1
        help = "number of API channels for http server"
        "--endpoint", "-e"
        arg_type = String
        default = "ipc:///tmp/juliabackground"
        help = "endpoint for zmq connection"
        "--port", "-p"
        arg_type = Int
        default = 9998
        help = "http connection port"
    end

    parse_args(args, distributed_args; as_symbols=true)

end

function logger()
    logger = Logging.SimpleLogger(stdout, Logging.Debug)
    Logging.global_logger(logger)
end

function main()
    Sys.set_process_title("emma-distributed")
    # logger()
    args = get_args()
    # Expose testfn1 and testfn2 via a ZMQ listener
    # endpoint = "tcp://127.0.0.1:9999"
    #endpoint = "inproc://test-1"
    endpoint = args[:endpoint]
    @info "endpoint = $(endpoint) port=$(args[:port])"

    resp = create_responder([
            (task_testfn1, true, Dict{String,String}(), "testfn1"), # respond with json
            (task_testfn2, false, Dict{String,String}(), "testfn2"), # respond with text
            (task_emma, false, Dict{String,String}(), "emma") # respond with text
        ], endpoint, true, "")
    # @info "function $(task_testfn1),$(task_testfn2) $(endpoint) $(resp)"
    process(resp, async=true)



    #Create the ZMQ client that talks to the ZMQ listener above
    apiclnt = [APIInvoker(endpoint) for i in 1:args[:nchannels]]

    #Start the HTTP server in current process (Ctrl+C to interrupt)

    init_workers(args[:workers])
    # @sync Threads.@spawn run_http(apiclnt, args[:port])
    run_http(apiclnt, args[:port])
end
