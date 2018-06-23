all: build

USERARGS    ?= -a perf -n 1
ADMIN       ?= admin
PASS        ?= test123
URL         ?= https://zmc-proxy:7071/service/admin/soap
SHELL       = bash
ORG         ?= zimbra
TAG         ?= latest
IMG         = "${ORG}/zm-zcs-test:${TAG}"
STACK_NAME  ?= zm-test


build: .secrets/env.prop .config/users.csv .image.tag logs

.image.tag:
	IMG=${IMG} \
	docker-compose build
	@echo "${IMG}" > .image.tag

clean: down
	rm -f .image.tag
	rm -rf .secrets
	rm -rf .config

down:
	IMG="${IMG}" \
        docker-compose down
#       docker stack rm '${STACK_NAME}'
	rm -f .up.lock

logs: 
	mkdir -p logs

up: .up.lock

.up.lock:
	IMG="${IMG}" \
	docker-compose up -d
#	docker stack deploy -c docker-compose.yml '${STACK_NAME}'
	touch .up.lock

.secrets/.init:
	mkdir -p .secrets
	touch "$@"

.secrets/env.prop: .secrets/.init
	bin/env -a ${ADMIN} -p ${PASS} -u ${URL} >$@

.config/.init:
	mkdir -p .config
	touch "$@"

.config/users.csv: .config/.init
	bin/users ${USERARGS} >$@
