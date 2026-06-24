# Maestra fork build (thin, self-contained — no upbound build/ submodule).
# Mirrors maestra-io/provider-cloudflare's Makefile. The Go module path stays
# github.com/upbound/provider-vault/v4 (baked into upjet-generated code); only
# the repo home and the image/xpkg registry are Maestra's.

# Project metadata
PROJECT_NAME := provider-vault
PROJECT_REPO := github.com/maestra-io/$(PROJECT_NAME)

# Versions
GO_REQUIRED_VERSION := 1.26

# Image / registry
IMAGE_REGISTRY ?= 515260921971.dkr.ecr.eu-central-1.amazonaws.com
IMAGE_NAME := $(PROJECT_NAME)
IMAGE_TAG ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
IMAGE := $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

# Tooling
GO ?= go

# Enforce the required Go major.minor at make time so a stale host toolchain
# doesn't produce a build vet/lint disagree with. Compares X.Y only.
.PHONY: check-go-version
check-go-version:
	@have=$$($(GO) env GOVERSION 2>/dev/null | sed -e 's/^go//' -e 's/[^0-9.].*//'); \
	want=$(GO_REQUIRED_VERSION); \
	if [ -z "$$have" ]; then echo "warn: could not detect Go version; required Go $$want+"; exit 0; fi; \
	if command -v python3 >/dev/null 2>&1; then \
	  python3 -c "import sys; h=tuple(int(x) for x in '$$have'.split('.')[:2]); w=tuple(int(x) for x in '$$want'.split('.')[:2]); sys.exit(0 if h>=w else 1)" || { echo "error: Go $$want+ required; have $$have"; exit 1; }; \
	else echo "warn: python3 not found; skipping Go version check (have=$$have, want=$$want+)"; fi

.PHONY: all
all: build

.PHONY: vet
vet:
	$(GO) vet ./...

.PHONY: lint
lint:
	@command -v golangci-lint >/dev/null 2>&1 || { echo "golangci-lint not installed"; exit 1; }
	golangci-lint run ./...

# This fork only adds config/database (the create-only password diff). The rest
# of the module is upstream code, tested upstream at the pinned tag, so CI tests
# our package; `make build` already gives the full-module compile signal.
.PHONY: test
test:
	$(GO) test -count=1 ./config/...

# build emits a per-arch binary so the same _output/ tree can hold linux_amd64
# and linux_arm64 in parallel — the Dockerfile picks the right one via
# TARGETOS/TARGETARCH. Defaults to the host's GOOS/GOARCH for local dev.
GOOS   ?= $(shell $(GO) env GOOS)
GOARCH ?= $(shell $(GO) env GOARCH)

.PHONY: build
build: check-go-version
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) $(GO) build \
	  -trimpath -buildvcs=auto \
	  -o _output/$(GOOS)_$(GOARCH)/provider ./cmd/provider

.PHONY: image
image: build
	docker build \
	  --build-arg TARGETOS=$(GOOS) \
	  --build-arg TARGETARCH=$(GOARCH) \
	  --build-arg IMAGE_REVISION=$(IMAGE_TAG) \
	  -t $(IMAGE) \
	  -f cluster/images/$(PROJECT_NAME)/Dockerfile .

.PHONY: image.push
image.push: image
	docker push $(IMAGE)

# image.buildx.push emits a multi-arch (linux/amd64 + linux/arm64) manifest
# list in one go. Reuses the per-arch binaries the build target produces
# (Dockerfile picks them up via TARGETOS/TARGETARCH) so the bake stays cheap.
.PHONY: image.buildx.push
image.buildx.push:
	$(MAKE) build GOOS=linux GOARCH=amd64
	$(MAKE) build GOOS=linux GOARCH=arm64
	@docker buildx inspect provider-vault-builder >/dev/null 2>&1 || \
	  docker buildx create --name provider-vault-builder --use
	docker buildx build \
	  --builder provider-vault-builder \
	  --platform linux/amd64,linux/arm64 \
	  --build-arg IMAGE_REVISION=$(IMAGE_TAG) \
	  --label org.opencontainers.image.source=$(PROJECT_REPO) \
	  --label org.opencontainers.image.revision=$(IMAGE_TAG) \
	  --label org.opencontainers.image.version=$(IMAGE_TAG) \
	  -t $(IMAGE) \
	  -f cluster/images/$(PROJECT_NAME)/Dockerfile \
	  --push \
	  .

# xpkg.build emits a real OCI-format Crossplane package via `crossplane xpkg
# build`. crossplane.yaml is templated from package/crossplane.yaml.tmpl on
# every build (the in-tree crossplane.yaml is generated, never hand-edited).
# --embed-runtime-image bakes the controller binary OCI into the xpkg so
# Crossplane v2 runs the actual provider, not the metadata-only package image.
# The runtime image must be present in the local Docker daemon, hence the
# dependency on `image` (host-arch `docker build`).
.PHONY: xpkg.build
xpkg.build: image
	@command -v crossplane >/dev/null 2>&1 || { echo "crossplane CLI not found"; exit 1; }
	@mkdir -p _output
	@sed "s|@@IMAGE@@|$(IMAGE)|g" package/crossplane.yaml.tmpl > package/crossplane.yaml
	crossplane xpkg build \
	  --package-root=package \
	  --package-file=_output/$(PROJECT_NAME)-$(IMAGE_TAG).xpkg \
	  --embed-runtime-image=$(IMAGE)

.PHONY: xpkg.push
xpkg.push: xpkg.build
	crossplane xpkg push -f _output/$(PROJECT_NAME)-$(IMAGE_TAG).xpkg $(IMAGE_REGISTRY)/$(IMAGE_NAME)-pkg:$(IMAGE_TAG)

.PHONY: clean
clean:
	rm -rf _output .work
