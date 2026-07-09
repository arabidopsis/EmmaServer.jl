#!/bin/bash
fastas=(~/Sites/websites/chloe/kelly/NC_000932.1.fa
~/Sites/websites/chloe/kelly/NC_001320.1.fa
~/Sites/websites/chloe/kelly/NC_001666.2.fa
~/Sites/websites/chloe/kelly/NC_001879.2.fa
~/Sites/websites/chloe/kelly/NC_002202.1.fa
~/Sites/websites/chloe/kelly/NC_002693.2.fa
~/Sites/websites/chloe/kelly/NC_002762.1.fa
~/Sites/websites/chloe/kelly/NC_005086.1.fa
~/Sites/websites/chloe/kelly/NC_006050.1.fa
~/Sites/websites/chloe/kelly/NC_006290.1.fa
~/Sites/websites/chloe/kelly/NC_007144.1.fa
~/Sites/websites/chloe/kelly/NC_007407.1.fa
~/Sites/websites/chloe/kelly/NC_007499.1.fa
~/Sites/websites/chloe/kelly/NC_007500.1.fa
~/Sites/websites/chloe/kelly/NC_007578.1.fa
~/Sites/websites/chloe/kelly/NC_007602.1.fa
~/Sites/websites/chloe/kelly/NC_007898.3.fa
~/Sites/websites/chloe/kelly/NC_007942.1.fa
~/Sites/websites/chloe/kelly/NC_007944.1.fa
~/Sites/websites/chloe/kelly/NC_007957.1.fa 
~/Sites/websites/chloe/kelly/NC_006290.1.fa)

PORT=9998
if [ -d junk ]; then
    rm -rf junk
fi
mkdir -p junk
junk=$(realpath junk)
for fasta in "${fastas[@]}"
do
    n=$(basename $fasta)
    fullpath=$junk/res$n.json
    outpath=$junk/out$n.json
    echo "annotating: $n"
    curl --silent "http://127.0.0.1:${PORT}/chloe2_json?fasta=${fasta}" > $fullpath &
    # curl --silent "http://127.0.0.1:${PORT}/emma_json?fasta=${fasta}" > $fullpath &
    # curl --silent "http://127.0.0.1:${PORT}/chloe2_write_json?fasta=${fasta}&data_path=${fullpath}" > $outpath &
    # curl --silent "http://127.0.0.1:${PORT}/emma_write_json?fasta=${fasta}&data_path=${fullpath}" > $outpath &
done
