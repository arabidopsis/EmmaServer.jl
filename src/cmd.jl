import Logging
import ArgParse: ArgParseSettings, @add_arg_table!, parse_args
import JuliaWebAPI: APIInvoker, run_http, process, create_responder, ZMQTransport, JSONMsgFormat, apicall
import .EndpointsEmma: make_task_emma_json, make_task_emma_write_json
import .EndpointsChloe2: make_task_chloe2_json, make_task_chloe2_write_json, get_model_lengths, missing_executables

function git_version()
    git_version(dirname(@__FILE__))
end
function git_version(repo_dir::String)
    try
        # older version of git don't have -C
        git = Sys.which("git")
        if git === nothing
            return "unknown"
        end 
        strip(read(pipeline(`$(git) -C "$repo_dir" rev-parse HEAD`; stderr=devnull), String))
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
        default = 4
        help = "number of distributed processes [default = 4], ignored if --use-threads is specified"
        "--endpoint", "-e"
        arg_type = String
        help = "endpoint for zmq connection [default = ipc:///{tempdir}/emma-distributed{port}]"
        "--port", "-p"
        arg_type = Int
        default = 9998
        help = "http connection port"
        "--tempdir", "-t"
        arg_type = String
        help = "temporary file directory [default = tempdir()]" 
        "--watch"
        arg_type = String
        help = "watch directory"
        action = :append_arg
        help = "cleanup files in the watch directory (can be specified multiple times)"
        "--max-days"
        arg_type = Float32
        default = 30.0
        help = "files older than this in days will be removed (see --watch)"
        "--sleep-hours"
        arg_type = Float32
        default = 2.0
        help = "sleep in hours between directory sweep (see --watch)"
        # "--console"
        # action = :store_true
        # help = "use the console logger"
        "--without-terminate", "-x"
        action = :store_true
        help = "don't have a \"terminate\" endpoint"
        "--use-threads"
        action = :store_true
        help = "use threads instead of processes (Threads.nthreads() [--threads=n] must be > 1 for this to work)"
        "--tee"
        action = :store_true
        help = "also print logs to the console when processing requests"
    end

    parse_args(args, distributed_args; as_symbols=true)
end

const LOGLEVELS = Dict("info" => Logging.Info, "debug" => Logging.Debug, "warn" => Logging.Warn,
    "error" => Logging.Error)

const JSON_RESP_HDRS = Dict{String,String}("Content-Type" => "application/json; charset=utf-8")

function set_logger(level)
    # the systemd.service file has StandardOutput=append:/path/to/emma-annotator.log.
    # If you want to see the log output of the background annotators then use ``--tee``
    # otherwise it will be captured and sent back to the frontend via the API response.
    logger = Logging.ConsoleLogger(stdout, level; meta_formatter=Logging.default_metafmt)
    Logging.global_logger(logger)
end

function emma_main(args=ARGS)
    Sys.set_process_title("emma-distributed")
    args = get_args(args)

    set_logger(get(LOGLEVELS, lowercase(args[:level]), Logging.Warn))

    missing = missing_executables()
    if length(missing) > 0
        @error("missing executables for chloe2: $(join(missing, ", "))")
        exit(1)
    end
    
    tmpdir = args[:tempdir]
    if tmpdir === nothing
        tmpdir = tempdir()
    end
    if !isdir(tmpdir)
        error("no such directory: \"$(tmpdir)\"")
    end

    endpoint = args[:endpoint]
    if endpoint === nothing
        endpoint = "ipc://$(tmpdir)/emma-distributed$(args[:port])"
        args[:endpoint] = endpoint # for server config output
    end
    @info "endpoint=$(endpoint) port=$(args[:port])"

    version = git_version()

    function ping()
        return "OK $(version[1:7])"
    end

    function terminate_later()
        # need to sleep so the terminate function is fully processed by the APIResponder,
        # and has sent terminate's value back to the client.
        sleep(0.3)
        @info "sending terminate requests to $(length(apiclnt)) channels."
        for api in apiclnt
            apicall(api, ":terminate")
        end
        @info("exiting... 👋")
        exit(0)

    end
    function terminate()
        @info "terminating..."
        # The problem here is that we can't terminate all the channels while we
        # are still being processed by one of them! So we delegate to an async task
        # that will terminate all channels after a short sleep.
        @async terminate_later()
        return "OK\n"
    end

    function config()
        return args
    end
    tee = args[:tee]

    # function, json_response, headers, name
    json_response = true
    ut = args[:use_threads]
    tasks = [
        (ping, json_response, JSON_RESP_HDRS, "ping"),
        (config, json_response, JSON_RESP_HDRS , "config"),
        (make_task_emma_json(tmpdir, ut; tee=tee), json_response, JSON_RESP_HDRS, "emma_json"),
        (make_task_emma_write_json(tmpdir, ut; tee=tee), json_response, JSON_RESP_HDRS, "emma_write_json"),
        (make_task_chloe2_json(tmpdir, ut; tee=tee), json_response, JSON_RESP_HDRS, "chloe2_json"),
        (make_task_chloe2_write_json(tmpdir, ut; tee=tee), json_response, JSON_RESP_HDRS, "chloe2_write_json")
    ]

    wt = args[:without_terminate]
    if !wt
        # not a json response, so we can just return a string.
        push!(tasks, (terminate, false, Dict{String,String}(), "terminate"))
    end
   

    if !ut
        workers = args[:workers]
        @info "using $(workers) workers"
        init_workers(workers)
        nchannels = workers
    else
        @info "using $(Threads.nthreads()) threads"
        nchannels = Threads.nthreads()
        if nchannels < 2
            error("Threads.nthreads() must be > 1 for --use-threads to work [set --threads=n *julia* option]")
        end
        # read chloe2 artifacts into memory
        get_model_lengths()

    end
    apiclnt::Vector{APIInvoker{ZMQTransport, JSONMsgFormat}} = []
    for i in 1:nchannels
        ep = "$(endpoint)-$(i)"
        @info "starting channel: $(ep)"
        push!(apiclnt, APIInvoker(ep))
        # bind=true nid=nothing
        resp = create_responder(tasks, ep, true, nothing)
        process(resp; async=true)
    end
    watch = args[:watch]
    if watch !== nothing && length(watch) > 0
        watch = [expanduser(w) for w in watch]
        wait = args[:sleep_hours] * 60 * 60
        if wait < 600
            error("can't sleep less than 600 seconds: $(wait)")
        end
        # @info "watching $watch every=$(wait)secs"
        @async clean(watch, wait; old=args[:max_days], verbose=false)
    end
    # for config output
    args[:nchannels] = nchannels
    # Start the HTTP server in current process (Ctrl+C to interrupt)
    try
        run_http(apiclnt, args[:port])
    catch e
        # Ctrl+C never gets here :(
        if e isa InterruptException
            @info "Abort!"
            exit(0)
        end
        rethrow()
    end
end
