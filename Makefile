# Multi-arch docker container instance of the open-source Fledge project intended for Open Horizon Linux edge nodes

export DOCKER_HUB_ID ?= itzg
export HZN_ORG_ID ?= examples

export SERVICE_NAME ?= service-minecraft
export SERVICE_VERSION ?= 0.0.2
export SERVICE_ORG_ID ?= $(HZN_ORG_ID)
export PATTERN_NAME ?= pattern-fledge

# Don't allow the ARCH to be overridden at this time since only arm64 supported today
export ARCH := amd64
export DOCKER_IMAGE_BASE ?= $(DOCKER_HUB_ID)/minecraft-server
export DOCKER_IMAGE_VERSION ?= latest

# Minecraft customizations
export MINECRAFT_SERVER_PORT ?= 25565
export MINECRAFT_RCON_PORT ?= 25575
export MINECRAFT_VOLUME_NAME ?= minecraft-data
export EULA ?= TRUE
export MEMORY ?= 2G
export TYPE ?= SPIGOT
export VERSION ?= 1.19

# Detect Operating System running Make
OS := $(shell uname -s)

default: run

init:
# possibly @docker volume create ...

build:
	@echo build is not needed since we are using a 3rd party image

push:
	@echo push is not needed since build includes push

clean:
	-docker rmi $(DOCKER_IMAGE_BASE):$(DOCKER_IMAGE_VERSION) 2> /dev/null || :
	@docker volume rm $(MINECRAFT_VOLUME_NAME)

distclean: agent-stop remove-deployment-policy remove-service-policy remove-service clean

stop:
	@docker exec `docker ps -aqf "name=$(SERVICE_NAME)"` rcon-cli stop
	@docker rm -f $(SERVICE_NAME) >/dev/null 2>&1 || :

run:
	@docker run -d \
		--name $(SERVICE_NAME) \
		--volume "$(MINECRAFT_VOLUME_NAME):/data:rw" \
		-p $(MINECRAFT_SERVER_PORT):25565 \
		-e EULA=$(EULA) \
		-e MEMORY=$(MEMORY) \
		-e TYPE=$(TYPE) \
		-e VERSION=$(VERSION) \
		$(DOCKER_IMAGE_BASE):$(DOCKER_IMAGE_VERSION)

attach: 
	@docker exec -it \
		`docker ps -aqf "name=$(SERVICE_NAME)"` \
		/bin/bash		

dev: run attach

test:
	@curl -sS http://127.0.0.1:$(MINECRAFT_SERVER_PORT)/

publish: publish-service publish-service-policy publish-deployment-policy agent-run

publish-service:
	@echo "=================="
	@echo "PUBLISHING SERVICE"
	@echo "=================="
	@hzn exchange service publish -O -P --json-file=horizon/service.definition.json
	@echo ""

remove-service:
	@echo "=================="
	@echo "REMOVING SERVICE"
	@echo "=================="
	@hzn exchange service remove -f $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$(ARCH)
	@echo ""

publish-service-policy:
	@echo "========================="
	@echo "PUBLISHING SERVICE POLICY"
	@echo "========================="
	@hzn exchange service addpolicy -f horizon/service.policy.json $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$(ARCH)
	@echo ""

remove-service-policy:
	@echo "======================="
	@echo "REMOVING SERVICE POLICY"
	@echo "======================="
	@hzn exchange service removepolicy -f $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$(ARCH)
	@echo ""

publish-deployment-policy:
	@echo "============================"
	@echo "PUBLISHING DEPLOYMENT POLICY"
	@echo "============================"
	@hzn exchange deployment addpolicy -f horizon/deployment.policy.json $(HZN_ORG_ID)/policy-$(SERVICE_NAME)_$(SERVICE_VERSION)
	@echo ""

remove-deployment-policy:
	@echo "=========================="
	@echo "REMOVING DEPLOYMENT POLICY"
	@echo "=========================="
	@hzn exchange deployment removepolicy -f $(HZN_ORG_ID)/policy-$(SERVICE_NAME)_$(SERVICE_VERSION)
	@echo ""

agent-run:
	@echo "================"
	@echo "REGISTERING NODE"
	@echo "================"
	@hzn register -v --policy=horizon/node.policy.json
	@watch hzn agreement list

agent-stop:
	@echo "==================="
	@echo "UN-REGISTERING NODE"
	@echo "==================="
	@docker exec `docker ps -aqf "name=$(SERVICE_NAME)"` rcon-cli stop
	@hzn unregister -f
	@echo ""

deploy-check:
	@hzn deploycheck all -t device -B horizon/deployment.policy.json --service=horizon/service.definition.json --service-pol=horizon/service.policy.json --node-pol=horizon/node.policy.json

log:
	@echo "========="
	@echo "EVENT LOG"
	@echo "========="
	@hzn eventlog list
	@echo ""
	@echo "==========="
	@echo "SERVICE LOG"
	@echo "==========="
	@hzn service log -f $(SERVICE_NAME)

.PHONY: build clean distclean init default stop run dev attach test push publish publish-service publish-service-policy publish-deployment-policy agent-run distclean deploy-check log remove-deployment-policy remove-service-policy remove-service