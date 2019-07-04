#!/bin/bash

set -e

cp /usr/local/share/postgresql/postgresql.conf.repmgr $PGDATA/postgresql.conf


if ! [ -z ${PG_SSL} ]; then

  sed -i "s/#*\(ssl =\).*/\1 ${PG_SSL}/;" ${PGDATA}/postgresql.conf

  if ! [ -z ${PG_SSL_KEY_FILE} ]; then
    sed -i "s/#*\(ssl_key_file\).*/\1 = '${PG_SSL_KEY_FILE}'/;" ${PGDATA}/postgresql.conf
  fi

  if ! [ -z ${PG_SSL_CERT_FILE} ]; then
    sed -i "s/#*\(ssl_cert_file\).*/\1 = '${PG_SSL_CERT_FILE}'/;" ${PGDATA}/postgresql.conf
  fi

  if ! [ -z ${PG_SSL_CA_FILE} ]; then
    sed -i "s/#*\(ssl_ca_file\).*/\1 = '${PG_SSL_CA_FILE}'/;" ${PGDATA}/postgresql.conf
  fi

fi


if [ $(grep -c "replication repmgr" ${PGDATA}/pg_hba.conf) -gt 0 ]; then
    return
fi

echo "~~ 01: add repmgr" >&2

if [ -z "$PG_REP_PASSWORD" ]; then
	echo 'ERROR: Missing $PG_REP_PASSWORD variable' >&2
	exit 1
fi


echo "CREATE ROLE $PG_REP_USER LOGIN SUPERUSER REPLICATION PASSWORD '$PG_REP_PASSWORD'" | psql -U "$POSTGRES_USER" --dbname "$POSTGRES_DB"
createdb -U "$POSTGRES_USER" -O "$PG_REP_USER" "$PG_REP_DB"

echo "host replication $PG_REP_USER 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
echo "host all repmgr 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"


if ! [ -z ${PG_SSL} ]; then

 sed -i "s/host/hostssl/;" ${PGDATA}/pg_hba.conf

fi

sed -i "s/#*\(shared_preload_libraries\).*/\1 = 'repmgr'/;" ${PGDATA}/postgresql.conf
sed -i "s/#*\(max_wal_senders\).*/\1 = $PG_MAX_WAL_SENDERS/;" ${PGDATA}/postgresql.conf
sed -i "s/#*\(wal_keep_segments\).*/\1 = $PG_WAL_KEEP_SEGMENTS/;" ${PGDATA}/postgresql.conf

pg_ctl -D ${PGDATA} stop -m fast
pg_ctl -D ${PGDATA} start &

sleep 10
