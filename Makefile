.PHONY: test hooks privacy doctor

test:
	python3 -I tests/privacy_check_test.py
	bash tests/board_test.sh
	bash tests/doctor_test.sh

doctor:
	scripts/doctor

privacy:
	scripts/privacy-check tree HEAD

hooks:
	git config core.hooksPath .githooks
