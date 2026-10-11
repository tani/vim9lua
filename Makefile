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
.PHONY: m12 m12-fixtures regression-fixtures regression unit test
m12-fixtures:
	$(NVIM) --headless -u NONE -l scripts/fixtures.lua
regression-fixtures:
	$(NVIM) --headless -u NONE -l scripts/regression-fixtures.lua
m12: m12-fixtures
	$(NVIM) --headless -u NONE -l scripts/m0.lua m12
regression: regression-fixtures
	$(NVIM) --headless -u NONE -l scripts/m0.lua regression
unit:
	$(NVIM) --headless -u NONE -l tests/unit.lua
test: unit selftest differential m12 regression m3

.PHONY: m3 m3-fixtures
m3-fixtures:
	$(NVIM) --headless -u NONE -l scripts/m3-fixtures.lua
m3: m3-fixtures
	$(NVIM) --headless -u NONE -l scripts/m0.lua m3
