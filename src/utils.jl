import Random
import JSON3
import CodecZlib: GzipDecompressorStream, GzipCompressorStream

function atomic_write(path::String, data)
    parent = dirname(path)
    _, ext = splitext(path)
    tmp = joinpath(parent, "$(Random.rand(UInt32))$(ext)")
    try
        maybe_gzwrite(tmp) do io
            JSON3.write(io, data)
        end
        mv(tmp, path)
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
