#!/bin/bash

if [ "x$REPLICATE_FROM" == "x" ] && [ -n  "$PG_REP_USER"]; then

echo "host replication $PG_REP_USER 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
CREATE USER $PG_REP_USER REPLICATION LOGIN CONNECTION LIMIT 100 ENCRYPTED PASSWORD '$PG_REP_PASSWORD';
EOSQL
cat >> ${PGDATA}/postgresql.conf <<EOF
wal_level = hot_standby
archive_mode = on
archive_command = 'cd .'
max_wal_senders = $PG_MAX_WAL_SENDERS
wal_keep_segments = $PG_WAL_KEEP_SEGMENTS
hot_standby = on
EOF

elif [ -n  "$REPLICATE_FROM"]; then

if [ ! -s "$PGDATA/PG_VERSION" ]; then
echo "*:*:*:$PG_REP_USER:$PG_REP_PASSWORD" > ~/.pgpass
chmod 0600 ~/.pgpass
until ping -c 1 -W 1 $REPLICATE_FROM
do
echo "Waiting for master to ping..."
sleep 1s
done
until pg_basebackup -h $REPLICATE_FROM -D ${PGDATA} -U ${PG_REP_USER} -vP -W
do
echo "Waiting for master to connect..."
sleep 1s
done
echo "host replication $PG_REP_USER 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
set -e
cat > ${PGDATA}/recovery.conf <<EOF
standby_mode = on
primary_conninfo = 'host=$REPLICATE_FROM port=$REPLICATE_PORT user=$PG_REP_USER password=$PG_REP_PASSWORD'
trigger_file = '/tmp/touch_me_to_promote_to_me_master'
EOF
chown ${SYS_USER}:${SYS_GROUP} ${PGDATA} -R
chmod 700 ${PGDATA} -R
fi
sed -i 's/wal_level = hot_standby/wal_level = replica/g' ${PGDATA}/postgresql.conf

fi
