IMAGE_NAME := pepelepew-os
GH_REPO := stevendpclark/${IMAGE_NAME}
REGISTRY_IMAGE := ghcr.io/${GH_REPO}
UPSTREAM_VER := 39
UPSTREAM_SOURCE_IMAGE := silverblue
UPSTREAM_SOURCE_ORG := fedora-ostree-desktops
UPSTREAM_IMAGE := quay.io/${UPSTREAM_SOURCE_ORG}/${UPSTREAM_SOURCE_IMAGE}

REQUIRED_TOOLS := skopeo jq buildah

$(foreach bin,$(REQUIRED_TOOLS),\
	$(if $(shell command -v $(bin) 2> /dev/null),,$(error Required tool `$(bin)` is missing)))

ifeq (${UPSTREAM_CONTAINER_VERSION},)
.PHONY: upstream_info
upstream_info: 
	$(eval TMP := $(shell mktemp))
	$(shell skopeo inspect docker://${UPSTREAM_IMAGE}:${UPSTREAM_VER} > ${TMP})  
	$(eval UPSTREAM_CONTAINER_VERSION := $(shell jq -r '.Labels["org.opencontainers.image.version"]' ${TMP}))
	$(eval UPSTREAM_CONTAINER_TAG := $(shell jq -r '.RepoTags[]|select(startswith("${UPSTREAM_CONTAINER_VERSION}"))' ${TMP}))
	@rm -rf ${TMP}
else
.PHONY: upstream_info
upstream_info: 
endif

.PHONY: all
all: echo_upstream_info
	
.PHONY: echo_upstream_info
echo_upstream_info: upstream_info
	@echo "Upstream version: ${UPSTREAM_CONTAINER_VERSION}"
	@echo "Upstream tag: ${UPSTREAM_CONTAINER_TAG}"

.PHONY: ci_upstream_info
ci_upstream_info: upstream_info
	@echo "UPSTREAM_CONTAINER_VERSION=${UPSTREAM_CONTAINER_VERSION}"
	@echo "UPSTREAM_CONTAINER_TAG=${UPSTREAM_CONTAINER_TAG}"

.PHONY: pull_upstream_image
pull_upstream_image: upstream_info
	buildah pull "${UPSTREAM_IMAGE}:${UPSTREAM_CONTAINER_TAG}"

.PHONY: build_image
build_image: echo_upstream_info
	buildah build \
		--build-arg SOURCE_IMAGE=${UPSTREAM_SOURCE_IMAGE} \
		--build-arg SOURCE_ORG=${UPSTREAM_SOURCE_ORG} \
		--build-arg BASE_IMAGE=${UPSTREAM_IMAGE} \
		--build-arg BASE_TAG=${UPSTREAM_CONTAINER_TAG} \
		--build-arg FEDORA_MAJOR_VERSION=${UPSTREAM_CONTAINER_VERSION} \
		--annotation org.opencontainers.image.title="${IMAGE_NAME}" \
		--annotation org.opencontainers.image.version="${UPSTREAM_CONTAINER_VERSION}" \
		--annotation org.opencontainers.image.description="A customized Fedora Silverblue image" \
		--annotation io.artifacthub.package.readme-url="https://raw.githubusercontent.com/${GH_REPO}/main/README.md" \
		--tag ${REGISTRY_IMAGE}:${UPSTREAM_CONTAINER_VERSION}

.PHONY: publish_image
publish_image: upstream_info
	@echo "Publishing ${REGISTRY_IMAGE}:${UPSTREAM_CONTAINER_VERSION}"
	buildah push ${REGISTRY_IMAGE}:${UPSTREAM_CONTAINER_VERSION}

.PHONY: require_cosign
require_cosign:
	$(if $(shell command -v cosign 2> /dev/null),,$(error Required tool 'cosign' is missing))

.PHONY: lookup_sha
lookup_sha: upstream_info
	$(eval IMAGE_SHA:=$(shell buildah images \
		--noheading \
		--no-trunc \
		--format '{{.ID}}' \
		${REGISTRY_IMAGE}:${UPSTREAM_CONTAINER_VERSION}))

.PHONY: sign_image
sign_image: require_cosign upstream_info lookup_sha
	cosign sign \
		--yes=true \
		--key env://COSIGN_PRIVATE_KEY \
		--annotations='tag=${UPSTREAM_CONTAINER_VERSION}' \
		${REGISTRY_IMAGE}@${IMAGE_SHA}

.PHONY: verify_signed_image
verify_signed_image: require_cosign upstream_info lookup_sha
	cosign verify \
		--key cosign.pub \
		--annotations='tag=${UPSTREAM_CONTAINER_VERSION}' \
		${REGISTRY_IMAGE}@${IMAGE_SHA}

