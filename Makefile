.PHONY: test hooks privacy doctor version probes-check

test:
	python3 -I tests/privacy_check_test.py
	bash tests/board_test.sh
	bash tests/doctor_test.sh
	bash tests/release_test.sh

doctor:
	scripts/doctor

privacy:
	scripts/privacy-check tree HEAD

hooks:
	git config core.hooksPath .githooks

version: export RELEASE_VERSION := $(value V)
version: export RELEASE_FROM := $(value FROM)
version:
	./scripts/version.sh "$$RELEASE_VERSION"

probes-check:
	$$(command -v lua5.3 || command -v lua) probes/engine/tests/collect_test.lua
	for f in $$(find probes/engine/server -name '*.lua'); do luac -p "$$f" || exit 1; done
	for f in $$(find probes/engine/client-base probes/engine/client-game -name '*.lua'); do luajit -bl "$$f" >/dev/null || exit 1; done
	bash -n probes/engine/install.sh
	bash probes/engine/tests/install_test.sh
