module EndpointsChloe2
export make_task_chloe2_write_json, make_task_chloe2_json, get_model_lengths, missing_executables
import Distributed: @spawnat
import FASTX: FASTA
import Chloe2: chloe, get_model_lengths, missing_executables
import Logging

import ..EmmaServer: loglines, atomic_write, maybe_gzread, maybe_gzwrite, local_logger

# true for strings like 1, true, TRUE, True, yes ,Yes, etc.
const YES = r"1|t|T|y|Y"

@kwdef struct CmdArgs
    fasta::String = ""
    sensitivity::Bool = false
    reportpseudos::Bool = false
end

function read_fasta(infile::IO)::FASTA.Record
    target = FASTA.Record()

    FASTA.Reader(infile) do reader
        read!(reader, target)
    end

    return target
end

function chloe2_json(tempdirectory::String, args::CmdArgs; tee::Bool=false)
    fasta = args.fasta
    # @info "running chloe2 with pseudo=$(args.reportpseudos)"
    io_buffer, task_logger = local_logger(Logging.Warn; tee=tee)
    buf = IOBuffer()
    bytes = maybe_gzread(fasta) do io
        bytes = read(io)
        Logging.with_logger(task_logger) do
            chloe(
                IOBuffer(bytes);
                outfile_gff=buf,
                tempdir=tempdirectory,
                reportpseudos=args.reportpseudos,
                sensitivity=args.sensitivity
            )
        end
        bytes
    end
    logs = loglines(String(take!(io_buffer)))
    gff = String(take!(buf))
    record = read_fasta(IOBuffer(bytes))
    id, len = FASTA.identifier(record), length(FASTA.sequence(record))

    ret = Dict(
        "fasta" => fasta,
        "gff" => gff,
        "logs" => logs,
        "id" => id,
        "length" => len,
        "sensitivity" => args.sensitivity,
        "reportpseudos" => args.reportpseudos
    )
    return ret
end

function chloe2_write_json(tempdirectory::String, args::CmdArgs, data_path::String; tee::Bool=false)
    dict = chloe2_json(tempdirectory, args; tee=tee)
    atomic_write(data_path, dict)

    return true
end

function make_task_chloe2_json(tempdirectory::String=".", use_threads::Bool=false; tee::Bool=false)
    # /chloe2_json?fasta=...&sensitivity=...&reportpseudos=...
    function task_chloe2_json(; fasta::String="", sensitivity::String="false", reportpseudos::String="false")
        if fasta == ""
            error("chloe2_json: fasta file must be specified")
        end
        # fasta = expanduser(fasta)
        if !isfile(fasta)
            error("chloe2_json: no such file: $(fasta)")
        end
        args = CmdArgs(;
            fasta=fasta,
            sensitivity=startswith(sensitivity, YES),
            reportpseudos=startswith(reportpseudos, YES)
        )
        if use_threads
            ret = fetch(Threads.@spawn chloe2_json(tempdirectory, args; tee=tee))

        else
            ret = fetch(@spawnat :any chloe2_json(tempdirectory, args; tee=tee))
        end
        @info "done $(fasta): $(ret["id"]) $(ret["length"])"
        ret
    end
    return task_chloe2_json
end

function make_task_chloe2_write_json(tempdirectory::String=".", use_threads::Bool=false; tee::Bool=false)
    # a reference to this url will call this function:
    # https://127.0.0.1:9998/chloe2_write_json?fasta=...&sensitivity=...&reportpseudos=...&data_path=...
    function task_chloe2_write_json(;
        fasta::String="",
        sensitivity::String="false",
        reportpseudos::String="false",
        data_path::String=""
    )
        if fasta == ""
            error("chloe2_write_json: fasta file must be specified")
        end
        # fasta = expanduser(fasta)
        if !isfile(fasta)
            error("chloe2_write_json: no such file: $(fasta)")
        end
        if data_path == ""
            error("chloe2_write_json: data_path must be specified")
        end
        args = CmdArgs(;
            fasta=fasta,
            sensitivity=startswith(sensitivity, YES),
            reportpseudos=startswith(reportpseudos, YES)
        )
        if use_threads
            ret = fetch(Threads.@spawn chloe2_write_json(tempdirectory, args, data_path; tee=tee))
        else
            ret = fetch(@spawnat :any chloe2_write_json(tempdirectory, args, data_path; tee=tee))
        end
        @info "done $(fasta)"
        ret
    end
    return task_chloe2_write_json
end
end # module EndpointsChloe2
