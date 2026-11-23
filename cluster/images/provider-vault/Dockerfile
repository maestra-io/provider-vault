FROM packages.maestra.io/gcr/distroless/static-debian13:nonroot@sha256:aafe993665bf6200db38a02c11a9351e782a84b6a45e7f33b6695638c88e3931

ARG TARGETOS
ARG TARGETARCH
ARG IMAGE_REVISION=dev

# OCI image labels — ECR uses these for cosign verify and provenance UIs.
LABEL org.opencontainers.image.source="https://github.com/maestra-io/provider-vault" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.version="${IMAGE_REVISION}" \
      org.opencontainers.image.licenses="Apache-2.0"

COPY _output/${TARGETOS}_${TARGETARCH}/provider /usr/local/bin/provider

USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/provider"]
