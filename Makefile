SHELL=/bin/bash
JULIADIR=`julia -e 'print(Sys.BINDIR)'`/..
TEMPDIR=`realpath ../emma-website/instance/datadir`
# requires a python environment with footprint installed
service:
	footprint config template -o emma-annotator.service --user etc/emma-annotator.service venv=unused appname=emma julia-dir="$(JULIADIR)" workers=4 watch=$(TEMPDIR)

# easily terminate the julia server
terminate:
	#@wget -q -O- http://127.0.0.1:9998/terminate
	@/usr/bin/curl --silent http://127.0.0.1:9998/terminate

.PHONY: service terminate
