_build:
	mkdir $@
deps:
	mkdir $@

_build/%.lua: %.fnl _build
	fennel --compile $< > $@

_build/fennelview.lua:
	curl https://raw.githubusercontent.com/bakpakin/Fennel/master/fennelview.fnl.lua -o $@

_build/bin: _build/plaindb.lua _build/humantime.lua _build/main.lua deps/date.lua deps/argparse.lua deps/moses.lua _build/fennelview.lua
	cp -r deps _build/
	luac -o $@ $^

deps/date.lua: deps
	curl https://raw.githubusercontent.com/Tieske/date/master/src/date.lua -o $@

deps/argparse.lua: deps
	curl https://raw.githubusercontent.com/mpeterv/argparse/master/src/argparse.lua -o $@

deps/moses.lua: deps
	curl https://raw.githubusercontent.com/Yonaba/Moses/master/moses.lua -o $@

# export LUA_CPATH='/Users/martinklepsch/.luarocks/lib/lua/5.3/?.so;/usr/local/lib/lua/5.3/?.so;/usr/local/lib/lua/5.3/loadall.so;./?.so'
# export PATH='/Users/martinklepsch/.luarocks/bin:/usr/local/bin:/Users/martinklepsch/code/08-go/bin:/Users/martinklepsch/.bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/MacGPG2/bin'
