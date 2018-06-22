all: build

ADMIN       ?= admin
PASS        ?= test123
URL         ?= https://zmc-proxy:7071/service/admin/soap
SHELL       = bash
ORG         ?= zimbra
TAG         ?= latest
IMG         = "${ORG}/zm-zcs-test:${TAG}"
STACK_NAME  ?= zm-test


build: .secrets/env.prop .config/users.csv .env .image.tag logs

force-build: .env
	rm .image.tag
	make build

.image.tag:
	IMG=${IMG} \
	docker-compose build
	@echo "${IMG}" > .image.tag

clean: down
	rm -r .env .image.tag .secrets .config

down:
	IMG="${IMG}" \
        docker stack rm '${STACK_NAME}'
	rm -f .up.lock

logs: 
	mkdir -p logs

up: .up.lock

.up.lock:
	IMG="${IMG}" \
	docker stack deploy -c docker-compose.yml '${STACK_NAME}'
	touch .up.lock

.env:
	cat DOT-env > .env

.secrets/.init:
	mkdir .secrets
	touch "$@"

.secrets/env.prop: .secrets/.init
	bin/env -a ${ADMIN} -p ${PASS} -u ${URL} >$@

.config/.init:
	mkdir .config
	touch "$@"

.config/users.csv: .config/.init
	bin/users -a perf -n 1 >$@
