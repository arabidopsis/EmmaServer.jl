SHELL=/bin/bash
JULIADIR=`julia -e 'print(Sys.BINDIR)'`/..
TEMPDIR=`realpath ../emma-website/instance/datadir`
# requires a python environment with flask-nginx installed
# e.g. uv tool install flask-nginx
bg-service:
	footprint config template -o emma-annotator.service etc/emma-annotator.service \
		appname=emmaserver port=9998 julia-dir="$(JULIADIR)" threads=8 watch=$(TEMPDIR) max-days=30 \
		annotator-dir=. depot-path=$(JULIA_DEPOT_PATH)

# easily terminate the julia server
terminate:
	@/usr/bin/curl --silent http://127.0.0.1:9998/terminate

# run this to install all dependencies in the current environment
instantiate:
	@$(JULIADIR)/bin/julia --project=. -e 'using Pkg; Pkg.instantiate()'

.PHONY: service terminate instantiate
