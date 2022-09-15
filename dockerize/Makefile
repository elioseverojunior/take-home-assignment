#!/usr/bin/env bash

.PHONY:\
	build\
	compose-down\
	compose-up\
	current-branch\
	docker-build-push\
	docker-build-run\
	docker-build\
	docker-build\
	compose-rebuild\
	docker-compose\
	docker-push\
	docker-run\
  build-only\
  strip\
	;

SHELL=/bin/bash

CWD := $(shell pwd)
APPLICATION := $(shell echo "dockerize")
ORGANIZATION := $(shell echo "elioseverojunior")
PROJECT := $(shell echo "dockerize")
GOOS := $(shell uname | tr '[:upper:]' '[:lower:]')
GOARCH := $(shell echo "amd64")
COMMIT := $(shell git rev-parse HEAD)
SHORT_COMMIT := $(shell git rev-parse --short HEAD)
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
BRANCH_NAME := $(shell git name-rev --refs="refs/heads/*" --name-only $(COMMIT))
HTTP_PORT := $(shell echo "8080")
RELEASE_VERSION := 0.0.1
RELEASE := $(RELEASE_VERSION)-$(BRANCH_NAME)-$(SHORT_COMMIT)
REGISTRY := $(shell echo "$(ORGANIZATION)/$(APPLICATION)")
TAG := latest

current-branch:
	@echo $(BRANCH_NAME)

release-version:
	@echo $(RELEASE)

# Go Build Locally
strip:
	upx --brute $(APPLICATION)-$(GOOS)-$(GOARCH)

build-only:
	go build -a -ldflags '-s -w -X version.Release=${RELEASE} -X version.Commit=${COMMIT} -X version.BuildTime=${BUILD_TIME}"' -o $(APPLICATION)-$(GOOS)-$(GOARCH)

build: build-only strip

# Docker Container Build
docker-build:
	docker build  -f "Dockerfile" -t $(REGISTRY):$(TAG) --no-cache --progress=plain\
		--build-arg APPLICATION=$(APPLICATION)\
		--build-arg RELEASE=$(RELEASE)\
		--build-arg COMMIT=$(COMMIT)\
		--build-arg BUILD_TIME=$(BUILD_TIME) .\
	&& docker tag $(REGISTRY):$(TAG) $(REGISTRY):$(RELEASE)\
	&& docker tag $(REGISTRY):$(TAG) $(REGISTRY):$(BRANCH_NAME)

docker-run:
	docker run -i -t --rm --name=$(APPLICATION) -h $(APPLICATION) -p $(HTTP_PORT):8080 $(REGISTRY):$(BRANCH_NAME)

docker-build-run: docker-build docker-run

docker-push:
	docker push $(REGISTRY):$(TAG)\
	&& docker push $(REGISTRY):$(BRANCH_NAME)\
	&& docker push $(REGISTRY):$(RELEASE)

docker-build-push: docker-build docker-push

# Docker Compose
compose: compose-up

compose-down:
	docker-compose -f "docker-compose.yml" down

compose-rebuild: docker-build compose

compose-up:
	docker-compose -f "docker-compose.yml" up -d --remove-orphans --force-recreate
