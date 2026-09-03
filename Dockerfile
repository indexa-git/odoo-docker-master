# odoo:master — the image Odoo does not publish.
#
# Docker Hub ships odoo:17.0, odoo:18.0, odoo:19.0 ... but nothing for the
# development series. Odoo has not branched 20.0: that work lives on `master`,
# which currently self-reports as 19.5a1. This image fills the gap so everything
# downstream can just say `FROM ghcr.io/indexa-git/odoo:master`, exactly the way
# it says `FROM odoo:19.0` on the 19.0 line.
#
# It is a faithful copy of the official odoo/docker 19.0 recipe — same base,
# same deps, same entrypoint, same layout — with one difference: the core comes
# from the master nightly .deb instead of a released one. The .deb filename and
# its sha1 are resolved from the nightly Packages index at build time rather
# than pinned, so this keeps working when master renames itself from 19.5a1 to
# 20.0a1. Pass ODOO_DEB + ODOO_SHA to pin an exact nightly.
#
# Published by .github/workflows/build.yaml as:
#   ghcr.io/indexa-git/odoo:master           moving, latest build
#   ghcr.io/indexa-git/odoo:master-<date>    immutable, for pinning
#
# Archive this repo once Odoo publishes a real odoo:20.0 image.

FROM ubuntu:noble
LABEL org.opencontainers.image.title="odoo-master"
LABEL org.opencontainers.image.description="Odoo master (future 20.0) nightly, built on the official odoo/docker 19.0 recipe"
LABEL org.opencontainers.image.source="https://github.com/indexa-git/odoo-docker-master"
LABEL org.opencontainers.image.licenses="LGPL-3.0"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

ENV LANG=en_US.UTF-8

ARG TARGETARCH

# Install some deps, lessc and less-plugin-clean-css, and wkhtmltopdf
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dirmngr \
        fonts-noto-cjk \
        gnupg \
        libssl-dev \
        node-less \
        python3-magic \
        python3-num2words \
        python3-odf \
        python3-pdfminer \
        python3-pip \
        python3-phonenumbers \
        python3-pyldap \
        python3-qrcode \
        python3-renderpm \
        python3-setuptools \
        python3-slugify \
        python3-vobject \
        python3-watchdog \
        python3-xlrd \
        python3-xlwt \
        xz-utils && \
    if [ -z "${TARGETARCH}" ]; then \
        TARGETARCH="$(dpkg --print-architecture)"; \
    fi; \
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb \
    && echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# install latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ noble-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# Install rtlcss
RUN apt-get update && \
    apt-get install -y --no-install-recommends nodejs npm \
    && npm install -g rtlcss \
    && apt-get purge --autoremove -y npm \
    && rm -rf /var/lib/apt/lists/*

# Install Odoo from the master nightly build
ENV ODOO_VERSION=master
# Leave both empty to resolve master's current nightly; set both to pin one.
ARG ODOO_DEB=
ARG ODOO_SHA=
RUN base="http://nightly.odoo.com/${ODOO_VERSION}/nightly/deb" \
    && deb="${ODOO_DEB}" && sha="${ODOO_SHA}" \
    && if [ -z "${deb}" ]; then \
        packages="$(curl -sSL "${base}/Packages")" \
        && deb="$(printf '%s' "${packages}" | awk '/^Filename:/ {print $2}' | sed 's|^\./||' | tail -n1)" \
        && sha="$(printf '%s' "${packages}" | awk '/^SHA1:/ {print $2}' | tail -n1)" \
        && echo "resolved master nightly: ${deb} (sha1 ${sha})"; \
    fi \
    && [ -n "${deb}" ] && [ -n "${sha}" ] \
    && curl -o odoo.deb -sSL "${base}/${deb}" \
    && echo "${sha} odoo.deb" | sha1sum -c - \
    && apt-get update \
    && apt-get -y install --no-install-recommends ./odoo.deb \
    && rm -rf /var/lib/apt/lists/* odoo.deb

# Copy entrypoint script and Odoo configuration file
COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/

# Set permissions and Mount /var/lib/odoo to allow restoring filestore and /mnt/extra-addons for users addons
RUN chown odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

# Expose Odoo services
EXPOSE 8069 8071 8072

# Set the default config file
ENV ODOO_RC=/etc/odoo/odoo.conf

COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py

# Set default user when running the container
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
