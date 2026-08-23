SHELL=/bin/bash
JULIADIR=`julia -e 'print(Sys.BINDIR)'`/..
INSTANCE=`realpath ../emma-website/instance`
# requires uv to be installed
service:
	uv run --with=flask-nginx footprint config template -o emma-annotator.service etc/emma-annotator.service \
		appname=emmaserver port=9998 julia-dir="$(JULIADIR)" instance="$(INSTANCE)" max-days=30 \
		annotator-dir=. depot-path=$(JULIA_DEPOT_PATH)

# easily terminate the julia server
terminate:
	# killall -s SIGHUP emma-server
	@/usr/bin/curl --silent http://127.0.0.1:9998/terminate

# run this to install all dependencies in the current environment
instantiate:
	@$(JULIADIR)/bin/julia --project=. -e 'using Pkg; Pkg.instantiate()'

resolve:
	@$(JULIADIR)/bin/julia --project=. -e 'using Pkg; Pkg.resolve()'

.PHONY: service terminate instantiate resolve
