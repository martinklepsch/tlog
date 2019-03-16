# tlog

A tiny toy application for tracking time from the CLI written in [fennel](https://fennel-lang.org).

Usage:

```sh
touch timelogs.txt
export TLOG_FILE=timelogs.txt

./main.fnl --help          # get help
./main.fnl sheet project   # switch to a project
./main.fnl in              # start the timer
./main.fnl out             # stop the timer
./main.fnl display         # show a list of tracked entries
./main.fnl status          # minimal info for use in prompts etc
./main.fnl backend         # open data file in $EDITOR
```

**`fennelview.lua` not found?**: run `make _build/fennelview.lua; cp _build/fennelview.lua .`. I remember this being provided automatically but somehow that changed at some point (likely entirely my fault).

Making an exectuable in `_build/`:
```sh
make _build/t
./_build/t
```
