IMAGE ?= ghcr.io/ai-bug-bounty/runtime-base
TAG ?= local
BUILD_ARGS ?=

.DEFAULT_GOAL := help

.PHONY: help build test push pull shell clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | sort \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

build: ## Build the image (IMAGE, TAG, BUILD_ARGS)
	docker build $(BUILD_ARGS) -t $(IMAGE):$(TAG) .

test: ## Smoke-test a built image (IMAGE, TAG)
	./scripts/smoke-test.sh $(IMAGE):$(TAG)

push: ## Push the image (IMAGE, TAG)
	docker push $(IMAGE):$(TAG)

pull: ## Pull the image (IMAGE, TAG)
	docker pull $(IMAGE):$(TAG)

shell: ## Interactive shell (privileged, with a nested Docker daemon)
	docker run --rm -it --privileged -v /var/lib/docker $(IMAGE):$(TAG) bash

clean: ## Remove the local image (IMAGE, TAG)
	-docker image rm $(IMAGE):$(TAG)
