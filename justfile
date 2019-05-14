# Local Variables:
# mode: makefile
# End:
# vim: set ft=make :
# description: build or run or lint
# https://github.com/casey/just

# build and run
run: build
  ./fff

# build
build:
  #!/usr/bin/env bash
  SRC=src/fff.cr
  TGT=./fff
  if [[ $SRC -nt $TGT ]]; then
    time crystal build src/fff.cr
  else
    echo Nothing to do. $TGT uptodate.
  fi

lint:
  ameba

log:
  most ~/tmp/fff.log

install:
  crystal build src/fff.cr --release
  cp fff ~/bin
