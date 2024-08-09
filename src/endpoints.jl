# Define functions testfn1 and testfn2 that we shall expose

import Distributed: @spawnat
import Emma: doone, writeGFF
using UUIDs
mutable struct GFF
    source::Int
    ftype::String

end
function testfn1(arg1, arg2; narg1="1", narg2="2")
    @info "id=$(Distributed.myid())"
    # sleep(2.0)
    # result = (parse(Int, arg1) * parse(Int, narg1)) + (parse(Int, arg2) * parse(Int, narg2))
    result = [GFF(parse(Int, arg1), narg1), GFF(parse(Int, arg2), narg2)]
    return Dict("id" => Distributed.myid(), "result" => result)
    # return result
end

testfn2(arg1, arg2; narg1="1", narg2="2") = testfn1(arg1, arg2; narg1=narg1, narg2=narg2)


function task_testfn1(arg1, arg2; narg1="1", narg2="2")
    return fetch(@spawnat :any testfn1(arg1, arg2; narg1=narg1, narg2=narg2))
end
function task_testfn2(arg1, arg2; narg1="1", narg2="2")
    return fetch(@spawnat :any testfn2(arg1, arg2; narg1=narg1, narg2=narg2))
end

function task_emma(; fasta::String="")
    uuid = uuid4()
    id, gffs, genome = fetch(@spawnat :any doone(fasta, uuid))
    # writeGFF(id, gffs, outfile)
    return Dict("uuid" => uuid, "gffs" => gffs, "id" => id)
end

