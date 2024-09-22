OS := $(shell uname)
ifeq ($(OS), Darwin)
BATS_LIB_PATH=/opt/homebrew/lib
endif
ifeq ($(OS), Linux)
BATS_LIB_PATH=/usr/local/lib/ 
endif


.PHONY: test
test:
	mkdir -p .cache
	BATS_LIB_PATH=$(BATS_LIB_PATH) GITHUB_REPOSITORY_OWNER=aquasecurity\
	  TRIVY_CACHE_DIR=.cache TRIVY_DISABLE_VEX_NOTICE=true TRIVY_DEBUG=true\
	  bats --recursive --timing --verbose-run .
