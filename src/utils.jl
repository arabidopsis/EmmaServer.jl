import Random
import JSON
import CodecZlib: GzipDecompressorStream, GzipCompressorStream
import Logging
import LoggingExtras

function atomic_write(path::String, data)
    parent = dirname(path)
    _, ext = splitext(path)
    tmp = joinpath(parent, "$(Random.rand(UInt32))$(ext)")
    try
        maybe_gzwrite(tmp) do io
            JSON.json(io, data)
        end
        mv(tmp, path; force=true)
    catch
        rm(tmp; force=true)
        rethrow()
    end
end
function maybe_gzread(f::Function, filename::String)
    if endswith(filename, ".gz")
        open(z -> z |> GzipDecompressorStream |> f, filename)
    else
        open(f, filename)
    end
end

function maybe_gzwrite(f::Function, filename::String)
    function gzcompress(func::Function, fp::IO)
        o = GzipCompressorStream(fp)
        try
            func(o)
        finally
            close(o)
        end
    end

    if endswith(filename, ".gz")
        open(fp -> gzcompress(f, fp), filename, "w")
    else
        open(f, filename, "w")
    end
end

function loglines(logs::AbstractString)::Vector{String}
    [replace(s, '┌' => '[') for s in split(logs, '\n'; keepempty=false) if !startswith(s, "└")]
end

function local_logger(level=Logging.Info; tee::Bool=false)::Tuple{IOBuffer,Logging.AbstractLogger}
    io_buffer = IOBuffer()

    logger = Logging.ConsoleLogger(io_buffer, level)
    if tee
        logger = LoggingExtras.TeeLogger(logger, Logging.global_logger())
    end
    return io_buffer, logger
end
