#!/bin/bash

set -ex
unset  PGPASSWORD
PGHOST=${PRIMARY_NODE}
PGSSLMODE=prefer
installed=$(psql -qAt -h "$PGHOST" -U "$PG_REP_USER" --dbname "$PG_REP_DB" -p "$PG_PORT" -c "SELECT 1 FROM pg_tables WHERE tablename='nodes'" || psql -qAt -h "$PGHOST" -U "$PG_REP_USER" --dbname "$PG_REP_DB"  -c "SELECT 1 FROM pg_tables WHERE tablename='nodes'")


if [ "${installed}" != "1" ]; then
    echo '~~ 03: registering as primary' >&2
    repmgr -f ${PG_CONFIG_DIR}/repmgr.conf primary register -k 30
    export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}" 2>/dev/null
    return
fi

if [ -n "$WITNESS" ]; then
	echo '~~ 03: registering as witness server' >&2
  repmgr -f ${PG_CONFIG_DIR}/repmgr.conf -h "$PRIMARY_NODE" -U "$PG_REP_USER" -d "$REPMGR_DB" -p "$PG_PORT" witness register -k 30
  export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}" 2>/dev/null
  return
fi

my_node=$(grep node_id ${PG_CONFIG_DIR}/repmgr.conf | cut -d= -f 2)
is_reg=$(psql -qAt -h "$PGHOST" -U "$PG_REP_USER" -d "$PG_REP_DB" -p "$PG_PORT" -c "SELECT 1 FROM repmgr.nodes WHERE node_id=${my_node}" || psql -qAt -h "$PGHOST" -U "$PG_REP_USER" -d "$PG_REP_DB" -c "SELECT 1 FROM repmgr.nodes WHERE node_id=${my_node}")

if [ "${is_reg}" != "1" ] && [ ${my_node} -gt 1 ]; then
    echo '~~ 03: registering as standby' >&2
    pg_ctl -D "$PGDATA" stop -m fast
    rm -Rf "$PGDATA"/*
    repmgr -f ${PG_CONFIG_DIR}/repmgr.conf -h "$PRIMARY_NODE" -U "$PG_REP_USER" -d "$PG_REP_DB" -p "$PG_PORT" standby clone --fast-checkpoint
    pg_ctl -D "$PGDATA" start &
    sleep 1
    repmgr -f ${PG_CONFIG_DIR}/repmgr.conf -h "$PRIMARY_NODE" -U "$PG_REP_USER" -d "$PG_REP_DB" -p "$PG_PORT" standby register -k 30
fi

export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}" 2>/dev/null
