FROM postgres:9.6-alpine

ENV SYS_GROUP postgres
ENV SYS_USER postgres

ENV SYS_UID                                         2001
ENV SYS_GID                                         2001


ENV PG_MAX_WAL_SENDERS 8
ENV PG_WAL_KEEP_SEGMENTS 8

# make the "C" locale so postgres will be utf-8 enabled by default
# alpine doesn't require explicit locale-file generation
ENV LANG C

RUN set -ex \
	\
	&& apk add --no-cache --virtual .dd2 \
	      postgresql-dev \
	      dos2unix \
	      curl \
	      git \
	      bison \
        coreutils \
        python3-dev \
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
  && update-ca-certificates

RUN set -ex \
	\
	&& apk add --no-cache  ca-certificates su-exec bash python3 tini openssl curl


#create user if not exist
RUN set -eux; \
	getent group ${SYS_GROUP} || addgroup -g ${RUN_GID} -S ${SYS_GROUP}; \
	getent passwd ${SYS_USER} || adduser  --uid ${RUN_UID}  -S ${SYS_USER}  -G ${SYS_GROUP} -s "/bin/bash";


RUN set -ex; \
	postgresHome="$(getent passwd ${SYS_USER})"; \
	postgresHome="$(echo "$postgresHome" | cut -d: -f6)"; \
	[ "$postgresHome" = '/var/lib/postgresql' ]; \
	mkdir -p "$postgresHome"; \
	chown -R ${SYS_USER}:${SYS_GROUP} "$postgresHome"

RUN set -eux; \
 pip3 install --upgrade pip && \
 pip3 install --upgrade setuptools && \
 pip3 install psycopg2 pyyaml jinja2 && \
 pip3 install patroni[etcd,aws,consul,zookeeper] python-consul dnspython boto mock requests six kazoo click tzlocal prettytable watchdog && \
 update-ca-certificates

RUN  chown -R ${SYS_USER}:${SYS_GROUP} "$PGDATA"


ENV PG_REP_USER=patroni
ENV PG_REP_DB=replication
ENV PG_CONFIG_DIR=/var/lib/postgresql/conf
ENV PGPASSFILE="$PG_CONFIG_DIR/.pgpass"
ENV POSTGRES_PORT=5432
ENV PGSSLMODE=prefer



RUN mkdir -p "$PG_CONFIG_DIR" &&  chown -R ${SYS_USER}:${SYS_GROUP} "$PG_CONFIG_DIR" \
 && mkdir -p "/var/log/patroni" &&  chown -R ${SYS_USER}:${SYS_GROUP} "/var/log/patroni"

RUN git clone https://github.com/mreithub/pg_recall.git /root/pg_recall/
RUN cd /root/pg_recall/; make install


COPY script/* /
COPY template/* /usr/local/share/postgresql/

RUN apk del .dd2
RUN apk add --update iputils


RUN chmod +x /entrypoint.py
RUN chmod +x /entrypoint_helpers.py
RUN chmod +x /post_bootstrap.sh

VOLUME /var/lib/postgresql
VOLUME /var/lib/postgresql/data

EXPOSE 5432
EXPOSE 8008
CMD ["/entrypoint.py"]
ENTRYPOINT ["tini", "--"]