#!/bin/bash

set -e

if [ -s $PGDATA/repmgr.conf ]; then
    return
fi


echo '~~ 02: repmgr conf' >&2

unset  PGPASSWORD

PGHOST=${PRIMARY_NODE}

if ! [ -f $PGPASSFILE ]; then
	echo "*:5432:*:$PG_REP_USER:$PG_REP_PASSWORD" > ${PG_CONFIG_DIR}/.pgpass
	echo "*:$PG_PORT:*:$PG_REP_USER:$PG_REP_PASSWORD" >> ${PG_CONFIG_DIR}/.pgpass
	echo "*:$PRIMARY_NODE_PORT:*:$PG_REP_USER:$PG_REP_PASSWORD" >> ${PG_CONFIG_DIR}/.pgpass
	chmod go-rwx ${PG_CONFIG_DIR}/.pgpass
	PGPASSFILE=${PG_CONFIG_DIR}/.pgpass
fi

python3  /docker-entrypoint-initdb.d/04-patroni.py
