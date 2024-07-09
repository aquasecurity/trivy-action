.PHONY: test

test:
	BATS_LIB_PATH=/usr/local/lib/ bats --recursive --timing --verbose-run .
