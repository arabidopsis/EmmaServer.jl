#!/bin/bash
fasta=~/Sites/websites/chloe/kelly/NC_001320.1.fa
curl -vv -F is_file=false -F fasta=@${fasta} http://127.0.0.1:9998/emma
