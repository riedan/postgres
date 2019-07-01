# vim:set ft=dockerfile:
FROM postgres:9.6-alpine

ENV SYS_GROUP postgres
ENV SYS_USER postgres

ENV PG_MAX_WAL_SENDERS 8
ENV PG_WAL_KEEP_SEGMENTS 8


ARG REPMGR_VERSION=4.4.0
ARG REPMGR_SHA1=e41a42dc5267e1b5f19d13f43a243eb7bc34d1a3


#create user if not exist
RUN set -eux; \
	getent group ${SYS_GROUP} || addgroup -S ${SYS_GROUP}; \
	getent passwd ${SYS_USER} || adduser -S ${SYS_USER}  -G ${SYS_GROUP} -s "/bin/sh";


RUN set -ex; \
	postgresHome="$(getent passwd ${SYS_USER})"; \
	postgresHome="$(echo "$postgresHome" | cut -d: -f6)"; \
	[ "$postgresHome" = '/var/lib/postgresql' ]; \
	mkdir -p "$postgresHome"; \
	chown -R ${SYS_USER}:${SYS_GROUP} "$postgresHome"


# make the "C" locale so postgres will be utf-8 enabled by default
# alpine doesn't require explicit locale-file generation
ENV LANG C



RUN set -ex \
	\
	&& apk add --no-cache  ca-certificates su-exec bash \
	&& apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ --allow-untrusted barman

RUN set -ex \
	\
	&& apk add --no-cache --virtual .dd2 \
	      dos2unix \
	      curl \
	      git \
	      bison \
        coreutils \
        dpkg-dev dpkg \
        flex \
        gcc \
    #		krb5-dev \
        libc-dev \
        libedit-dev \
        libxml2-dev \
        libxslt-dev \
        linux-headers \
        make \
        openssl-dev \
        perl-utils \
        perl-ipc-run \
        util-linux-dev \
        zlib-dev \
  && curl -sSL https://github.com/2ndQuadrant/repmgr/archive/v${REPMGR_VERSION}.tar.gz  -o ${REPMGR_VERSION}.tar.gz \
  && echo "${REPMGR_SHA1}  ${REPMGR_VERSION}.tar.gz" | sha1sum -c - \
  && tar zxf ${REPMGR_VERSION}.tar.gz \
  && cd repmgr-${REPMGR_VERSION} \
  && ./configure \
  && make USE_PGXS=1 install \
  && cd .. \
  && rm -Rf repmgr-${REPMGR_VERSION} ${REPMGR_VERSION}.tar.gz

RUN  chown -R ${SYS_USER}:${SYS_GROUP} "$PGDATA"


# override this on secondary nodes
ENV PRIMARY_NODE=localhost

ENV PG_REP_USER=repmgr
ENV PG_REP_DB=repmgr
ENV PGPASSFILE="$PGDATA/.pgpass"


RUN git clone https://github.com/mreithub/pg_recall.git /root/pg_recall/
RUN cd /root/pg_recall/; make install


COPY postgresql.conf /usr/local/share/postgresql/postgresql.conf.repmgr
COPY docker-entrypoint.sh /usr/local/bin/
COPY script/*.sh /docker-entrypoint-initdb.d/

RUN chmod 644 /etc/repmgr.conf
RUN dos2unix /usr/local/bin/docker-entrypoint.sh
RUN dos2unix /docker-entrypoint-initdb.d/*.sh

RUN apk del .dd2
RUN apk add --update iputils

RUN chmod +x  /usr/local/bin/docker-entrypoint.sh  /docker-entrypoint-initdb.d/*.sh
ENTRYPOINT ["docker-entrypoint.sh"]

VOLUME /var/lib/postgresql
VOLUME /var/lib/postgresql/data

EXPOSE 5432
CMD ["postgres"]