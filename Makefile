OS := $(shell uname)

ifeq ($(OS), Darwin)
  SED = gsed
  BATS_LIB_PATH ?= /opt/homebrew/lib
else
  SED = sed
  BATS_LIB_PATH ?= /usr/local/lib/
endif

LOCAL_BIN := $(CURDIR)/.bin
LOCAL_TRIVY := $(LOCAL_BIN)/trivy

ifeq ($(shell [ -f $(LOCAL_TRIVY) ] && [ -z "$(CI)" ] && echo yes),yes)
TRIVY_CMD := $(LOCAL_TRIVY)
else
TRIVY_CMD ?= trivy
endif

CACHE_DIR := '.cache'

TRIVY_VERSION_FILE := .github/workflows/test.yaml
CURRENT_TRIVY_VERSION := $(shell awk '/TRIVY_VERSION:/ {print $$2}' $(TRIVY_VERSION_FILE))

BATS_ENV := BATS_LIB_PATH=$(BATS_LIB_PATH) \
	GITHUB_REPOSITORY_OWNER=aquasecurity \
	TRIVY_CACHE_DIR=$(CACHE_DIR) \
	TRIVY_DEBUG=true

BATS_FLAGS := --timing --verbose-run test/test.bats

.PHONY: test
test:
	TRIVY_CMD=$(TRIVY_CMD) $(BATS_ENV) bats $(BATS_FLAGS)

.PHONY: update-golden
update-golden:
	UPDATE_GOLDEN=1 TRIVY_CMD=$(TRIVY_CMD) $(BATS_ENV) bats $(BATS_FLAGS)

.PHONY: init-cache
init-cache:
	mkdir -p $(CACHE_DIR)

.PHONY: clean-cache
clean-cache:
	$(TRIVY_CMD) clean --scan-cache --cache-dir $(CACHE_DIR)

bump-trivy:
	@[ $$NEW_VERSION ] || ( echo "env 'NEW_VERSION' is not set"; exit 1 )
	@echo Current version: $(CURRENT_TRIVY_VERSION) ;\
	echo New version: $$NEW_VERSION ;\
	$(SED) -i -e "s/$(CURRENT_TRIVY_VERSION)/$$NEW_VERSION/g" \
		README.md action.yaml $(TRIVY_VERSION_FILE)

.PHONY: ensure-trivy
ensure-trivy:
	@set -e; \
	mkdir -p $(LOCAL_BIN); \
	if [ -x $(LOCAL_TRIVY) ]; then \
		CURRENT_VERSION="$$( $(LOCAL_TRIVY) version -f json | jq -r '.Version' )"; \
	else \
		CURRENT_VERSION=none; \
	fi; \
	echo "Required: $(CURRENT_TRIVY_VERSION)"; \
	echo "Current:  $$CURRENT_VERSION"; \
	if [ "$$CURRENT_VERSION" != "$(CURRENT_TRIVY_VERSION)" ]; then \
		echo "Installing Trivy $(CURRENT_TRIVY_VERSION) locally..."; \
		curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | \
		sh -s -- -b $(LOCAL_BIN) v$(CURRENT_TRIVY_VERSION); \
	else \
		echo "Trivy $(CURRENT_TRIVY_VERSION) already present."; \
	fi