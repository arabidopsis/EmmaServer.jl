#!/bin/bash
fastas=(~/Sites/websites/chloe/kelly/NC_002762.1.fa
        ~/Sites/websites/chloe/kelly/NC_005086.1.fa
        ~/Sites/websites/chloe/kelly/NC_006050.1.fa
        ~/Sites/websites/chloe/kelly/NC_006290.1.fa)
mkdir -p junk
for fasta in "${fastas[@]}"
do
    echo $fasta
    n=$(basename $fasta)
    curl --silent "http://127.0.0.1:9998/chloe2_json?fasta=${fasta}" > junk/res$n.json &
done
