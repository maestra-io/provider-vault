FROM packages.maestra.io/gcr/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab

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
