import ArgParse: ArgParseSettings, @add_arg_table!, parse_args
import JuliaWebAPI: APIInvoker, run_http, process, create_responder
import Logging

function git_version()
    git_version(dirname(@__FILE__))
end
function git_version(repo_dir::String)
    try
        # older version of git don't have -C
        strip(read(pipeline(`git -C "$repo_dir" rev-parse HEAD`; stderr=devnull), String))
        # strip(read(pipeline(`sh -c 'cd "$repo_dir" && git rev-parse HEAD'`, stderr=devnull), String))
    catch e
        "unknown"
    end
end
function get_args(args::Vector{String}=ARGS)
    distributed_args = ArgParseSettings(; prog="EmmaServer", autofix_names=true)  # turn "-" into "_" for arg names.
    #! format: off
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
        "--max-days"
        arg_type = Float32
        default = 30.0
        help = "files older than this in days will be removed"
        "--sleep-hours"
        arg_type = Float32
        default = 1.0
        help = "sleep in hours"
        "--console"
        action = :store_true
        help = "use the console logger"
        "--without-terminate", "-x"
        action = :store_true
        help = "don't have a terminate endpoint"
        "--use-threads"
        action = :store_true
        help = "use threads instead of processes"
    end

    parse_args(args, distributed_args; as_symbols=true)
end

const LOGLEVELS = Dict("info" => Logging.Info, "debug" => Logging.Debug, "warn" => Logging.Warn,
    "error" => Logging.Error)

function logger(level; console=false)
    if console
        logger = Logging.ConsoleLogger(stderr, level; meta_formatter=Logging.default_metafmt)
    else
        logger = Logging.SimpleLogger(stdout, level)
    end
    Logging.global_logger(logger)
end

function main(args=ARGS)
    Sys.set_process_title("emma-distributed")
    args = get_args(args)
    llevel = get(LOGLEVELS, lowercase(args[:level]), Logging.Warn)
    logger(llevel; console=args[:console])

    # Expose testfn1 and testfn2 via a ZMQ listener
    # endpoint = "tcp://127.0.0.1:9999"
    #endpoint = "inproc://test-1"
    endpoint = args[:endpoint]
    @info "endpoint=$(endpoint) port=$(args[:port])"
    tempdir = args[:tempdir]
    if !isdir(tempdir)
        error("no such directory: \"$(tempdir)\"")
    end

    version = git_version()

    function ping()
        return "OK $(version[1:7])"
    end

    function terminate()
        @info "terminated..."
        exit(0)
        return "OK"
    end

    function config()
        return args
    end

    task_emma = make_task4(tempdir, args[:use_threads])
    headers = Dict("Content-Type" => "application/json")
    # function, json_response, headers, name
    tasks = [(ping, true, headers),
        (config, true, headers),
        (task_emma, true,headers, "emma")]

    wt = args[:without_terminate]
    if !wt
        push!(tasks, (terminate, true))
    end
    resp = create_responder(tasks, endpoint, true, "")
    process(resp; async=true)

    nchannels = args[:nchannels]

    #Create the ZMQ client that talks to the ZMQ listener above

    if ~args[:use_threads]
        @info "using $(args[:workers]) workers"
        init_workers(args[:workers])
        if nchannels <= 0
            nchannels = args[:workers]
        end
    else
        @info "using $(Threads.nthreads()) threads"
        if nchannels <= 0
            nchannels = Threads.nthreads()
        end
    end

    apiclnt = [APIInvoker(endpoint) for i in 1:nchannels]
    watch = args[:watch]
    if watch !== nothing
        wait = args[:sleep_hours] * 60 * 60
        if wait < 60
            error("can't sleep less that 60 seconds")
        end
        @info "watching $watch $wait"
        @async clean(watch, wait; old=args[:max_days], verbose=false)
    end
    # Start the HTTP server in current process (Ctrl+C to interrupt)

    Base.exit_on_sigint(false)
    try
        run_http(apiclnt, args[:port])
    catch e
        if e isa InterruptException
            @info "Abort!"
            exit(0)
        end
        rethrow(e)
    end
end
