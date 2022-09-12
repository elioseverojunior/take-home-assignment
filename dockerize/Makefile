#!/usr/bin/env bash

.PHONY: strip build-only\
	build\
	compose-down\
	compose-up\
	docker-build-run\
	docker-build\
	docker-build\
	docker-compose-rebuild\
	docker-compose\
	docker-push\
	docker-run\
	;

SHELL=/bin/bash

export $(shell [ ! -n "$(ENVFILE)" ] || cat $(ENVFILE) | grep -v --perl-regexp '^('$$(env | sed 's/=.*//'g | tr '\n' '|')')\=')

APPLICATION := $(shell echo "dockerize")
ORGANIZATION := $(shell echo "elioseverojunior")
GOOS := $(shell uname | tr '[:upper:]' '[:lower:]')
GOARCH := $(shell echo "amd64")
HTTP_PORT := $(shell echo "8080")
#GOARCH := $(shell echo $(case $(uname -m) in\
#                                         i386)   GOARCH="386" ;;\
#                                         i686)   GOARCH="386" ;;\
#                                         x86_64) GOARCH="amd64" ;;\
#                                         arm)    dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="arm" ;;\
#                                         ;;\
#                                     esac))
REGISTRY := $(shell echo "$(ORGANIZATION)/$(APPLICATION)")
TAG := $(shell echo "macbook")

# Go Build Locally
strip:
	upx --brute $(APPLICATION)-$(GOOS)-$(GOARCH)

build-only:
	go build -a -ldflags '-s -w' -o $(APPLICATION)-$(GOOS)-$(GOARCH)

build: build-only strip

# Docker Container Build
docker-build:
	docker build  -f "Dockerfile" -t $(REGISTRY):$(TAG) --no-cache --progress=plain --build-arg APPLICATION=$(APPLICATION) .

docker-run:
	docker run -i -t --rm --name=$(APPLICATION) -h $(APPLICATION) -p $(HTTP_PORT):8080 $(REGISTRY):$(TAG)

docker-build-run: docker-build docker-run

# Docker Compose
docker-compose: compose-up

compose-up:
	docker-compose -f "docker-compose.yml" up -d --build --remove-orphans --force-recreate

compose-down:
	docker-compose -f "docker-compose.yml" down

docker-compose-rebuild: docker-build docker-compose

docker-push:
	docker push $(REGISTRY):$(TAG)

docker-build-push: docker-build docker-push
