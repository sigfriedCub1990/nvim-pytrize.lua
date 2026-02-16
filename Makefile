PLENARY_DIR := /tmp/plenary.nvim

$(PLENARY_DIR):
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY_DIR)

.PHONY: test
test: $(PLENARY_DIR)
	nvim --headless --noplugin \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/pytrize/ {minimal_init = 'tests/minimal_init.lua'}"
