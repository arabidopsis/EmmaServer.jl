# Define functions testfn1 and testfn2 that we shall expose

import Distributed: @spawnat
import Emma: doone, writeGFF, TempFile, drawgenome, trnF_start


function make_task(directory::String=".")
    function task_emma(; fasta::String="", svg::String="no", shift::String="no")
        if !isfile(fasta)
            error("no such file: $(fasta)")
        end
        tempfile = TempFile(directory)
        id, gffs, genome = fetch(@spawnat :any doone(fasta, tempfile))
        ret = Dict("uuid" => tempfile.uuid, "gffs" => gffs, "id" => id)
        if shift == "yes"
            gffs, genome = trnF_start(gffs, genome)
        end
        if svg == "yes"
            mRNAless = filter(x -> x.ftype != "mRNA" && x.ftype != "CDS", gffs)
            ret["svg"] = drawgenome(id, length(genome), mRNAless)
        end
        return ret
    end
    return task_emma

end
