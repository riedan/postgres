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
	chmod go-rwx ${PG_CONFIG_DIR}/.pgpass
	PGPASSFILE=${PG_CONFIG_DIR}/.pgpass
fi

installed=$(psql -qAt -h "$PGHOST" -U "$PG_REP_USER" -d "$PG_REP_DB" -p "$PG_PORT" -c "SELECT 1 FROM pg_tables WHERE tablename='nodes'")
my_node=1

if [ "${installed}" == "1" ]; then
    my_node=$(psql -qAt -h "$PGHOST" -U "$PG_REP_USER" -d "$PG_REP_DB" -p "$PG_PORT" -c 'SELECT max(node_id)+1 FROM repmgr.nodes')
fi

# allow the user to specify the hostname/IP for this node
if [ -z "$NODE_HOST" ]; then
	NODE_HOST=$(hostname -f)
fi

cat<<EOF > "$PG_CONFIG_DIR/repmgr.conf"
node_id=${my_node}
node_name=$(hostname -s | sed 's/\W\{1,\}/_/g;')
conninfo=host='$NODE_HOST' user='$PG_REP_USER' dbname='$PG_REP_DB' port=$PG_PORT connect_timeout=5 sslmode=prefer
data_directory=${PGDATA}

log_level=INFO
log_facility=STDERR
log_status_interval=300

pg_bindir=/usr/local/bin/
use_replication_slots=1

failover=automatic
promote_command=repmgr standby promote
follow_command=repmgr standby follow -W

service_start_command=pg_ctl -D ${PGDATA} start
service_stop_command=pg_ctl -D ${PGDATA} stop -m fast
service_restart_command=pg_ctl -D ${PGDATA} restart -m fast
service_reload_command=pg_ctl -D ${PGDATA} reload

monitor_interval_secs=10
monitoring_history=true
EOF


chown  ${SYS_USER}:${SYS_GROUP} ${PG_CONFIG_DIR}/repmgr.conf