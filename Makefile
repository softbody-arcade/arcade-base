.PHONY: test hooks privacy doctor version

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
