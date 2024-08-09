# Define functions testfn1 and testfn2 that we shall expose

import Distributed: @spawnat
import Emma: doone, writeGFF, TempFile


function make_task(directory::String=".")
    function task_emma(; fasta::String="")
        tempfile = TempFile(directory)
        id, gffs, genome = fetch(@spawnat :any doone(fasta, tempfile))
        # writeGFF(id, gffs, outfile)
        return Dict("uuid" => tempfile.uuid, "gffs" => gffs, "id" => id)
    end
    return task_emma

end
