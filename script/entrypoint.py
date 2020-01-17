#!/usr/bin/python3
import os
import shutil
import sys
from entrypoint_helpers import env, gen_cfg, gen_container_id, str2bool, start_app,  set_perms, set_ownership


RUN_USER = env['sys_user']
RUN_GROUP = env['sys_group']
PG_DATA = env['pgdata']
PG_CONFIG_DIR = env['pg_config_dir']


set_ownership(f'{PG_CONFIG_DIR}',  user=RUN_USER, group=RUN_GROUP)
set_ownership(f'{PG_DATA}',  user=RUN_USER, group=RUN_GROUP)
gen_cfg('patroni.yml.j2', f'{PG_CONFIG_DIR}/patroni.yml' , user=RUN_USER, group=RUN_GROUP,mode=0o640 , overwrite=False)



start_app(f'patroni {PG_CONFIG_DIR}/patroni.yml', PG_DATA, 'patroni')