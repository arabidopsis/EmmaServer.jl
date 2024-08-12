import ArgParse: ArgParseSettings, @add_arg_table!, parse_args
import JuliaWebAPI: APIInvoker, run_http, process, create_responder
import Logging

function git_version()
    repo_dir = dirname(@__FILE__)
    try
        # older version of git don't have -C
        strip(read(pipeline(`git -C "$repo_dir" rev-parse HEAD`, stderr=devnull), String))
        # strip(read(pipeline(`sh -c 'cd "$repo_dir" && git rev-parse HEAD'`, stderr=devnull), String))
    catch e
        "unknown"
    end
end
function get_args(args::Vector{String}=ARGS)
    distributed_args = ArgParseSettings(prog="EmmaServer", autofix_names=true)  # turn "-" into "_" for arg names.

    @add_arg_table! distributed_args begin
        "--level", "-l"
        arg_type = String
        default = "info"
        help = "log level (info,warn,error,debug)"
        "--workers", "-w"
        arg_type = Int
        default = 3
        help = "number of distributed processes"
        "--nchannels", "-c"
        arg_type = Int
        default = -1
        help = "number of API channels for http server [default = workers]"
        "--endpoint", "-e"
        arg_type = String
        default = "ipc:///tmp/emma-distributed"
        help = "endpoint for zmq connection"
        "--port", "-p"
        arg_type = Int
        default = 9998
        help = "http connection port"
        "--tempdir", "-t"
        arg_type = String
        default = "/tmp"
        help = "temp directory"
        "--watch"
        arg_type = String
        help = "watch directory"
        "--old"
        arg_type = Float32
        default = 10.0
        help = "files older than this in days will be removed"
        "--sleep"
        arg_type = Float32
        default = 1.0
        help = "sleep in hours"
    end

    parse_args(args, distributed_args; as_symbols=true)

end

const LOGLEVELS = Dict("info" => Logging.Info, "debug" => Logging.Debug, "warn" => Logging.Warn,
    "error" => Logging.Error)

function logger(level)
    logger = Logging.SimpleLogger(stdout, level)
    # logger = Logging.ConsoleLogger(stderr, level, meta_formatter=Logging.default_metafmt)
    Logging.global_logger(logger)
end

function main(args=ARGS)
    Sys.set_process_title("emma-distributed")
    args = get_args(args)
    llevel = get(LOGLEVELS, lowercase(args[:level]), Logging.Warn)
    logger(llevel)
    version = git_version()
    # Expose testfn1 and testfn2 via a ZMQ listener
    # endpoint = "tcp://127.0.0.1:9999"
    #endpoint = "inproc://test-1"
    endpoint = args[:endpoint]
    @info "endpoint=$(endpoint) port=$(args[:port])"
    tempdir = args[:tempdir]
    if !isdir(tempdir)
        error("no such directory: \"$(tempdir)\"")
    end
    function ping()
        return "OK $(version[1:7])"
    end

    function terminate()
        @info "terminated..."
        exit(0)
        return "OK"
    end

    task_emma = make_task(tempdir)

    resp = create_responder([
            (ping, true),
            (terminate, true),
            (task_emma, true, Dict{String,String}(), "emma") # respond with text
        ], endpoint, true, "")
    process(resp, async=true)

    nchannels = args[:nchannels]
    if nchannels <= 0
        nchannels = args[:workers]
    end
    #Create the ZMQ client that talks to the ZMQ listener above
    apiclnt = [APIInvoker(endpoint) for i in 1:nchannels]

    init_workers(args[:workers])

    watch = args[:watch]
    if watch !== nothing
        wait = args[:sleep] * 60 * 60
        if wait < 60
            error("can't sleep less that 60 seconds")
        end
        @info "watching $watch $wait"
        @async clean(watch, wait; old=args[:old], verbose=false)
    end

    # Start the HTTP server in current process (Ctrl+C to interrupt)
    run_http(apiclnt, args[:port])

end


