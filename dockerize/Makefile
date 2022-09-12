#!/usr/bin/env bash

.PHONY: strip build-only\
	build\
	docker-build\
	docker-run\
	docker-build-run\
	compose-up\
	compose-down\
	docker-compose\
	docker-compose-rebuild

SHELL=/bin/bash

export $(shell [ ! -n "$(ENVFILE)" ] || cat $(ENVFILE) | grep -v --perl-regexp '^('$$(env | sed 's/=.*//'g | tr '\n' '|')')\=')

APPLICATION := $(shell echo "dockerize")
ORGANIZATION := $(shell echo "stack.io")
GOOS := $(shell uname | tr '[:upper:]' '[:lower:]')
REGISTRY := $(shell echo "$(ORGANIZATION)/$(APPLICATION)")
TAG := $(shell echo "latest")

# Go Build Locally
strip:
	upx --brute $(APPLICATION)-$(GOOS)-amd64

build-only:
	go build -a -ldflags '-s -w' -o $(APPLICATION)-$(GOOS)-amd64

build: build-only strip

# Docker Container Build
docker-build:
	docker build  -f "Dockerfile" -t $(REGISTRY):$(TAG) --no-cache --progress=plain --build-arg APPLICATION=$(APPLICATION) .

docker-run:
	docker run -i -t --rm --name=$(APPLICATION) -h $(APPLICATION) -p 8080:8080 $(REGISTRY):$(TAG)

docker-build-run: docker-build docker-run

# Docker Compose
docker-compose: compose-up

compose-up:
	docker-compose -f "docker-compose.yml" up -d --build --remove-orphans --force-recreate

compose-down:
	docker-compose -f "docker-compose.yml" down

docker-compose-rebuild: docker-build docker-compose
