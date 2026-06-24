FROM gcr.io/distroless/static-debian12:nonroot

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
