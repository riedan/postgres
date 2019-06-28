# vim:set ft=dockerfile:
FROM postgres:9.6-alpine

ENV SYS_GROUP postgres
ENV SYS_USER postgres

ENV PG_MAX_WAL_SENDERS 8
ENV PG_WAL_KEEP_SEGMENTS 8

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
ENV postgresHome /var/lib/postgresql

RUN set -ex \
	\
	&& apk add --no-cache --virtual .dd2 \
	dos2unix postgresql-dev make git

RUN set -ex \
	\
	&& apk add --no-cache  ca-certificates repmgr su-exec bash \
	&& apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ --allow-untrusted barman

RUN  chown -R ${SYS_USER}:${SYS_GROUP} "$PGDATA"

RUN ln -s /etc/repmgr.conf $postgresHome/repmgr.conf


# override this on secondary nodes
ENV PRIMARY_NODE=localhost

ENV PG_REP_USER=repmgr
ENV PG_REP_DB=repmgr


RUN git clone https://github.com/mreithub/pg_recall.git /root/pg_recall/
RUN cd /root/pg_recall/; make install


COPY docker-entrypoint.sh /usr/local/bin/
COPY script/*.sh /docker-entrypoint-initdb.d/


RUN dos2unix /usr/local/bin/docker-entrypoint.sh
RUN dos2unix /docker-entrypoint-initdb.d/*.sh

RUN apk del .dd2
RUN apk add --update iputils

RUN chmod +x  /docker-entrypoint-initdb.d/setup-replication.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]

VOLUME /var/lib/postgresql
VOLUME /var/lib/postgresql/data

EXPOSE 5432
CMD ["postgres"]