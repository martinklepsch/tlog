_build/%.lua: %.fnl
	fennel --compile $< > $@

_build/tt.lua: tt.lua
	cp $< $@
