FROM rahul23/trivy:0.18.1
COPY entrypoint.sh /
RUN apk --no-cache add bash
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]