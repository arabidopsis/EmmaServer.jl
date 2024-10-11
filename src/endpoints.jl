# Define functions testfn1 and testfn2 that we shall expose

import Distributed: @spawnat
import Emma: emmaone, TempFile, drawgenome, rotate, writeGB, cleanfiles
import CodecZlib: GzipDecompressorStream, GzipCompressorStream
using FASTX
import Base64: base64decode
import JSON3
import Random

@kwdef struct CmdArgs
    fasta::String = ""
    svg::String = "no"
    rotate_to::String = ""
    gb::String = "no"
    species::String = "vertebrate"
    is_file::Bool = true # fasta is a filename else the b64 encoded body of the fasta file
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

function emmatwo(tempfile::TempFile, infile::String, translation_table::Integer; is_file=true)
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

function emmathree(tempdirectory::String, args::CmdArgs; use_threads::Bool=false)
    fasta = args.fasta
    if args.is_file
        fasta = expanduser(fasta)
        if !isfile(fasta)
            error("no such file: $(fasta)")
        end
    end

    translation_table = args.species == "vertebrate" ? 2 : 5
    tempfile = TempFile(tempdirectory)
    if use_threads
        id, gffs, genome, logs = fetch(Threads.@spawn emmatwo(tempfile, fasta, translation_table; is_file=args.is_file))
    else
        id, gffs, genome, logs = fetch(@spawnat :any emmatwo(tempfile, fasta, translation_table; is_file=args.is_file))
    end

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

function emmafour(tempdirectory::String, args::CmdArgs)
    fasta = args.fasta
    if args.is_file
        fasta = expanduser(fasta)
        if !isfile(fasta)
            error("no such file: $(fasta)")
        end
    end
    translation_table = args.species == "vertebrate" ? 2 : 5
    tempfile = TempFile(tempdirectory)
    id, gffs, genome, logs = emmatwo(tempfile, fasta, translation_table; is_file=args.is_file)

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
function emmafive(tempdirectory::String, args::CmdArgs, data_path::String)
    dict = emmafour(tempdirectory, args)
    atomic_write(data_path, dict)

    return true
end

function make_task2(tempdirectory::String=".", use_threads::Bool=false)
    function task_emma2(;
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
            is_file=startswith(is_file, r"1|t|T")
        )
        emmathree(tempdirectory, args; use_threads=use_threads)
    end
    return task_emma2
end

function make_task4(tempdirectory::String=".", use_threads::Bool=false)
    function task_emma4(;
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
            is_file=startswith(is_file, r"1|t|T")
        )
        if use_threads
            fetch(Threads.@spawn emmafour(tempdirectory, args))

        else
            fetch(@spawnat :any emmafour(tempdirectory, args))
        end
    end
    return task_emma4
end

function make_task5(tempdirectory::String=".", use_threads::Bool=false)
    function task_emma5(;
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
            is_file=startswith(is_file, r"1|t|T")
        )
        if use_threads
            fetch(Threads.@spawn emmafive(tempdirectory, args, data_path))

        else
            fetch(@spawnat :any emmafive(tempdirectory, args, data_path))
        end
    end
    return task_emma5
end
