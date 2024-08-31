# Emma Server

Web server that annotates Mitochondria via [Emma](https://github.com/ian-small/Emma)
e.g. start the server with:

```bash
julia --project=. --threads=8 srvr.jl --use-threads --port=9998
```
Then run

```bash
fasta="/path/to/fasta.fa"
curl "http://127.0.0.1:9998/emma?fasta=${fasta}&svg=yes"
```
## Notes

register julia package
https://julialang.org/contribute/developing_package/

JuliaFormatter: https://domluna.github.io/JuliaFormatter.jl/stable/
