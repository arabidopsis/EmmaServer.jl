SHELL=/bin/bash
JULIADIR=`julia -e 'print(Sys.BINDIR)'`/..
TEMPDIR=`realpath ../emma-website/instance/datadir`
# requires a python environment with footprint installed
service:
	footprint config template -o emma-annotator.service --user etc/emma-annotator.service venv=unused appname=emma julia-dir="$(JULIADIR)" workers=4 watch=$(TEMPDIR)
