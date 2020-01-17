#!/usr/bin/python3

import os
import shutil
import sys
from subprocess import call
from entrypoint_helpers import env, gen_cfg, gen_container_id, str2bool, start_app,  set_perms, set_ownership, activate_ssl


RUN_USER = env['sys_user']
RUN_GROUP = env['sys_group']
PG_DATA = env['pgdata']
PG_CONFIG_DIR = env['pg_config_dir']

gen_cfg('patroni.yml.j2', f'{PG_CONFIG_DIR}/patroni.yml' , user=RUN_USER, group=RUN_GROUP,mode=0o640 , overwrite=True)
