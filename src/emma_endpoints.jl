module EmmaEndpoints
export make_task_emma_write_json, make_task_emma_json
import Distributed: @spawnat
import Emma: emmaone, TempFile, drawgenome, rotate, writeGB, cleanfiles
import FASTX: FASTA
import Base64: base64decode
import Logging
import ..EmmaServer: atomic_write, maybe_gzread, maybe_gzwrite, loglines, local_logger

@kwdef struct CmdArgs
    fasta::String = ""
    svg::String = "no"
    rotate_to::String = ""
    gb::String = "no"
    species::String = "vertebrate"
    is_file::Bool = true # fasta is a filename else the b64 encoded body of the fasta file
end

const YES = r"1|t|T|y|Y"

function _emmatwo(tempfile::TempFile, infile::String, translation_table::Integer; is_file=true, tee::Bool=false)
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
        io_buffer, task_logger = local_logger(Logging.Warn; tee=tee)
        id, gffs, genome = Logging.with_logger(task_logger) do
            emmaone(tempfile, target, translation_table)
        end
        return (id, gffs, genome, loglines(String(take!(io_buffer))))
    finally
        cleanfiles(tempfile)
    end
end

function emma_json(tempdirectory::String, args::CmdArgs; tee::Bool=false)
    fasta = args.fasta
    if args.is_file
        fasta = expanduser(fasta)
        if !isfile(fasta)
            error("no such file: $(fasta)")
        end
    end
    translation_table = args.species == "vertebrate" ? 2 : 5
    tempfile = TempFile(tempdirectory)
    id, gffs, genome, logs = _emmatwo(tempfile, fasta, translation_table; is_file=args.is_file, tee=tee)

    offset = 0
    if args.rotate_to != ""
        gffs, genome, offset = rotate(args.rotate_to, gffs, genome)
    end
    ret = Dict(
        "gffs" => gffs,
        "id" => id,
        "length" => length(genome),
        "offset" => offset,
        "species" => args.species,
        "rotate_to" => args.rotate_to
    )
    if args.svg == "yes"
        # mRNAless = filter(x -> x.ftype != "mRNA" && x.ftype != "CDS", gffs)
        ret["svg"] = drawgenome(id, length(genome), gffs)
    end
    if args.gb == "yes"
        buf = IOBuffer()
        writeGB(buf, tempfile.uuid, id, translation_table, gffs)
        ret["gb"] = String(take!(buf))
    end
    ret["log"] = logs
    return ret
end

function emma_write_json(tempdirectory::String, args::CmdArgs, data_path::String; tee::Bool=false)
    dict = emma_json(tempdirectory, args; tee=tee)
    atomic_write(data_path, dict)

    return true
end

function make_task_emma_json(tempdirectory::String=".", use_threads::Bool=false; tee::Bool=false)
    function task_emma_json(;
        fasta::String="",
        svg::String="no",
        rotate_to::String="",
        gb::String="no",
        species::String="vertebrate",
        is_file::String="true"
    )
        args = CmdArgs(;
            fasta=fasta,
            svg=svg,
            rotate_to=rotate_to,
            gb=gb,
            species=species,
            is_file=startswith(is_file, YES)
        )
        if use_threads
            ret = fetch(Threads.@spawn emma_json(tempdirectory, args; tee=tee))

        else
            ret = fetch(@spawnat :any emma_json(tempdirectory, args; tee=tee))
        end
        return ret
    end
    return task_emma_json
end

function make_task_emma_write_json(tempdirectory::String=".", use_threads::Bool=false; tee::Bool=false)
    function task_emma_write_json(;
        fasta::String="",
        svg::String="no",
        rotate_to::String="",
        gb::String="no",
        species::String="vertebrate",
        is_file::String="true",
        data_path::String=""
    )
        args = CmdArgs(;
            fasta=fasta,
            svg=svg,
            rotate_to=rotate_to,
            gb=gb,
            species=species,
            is_file=startswith(is_file, YES)
        )
        if use_threads
            fetch(Threads.@spawn emma_write_json(tempdirectory, args, data_path; tee=tee))

        else
            fetch(@spawnat :any emma_write_json(tempdirectory, args, data_path; tee=tee))
        end
    end
    return task_emma_write_json
end
end # module EmmaEndpoints
