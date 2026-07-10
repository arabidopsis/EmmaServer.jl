#!/bin/bash
DIR=~/Sites/websites/chloe/kelly
fastas=(NC_000932.1.fa
NC_001320.1.fa
NC_001666.2.fa
NC_001879.2.fa
NC_002202.1.fa
NC_002693.2.fa
NC_002762.1.fa
NC_005086.1.fa
NC_006050.1.fa
NC_006290.1.fa
NC_007144.1.fa
NC_007407.1.fa
NC_007499.1.fa
NC_007500.1.fa
NC_007578.1.fa
NC_007602.1.fa
NC_007898.3.fa
NC_007942.1.fa
NC_007944.1.fa
NC_007957.1.fa 
NC_006290.1.fa)

PORT=9998
URL="http://127.0.0.1:${PORT}"
if [ -d junk ]; then
    rm -rf junk
fi
mkdir -p junk
junk=$(realpath junk)
for fa in "${fastas[@]}"
do  
    fasta=${DIR}/$fa
    fullpath=$junk/res$fa.json
    outpath=$junk/out$fa.json
    echo "annotating: $fa"
    curl --silent "${URL}/chloe2_json?fasta=${fasta}" > $fullpath &
    # curl --silent "${URL}/emma_json?fasta=${fasta}" > $fullpath &
    # curl --silent "${URL}/chloe2_write_json?fasta=${fasta}&data_path=${fullpath}" > $outpath &
    # curl --silent "${URL}/emma_write_json?fasta=${fasta}&data_path=${fullpath}" > $outpath &
done
