#!/usr/bin/python3
import os
import shutil
import sys
from entrypoint_helpers import env, gen_cfg, gen_container_id, str2bool, start_app,  set_perms, set_ownership


RUN_USER = env['sys_user']
RUN_GROUP = env['sys_group']
PG_DATA = env['pgdata']
PG_CONFIG_DIR = env['pg_config_dir']

try:
    PG_SSL_KEY_FILE = env['pg_ssl_key_file']
    PG_SSL_CERT_FILE =  env['pg_ssl_cert_file']
    PG_SSL_CA_FILE = env['pg_ssl_ca_file']

    shutil.copyfile(PG_SSL_KEY_FILE,  f'{PG_CONFIG_DIR}/server.key')
    shutil.copyfile(PG_SSL_CERT_FILE,  f'{PG_CONFIG_DIR}/server.crt')
    shutil.copyfile(PG_SSL_CA_FILE,  f'{PG_CONFIG_DIR}/root.crt')

    set_perms(f'{PG_CONFIG_DIR}/server.key', user=RUN_USER, group=RUN_GROUP, mode=0o600 )
    set_perms(f'{PG_CONFIG_DIR}/server.crt', user=RUN_USER, group=RUN_GROUP, mode=0o600 )
    set_perms(f'{PG_CONFIG_DIR}/root.crt', user=RUN_USER, group=RUN_GROUP, mode=0o600 )
except:
    print("no certificate")



set_ownership(f'{PG_CONFIG_DIR}',  user=RUN_USER, group=RUN_GROUP)
set_ownership(f'{PG_DATA}',  user=RUN_USER, group=RUN_GROUP)
set_ownership('/var/log/patroni',  user=RUN_USER, group=RUN_GROUP)


gen_cfg('patroni.yml.j2', f'{PG_CONFIG_DIR}/patroni.yml' , user=RUN_USER, group=RUN_GROUP,mode=0o640 , overwrite=False)



start_app(f'patroni {PG_CONFIG_DIR}/patroni.yml', PG_DATA, 'patroni')