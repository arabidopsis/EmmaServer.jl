# Define functions testfn1 and testfn2 that we shall expose

import Distributed: @spawnat
import Emma: emmaone, writeGFF, TempFile, drawgenome, rotate, writeGB


function make_task(directory::String=".")
    function task_emma(; fasta::String="", svg::String="no", rotate_to::String="", gb="no",
        species::String="vertebrate")
        if !isfile(fasta)
            error("no such file: $(fasta)")
        end
        translation_table = species == "vertebrate" ? 2 : 5
        tempfile = TempFile(directory)
        id, gffs, genome = fetch(@spawnat :any emmaone(tempfile, fasta, translation_table))
        offset = 0
        if rotate_to != ""
            gffs, genome, offset = rotate(rotate_to, gffs, genome)
        end
        ret = Dict("uuid" => tempfile.uuid, "gffs" => gffs, "id" => id,
            "length" => length(genome), "offset" => offset, "species" => species)
        if svg == "yes"
            # mRNAless = filter(x -> x.ftype != "mRNA" && x.ftype != "CDS", gffs)
            ret["svg"] = drawgenome(id, length(genome), gffs)
        end
        if gb == "yes"
            buf = IOBuffer()
            writeGB(buf, tempfile.uuid, id, translation_table, gffs)
            ret["gb"] = String(take!(buf))
        end
        return ret
    end
    return task_emma

end
