SHELL=/bin/bash

.PHONY: changelog release publish-release latest latest-git-short-hash next-version pre-commit

REGEX := ^v([0-9]{1,}\.){2}[0-9]{1,}$$
DEFAULT_BRANCH := $(shell git remote show origin | grep 'HEAD branch' | cut -d' ' -f5 2>/dev/null)
LATEST_VERSION := $(shell git --no-pager tag --sort=committerdate | grep -E '^v[0-9]' | sort -V | tail -1 2>/dev/null)
LATEST_GIT_TAG_SHORT_HASH := $(shell git rev-list -n 1 ${LATEST_VERSION} --abbrev-commit 2>/dev/null)
NEXT_VERSION := $(shell semtag final -s minor -o)
PWD := $(shell pwd)
ENVIRONMENT := dev

ifeq ($(LATEST_GIT_TAG_SHORT_HASH), $(shell git rev-parse --short HEAD))
  NEXT_GIT_TAG:=$(LATEST_VERSION)
else
  NEXT_GIT_TAG:=$(shell semtag final -s minor -o)
endif

changelog: pre-commit
	@git-chglog -o CHANGELOG.md --next-tag ${NEXT_VERSION}

release:
	@echo "Release/Tag: ${NEXT_GIT_TAG}"
	@git tag ${NEXT_GIT_TAG} -a -m 'Created ${NEXT_GIT_TAG}'
	@git branch releases/${NEXT_GIT_TAG}

publish-release:
	@git push origin $(LATEST_VERSION)
	@git push origin -u releases/$(LATEST_VERSION)
	@gh release create $(LATEST_VERSION) --generate-notes

# delete-current-release:
# 	@git branch -D releases/$(LATEST_VERSION)
# 	@git tag --delete $(LATEST_VERSION)
# 	@git push origin -d $(LATEST_VERSION)
# 	@git push origin -d releases/$(LATEST_VERSION)
# 	@gh release delete $(LATEST_VERSION) -y

pre-commit:
	@pre-commit run --all

latest:
	@echo "${LATEST_VERSION}"

latest-git-short-hash:
	@echo "${LATEST_GIT_TAG_SHORT_HASH}"

next-version:
	@echo "${NEXT_VERSION}"
