import Logging
const LOG = Ref{Vector{String}}([])
const LOCK = ReentrantLock()

function reset_log()::Vector{String}
    lock(LOCK) do
        log = LOG[]
        LOG[] = []
        log
    end
end

struct BGLogger <: Logging.AbstractLogger
    min_level::Logging.LogLevel

    function BGLogger(min_level::Logging.LogLevel = Logging.Warn)
        new(min_level)
    end
end

function Logging.handle_message(logger::BGLogger, level, message, _module, group, id,
    filepath, line; maxlog = nothing, kwargs...)
    if maxlog !== nothing && maxlog isa Integer
        remaining = get!(logger.message_limits, id, maxlog)
        logger.message_limits[id] = remaining - 1
        remaining > 0 || return
    end
    msglines = split(chomp(string(message)), '\n')
    buf = IOBuffer()
    io = IOContext(buf, stderr)
    println(io, msglines[1])
    for v in msglines[2:end]
        println(io, "\t> ", v)
    end
    for (key, val) in kwargs
        println(io, "\t> ", key, " = ", val)
    end
    msg = String(take!(buf))
    prefix = (level == Logging.Warn ? "WARNING" : uppercase(string(level)))
    msg = "$(prefix): $(msg)"
    lock(LOCK) do
        push!(LOG[], msg)
    end
    nothing
end
function Logging.shouldlog(logger::BGLogger, level, _module, group, id)
    true
end

function Logging.min_enabled_level(logger::BGLogger)
    logger.min_level
end

function Logging.catch_exceptions(logger::BGLogger)
    false
end

function set_global_logger(level::String = "warn")
    llevel = get(LOGLEVELS, level, Logging.Warn)

    logger = BGLogger(llevel)

    Logging.global_logger(logger)
end
