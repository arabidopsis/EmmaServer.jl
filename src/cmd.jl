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
        help = "number of API channels for http server [default == workers or nthreads]"
        "--endpoint", "-e"
        arg_type = String
        help = "endpoint for zmq connection [default = ipc:///tmp/emma-distributed{port}]"
        "--port", "-p"
        arg_type = Int
        default = 9998
        help = "http connection port"
        "--tempdir", "-t"
        arg_type = String
        help = "temporary file directory [default is system tempdir()]" 
        "--watch"
        arg_type = String
        help = "watch directory"
        "--max-days"
        arg_type = Float32
        default = 30.0
        help = "files older than this in days will be removed"
        "--sleep-hours"
        arg_type = Float32
        default = 2.0
        help = "sleep in hours between directory sweep"
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

const JSON_RESP_HDRS = Dict{String,String}("Content-Type" => "application/json; charset=utf-8")

function main(args=ARGS)
    Sys.set_process_title("emma-distributed")
    args = get_args(args)
    llevel = get(LOGLEVELS, lowercase(args[:level]), Logging.Warn)
    logger(llevel; console=args[:console])

    tmpdir = args[:tempdir]
    if tmpdir === nothing
        tmpdir = tempdir()
    end
    if !isdir(tmpdir)
        error("no such directory: \"$(tmpdir)\"")
    end
    # endpoint = "tcp://127.0.0.1:9999"
    #endpoint = "inproc://test-1"
    endpoint = args[:endpoint]
    if endpoint === nothing
        endpoint = "ipc://$(tmpdir)/emma-distributed$(args[:port])"
    end
    @info "endpoint=$(endpoint) port=$(args[:port])"

    version = git_version()

    function ping()
        return "OK $(version[1:7])"
    end

    function terminate()
        @info "terminated..."
        @async begin sleep(3); exit(0) end
        return "OK"
    end

    function config()
        return args
    end

    task_emma = make_task4(tmpdir, args[:use_threads])
    task_emma5 = make_task5(tmpdir, args[:use_threads])

    # function, json_response, headers, name
    tasks = [
        (ping, true, JSON_RESP_HDRS, "ping"),
        (config, true, JSON_RESP_HDRS , "config"),
        (task_emma, true, JSON_RESP_HDRS, "emma"),
        (task_emma5, true, JSON_RESP_HDRS, "emma5")
    ]

    wt = args[:without_terminate]
    if !wt
        push!(tasks, (terminate, false, Dict{String,String}(), "terminate"))
    end
    # bind=true nid=nothing
    resp = create_responder(tasks, endpoint, true, nothing)

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

    watch = args[:watch]
    if watch !== nothing
        watch = expanduser(watch)
        wait = args[:sleep_hours] * 60 * 60
        if wait < 600
            error("can't sleep less that 600 seconds: $(wait)")
        end
        # @info "watching $watch every=$(wait)secs"
        @async clean(watch, wait; old=args[:max_days], verbose=false)
    end
    # Start the HTTP server in current process (Ctrl+C to interrupt)
    
    apiclnt = [APIInvoker(endpoint) for i in 1:nchannels]

    try
        run_http(apiclnt, args[:port])
    catch e
        if e isa InterruptException
            @info "Abort!"
            exit(0)
        end
        rethrow()
    end
end
