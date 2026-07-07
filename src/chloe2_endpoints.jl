module Chloe2Endpoints
export make_task_chloe2_write_json, make_task_chloe2_json, get_model_lengths
import Distributed: @spawnat
import FASTX: FASTA
import Base64: base64decode
import Chloe2: TempFile, chloeone, chloe, get_model_lengths
import ..EmmaServer: reset_log, atomic_write, maybe_gzread, maybe_gzwrite

@kwdef struct CmdArgs
    fasta::String = ""
    is_file::Bool = true # fasta is a filename else the b64 encoded body of the fasta file
end

function _emmatwo(tempfile::TempFile, infile::String, translation_table::Integer; is_file=true)
    target = FASTA.Record()
    if is_file
        maybe_gzread(infile) do io
            FASTA.Reader(io) do reader
                read!(reader, target)
            end
        end
    else
        fasta = String(base64decode(infile))
        FASTA.Reader(IOBuffer(fasta)) do reader
            read!(reader, target)
        end
    end
    try
        id, gffs, genome = emmaone(tempfile, target, translation_table)
        return (id, gffs, genome, reset_log())
    finally
        cleanfiles(tempfile)
    end
end

function chloe2_json(tempdirectory::String, args::CmdArgs)
    fasta = args.fasta
    if args.is_file
        fasta = expanduser(fasta)
        if !isfile(fasta)
            error("no such file: $(fasta)")
        end
    end
    buf = IOBuffer()
    chloe(fasta; outfile_gff=buf, tempdir=tempdirectory)
    gff = String(take!(buf))
    ret = Dict("fasta" => fasta, "is_file" => args.is_file, "gff" => gff)
    return ret
end

function chloe2_write_json(tempdirectory::String, args::CmdArgs, data_path::String)
    dict = chloe2_json(tempdirectory, args)
    atomic_write(data_path, dict)

    return true
end

function make_task_chloe2_json(tempdirectory::String=".", use_threads::Bool=false)
    function task_chloe2_json(; fasta::String="", is_file::String="true")
        args = CmdArgs(; fasta=fasta, is_file=startswith(is_file, r"1|t|T"))
        if use_threads
            fetch(Threads.@spawn chloe2_json(tempdirectory, args))

        else
            fetch(@spawnat :any chloe2_json(tempdirectory, args))
        end
    end
    return task_chloe2_json
end

function make_task_chloe2_write_json(tempdirectory::String=".", use_threads::Bool=false)
    function task_chloe2_write_json(; fasta::String="", is_file::String="true", data_path::String="")
        args = CmdArgs(; fasta=fasta, is_file=startswith(is_file, r"1|t|T"))
        if use_threads
            fetch(Threads.@spawn chloe2_write_json(tempdirectory, args, data_path))

        else
            fetch(@spawnat :any chloe2_write_json(tempdirectory, args, data_path))
        end
    end
    return task_chloe2_write_json
end
end # module Chloe2Endpoints
