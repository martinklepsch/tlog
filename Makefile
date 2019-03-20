_build:
	mkdir $@
deps:
	mkdir $@

_build/%.lua: %.fnl _build
	fennel --compile $< > $@

_build/fennelview.lua:
	curl https://raw.githubusercontent.com/bakpakin/Fennel/master/fennelview.fnl.lua -o $@

_build/t: _build/plaindb.lua _build/humantime.lua _build/main.lua deps/date.lua deps/argparse.lua deps/moses.lua _build/fennelview.lua bin-head
	cp -r deps _build/
	cat bin-head > $@
	cat _build/main.lua >> $@
	chmod +x $@

deps/date.lua: deps
	curl https://raw.githubusercontent.com/Tieske/date/master/src/date.lua -o $@

deps/argparse.lua: deps
	curl https://raw.githubusercontent.com/mpeterv/argparse/master/src/argparse.lua -o $@

deps/moses.lua: deps
	curl https://raw.githubusercontent.com/Yonaba/Moses/master/moses.lua -o $@

deps/ansicolors.lua: deps
	curl https://raw.githubusercontent.com/kikito/ansicolors.lua/master/ansicolors.lua -o $@

clean:
	rm -rf deps _build

.PHONY: clean
