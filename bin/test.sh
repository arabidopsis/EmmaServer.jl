#!/bin/bash
fasta=~/Sites/websites/chloe/kelly/NC_001320.1.fa
ab -c 3 -n 20 "http://127.0.0.1:9998/emma?fasta=${fasta}"
