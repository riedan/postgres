# vim:set ft=dockerfile:
FROM postgres:9.6-alpine

ENV SYS_GROUP postgres
ENV SYS_USER postgres

ENV PG_MAX_WAL_SENDERS 8
ENV PG_WAL_KEEP_SEGMENTS 8

ENV REPMGR_PID_FILE /tmp/repmgrd.pid

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
	&& apk add --no-cache  ca-certificates su-exec bash python3 py3-psycopg2 py3-jinja2

RUN set -eux; \
 pip3 install --upgrade pip3 && \
 pip3 install --upgrade setuptools && \
 pip3 install patroni && \
 pip3 install psycopg2 pyyaml && \
 update-ca-certificates

RUN  chown -R ${SYS_USER}:${SYS_GROUP} "$PGDATA"


# override this on secondary nodes
ENV PRIMARY_NODE=localhost

ENV PG_REP_USER=patroni
ENV PG_REP_DB=patroni
ENV PG_CONFIG_DIR=/var/lib/postgresql/conf
ENV PGPASSFILE="$PG_CONFIG_DIR/.pgpass"
ENV POSTGRES_PORT=5432
ENV PGSSLMODE=prefer



RUN mkdir -p "$PG_CONFIG_DIR" &&  chown -R ${SYS_USER}:${SYS_GROUP} "$PG_CONFIG_DIR"

RUN git clone https://github.com/mreithub/pg_recall.git /root/pg_recall/
RUN cd /root/pg_recall/; make install


COPY postgresql.conf /usr/local/share/postgresql/postgresql.conf.repmgr
COPY docker-entrypoint.sh /usr/local/bin/
COPY script/* /docker-entrypoint-initdb.d/
COPY template/* /usr/local/share/postgresql/

RUN dos2unix /usr/local/bin/docker-entrypoint.sh
RUN dos2unix /docker-entrypoint-initdb.d/*.sh

RUN apk del .dd2
RUN apk add --update iputils

USER    root

RUN chmod +x  /usr/local/bin/docker-entrypoint.sh  /docker-entrypoint-initdb.d/*.sh  /docker-entrypoint-initdb.d/*.py
ENTRYPOINT ["docker-entrypoint.sh"]

VOLUME /var/lib/postgresql
VOLUME /var/lib/postgresql/data



EXPOSE 5432
CMD ["postgres"]