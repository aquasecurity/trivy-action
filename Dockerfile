FROM ghcr.io/aquasecurity/trivy:0.29.1
COPY entrypoint.sh /
RUN apk --no-cache add bash curl
RUN chmod +x /entrypoint.sh
ADD $GITHUB_WORKSPACE /github_workspace
ENTRYPOINT ["/entrypoint.sh"]
