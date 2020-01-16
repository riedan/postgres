#!/usr/bin/python3

import os
import shutil
import sys
from subprocess import call
from entrypoint_helpers import env, gen_cfg, gen_container_id, str2bool, start_app,  set_perms, set_ownership, activate_ssl


RUN_USER = env['sys_user']
RUN_GROUP = env['sys_group']
JIRA_SESSION_TIMEOUT = env.get('atl_session_timeout', 600)

gen_container_id()

gen_cfg('patroni.yml.j2', f'{PG_CONFIG_DIR}/patroni.yml')

start_app(f'patroni ', PG_DATA, name='Patroni')