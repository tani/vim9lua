NVIM ?= .deps/nvim-linux-x86_64/bin/nvim
.PHONY: bootstrap inventory fixtures reference differential selftest m0
bootstrap:
	./scripts/bootstrap.sh
inventory:
	$(NVIM) --headless -u NONE -l scripts/m0.lua inventory
fixtures:
	$(NVIM) --headless -u NONE -l scripts/m0.lua fixture
reference:
	$(NVIM) --headless -u NONE -l scripts/m0.lua reference
differential:
	$(NVIM) --headless -u NONE -l scripts/m0.lua differential
selftest:
	$(NVIM) --headless -u NONE -l scripts/m0.lua selftest
m0:
	$(NVIM) --headless -u NONE -l scripts/m0.lua all
