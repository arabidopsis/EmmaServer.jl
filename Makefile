SHELL=/bin/bash
JULIADIR=`julia -e 'print(Sys.BINDIR)'`/..
INSTANCE=`realpath ../emma-website/instance`
# requires uv to be installed
systemd:
	uv run --with=flask-nginx footprint config template -o emma-annotator.service etc/emma-annotator.service \
		appname=emmaserver port=9998 julia-dir="$(JULIADIR)" annotator-dir=. depot-path=$(JULIA_DEPOT_PATH) \
		instance="$(INSTANCE)" max-days=30 max-mb=500 sleep-days=3
install:
	uv run --with=flask-nginx footprint config systemd-install emma-annotator.service
uninstall:
	uv run --with=flask-nginx footprint config systemd-uninstall emma-annotator.service
# easily terminate the julia server
terminate:
	# killall -s SIGHUP emma-server
	@/usr/bin/curl --silent http://127.0.0.1:9998/terminate

# run this to install all dependencies in the current environment
instantiate:
	@$(JULIADIR)/bin/julia --project=. -e 'using Pkg; Pkg.instantiate()'

resolve:
	@$(JULIADIR)/bin/julia --project=. -e 'using Pkg; Pkg.resolve()'

.PHONY: systemd terminate instantiate resolve install uninstall
