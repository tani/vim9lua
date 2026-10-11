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
.PHONY: m12 m12-fixtures regression-fixtures regression unit error-actions test
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
error-actions:
	$(NVIM) --headless -u NONE -l tests/error-actions.lua
	$(NVIM) --headless -u NONE -l scripts/error-actions.lua
test: unit conformance-unit error-actions selftest differential m12 regression m3

.PHONY: m3 m3-fixtures
m3-fixtures:
	$(NVIM) --headless -u NONE -l scripts/m3-fixtures.lua
m3: m3-fixtures
	$(NVIM) --headless -u NONE -l scripts/m0.lua m3

.PHONY: discover progress progress-check conformance-unit assess
discover:
	$(NVIM) --headless -u NONE -l scripts/discover.lua
progress:
	$(NVIM) --headless -u NONE -l scripts/progress.lua
progress-check:
	$(NVIM) --headless -u NONE -l scripts/progress.lua --strict
conformance-unit:
	$(NVIM) --headless -u NONE -l tests/conformance.lua
assess:
	$(MAKE) inventory
	$(MAKE) discover
	$(MAKE) reference
	$(MAKE) test
	$(MAKE) progress-check
	$(MAKE) progress-integration

.PHONY: progress-integration
progress-integration:
	$(NVIM) --headless -u NONE -l tests/progress-integration.lua
