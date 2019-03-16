# tlog

A tiny toy application for tracking time from the CLI written in [fennel](https://fennel-lang.org).

Usage:

```sh
touch timelogs.txt
export TLOG_FILE=timelogs.txt
alias t="fennel main.fnl"

t --help          # get help
t sheet project   # switch to a project
t in              # start the timer
t out             # stop the timer
t display         # show a list of tracked entries
t status          # minimal info for use in prompts etc
t backend         # open data file in $EDITOR
```

**`fennelview.lua` not found?**: run `make _build/fennelview.lua; cp _build/fennelview.lua .`. I remember this being provided automatically but somehow that changed at some point (likely entirely my fault).

Making an exectuable in `_build/`:
```sh
make _build/t
./_build/t
```
