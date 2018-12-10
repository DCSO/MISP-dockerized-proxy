FROM nginx:stable-alpine


#     Variables for Labels:
ARG VENDOR="DCSO GmbH"
ARG COMPONENT="proxy"
ARG BUILD_DATE
ARG GIT_REPO
ARG VCS_REF
ARG VERSION
ARG RELEASE_DATE
ARG NAME="MISP-dockerized-${COMPONENT}"
ARG DESCRIPTION="This docker container is part of the DCSO MISP dockerized environment."
ARG DOCUMENTATION="https://github.com/DCSO/MISP-dockerized"
ARG AUTHOR="DCSO MISP Docker Team <misp.docker@dcso.de>"
ARG LICENSE="BSD-3-Clause"
#     END Variables

#########################################
LABEL org.label-schema.build-date="${BUILD_DATE}" \
        org.label-schema.name="${NAME}" \
        org.label-schema.description="${DESCRIPTION}" \
        org.label-schema.vcs-ref="${VCS_REF}" \
        org.label-schema.vcs-url="${GIT_REPO}" \
        org.label-schema.url="${GIT_REPO}" \
        org.label-schema.vendor="${VENDOR}" \
        org.label-schema.version="${VERSION}" \
        org.label-schema.usage="${DOCUMENTATION}" \
        org.label-schema.schema-version="1.0.0-rc1"

LABEL   org.opencontainers.image.created="${BUILD_DATE}" \
        org.opencontainers.image.url="${GIT_REPO}" \
        org.opencontainers.image.source="${GIT_REPO}" \
        org.opencontainers.image.version="${VERSION}" \
        org.opencontainers.image.revision="${VCS_REF}" \
        org.opencontainers.image.vendor="${VENDOR}" \
        org.opencontainers.image.title="${NAME}" \
        org.opencontainers.image.description="${DESCRIPTION}" \
        org.opencontainers.image.documentation="${DOCUMENTATION}" \
        org.opencontainers.image.authors="${AUTHOR}" \
        org.opencontainers.image.licenses="${LICENSE}"
#########################################


# Install Curl for Healthcheck
RUN apk add --no-cache \
    curl \
    openssl

# Copy the NGINX configs
COPY files/nginx/conf.d/* /etc/nginx/conf.d/
# COPY Entrypoint script
COPY files/entrypoint_nginx.sh /
RUN chmod +x /entrypoint_nginx.sh

# rename orig nginx.conf && place own nginx.conf
RUN mv /etc/nginx/nginx.conf /etc/nginx/nginx.orig \
    && ln -s /etc/nginx/conf.d/GLOBAL_nginx_common /etc/nginx/nginx.conf \
    && rm -f /etc/nginx/conf.d/default.conf

# create self signed cert
RUN mkdir -p /etc/nginx/ssl;

# Environment Variable for Proxy
ENV HTTP_PROXY=""
ENV HTTPS_PROXY=""
ENV NO_PROXY="0.0.0.0"
# Environment Variable to check Version
ENV NAME ${NAME}
ENV VERSION ${VERSION}
ENV RELEASE_DATE ${RELEASE_DATE}

# Add Healthcheck Config
HEALTHCHECK --interval=2m --timeout=15s --retries=3 CMD curl -fk https://localhost/ || exit 1


ENTRYPOINT [ "/entrypoint_nginx.sh" ]