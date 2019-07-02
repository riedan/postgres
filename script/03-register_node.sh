#!/bin/bash

set -ex

PGHOST=${PRIMARY_NODE}

installed=$(psql -qAt -h "$PGHOST" -U "$PG_REP_USER" --dbname "$PG_REP_DB" -c "SELECT 1 FROM pg_tables WHERE tablename='nodes'")

PGPASSFILE=${PGDATA}/.pgpass

 unset  PGPASSWORD

if [ "${installed}" != "1" ]; then
    echo '~~ 03: registering as primary' >&2
    repmgr -f $PGDATA/repmgr.conf primary register
    export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
    return
fi

if [ -n "$WITNESS" ]; then
	echo '~~ 03: registering as witness server' >&2
  repmgr -f $PGDATA/repmgr.conf -h "$PRIMARY_NODE" -U "$PG_REP_USER" -d "$REPMGR_DB" witness register
  export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
	return
fi

my_node=$(grep node_id $PGDATA/repmgr.conf | cut -d= -f 2)
is_reg=$(psql -qAt -h "$PGHOST" -U "$PG_REP_USER" "$PG_REP_DB" -c "SELECT 1 FROM repmgr.nodes WHERE node_id=${my_node}")

if [ "${is_reg}" != "1" ] && [ ${my_node} -gt 1 ]; then
    echo '~~ 03: registering as standby' >&2
    pg_ctl -D "$PGDATA" stop -m fast
    rm -Rf "$PGDATA"/*
    repmgr -f $PGDATA/repmgr.conf -h "$PRIMARY_NODE" -U "$PG_REP_USER" -d "$PG_REP_DB" standby clone --fast-checkpoint
    pg_ctl -D "$PGDATA" start &
    sleep 1
    repmgr -f $PGDATA/repmgr.conf -h "$PRIMARY_NODE" -U "$PG_REP_USER" -d "$PG_REP_DB" standby register
    export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
fi

