.PHONY: test

test:
	BATS_LIB_PATH=/usr/local/lib/ bats --recurisve --timing --verbose-run .