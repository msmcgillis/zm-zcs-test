all: build

SHELL       = bash
ORG         ?= zimbra
TAG         ?= latest
IMG			= "${ORG}/zm-zcs-test:${TAG}"


build: .env .image.tag logs

force-build: .env
	rm .image.tag
	make build

.image.tag:
	IMG=${IMG} \
	docker-compose build
	@echo "${IMG}" > .image.tag

clean: down
	rm -r .env .image.tag

down:
	IMG="${IMG}" \
	docker-compose down
	rm -f .up.lock

logs: 
	mkdir -p logs

up: .up.lock

.up.lock:
	IMG="${IMG}" \
	docker-compose up -d
	touch .up.lock

.env:
	cat DOT-env > .env


