FROM ghcr.io/aquasecurity/trivy:0.53.0
COPY entrypoint.sh /
RUN apk --no-cache add bash curl npm
RUN chmod +x /entrypoint.sh
ENV TRIVY_CACHE_DIR=/root/.cache/trivy
RUN mkdir -p $TRIVY_CACHE_DIR
RUN trivy image --download-db-only
ENTRYPOINT ["/entrypoint.sh"]