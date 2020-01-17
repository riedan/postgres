#!/usr/bin/python3

import sys
import os
import shutil
import logging
import jinja2 as j2
import uuid
import base64


logging.basicConfig(level=logging.DEBUG)


######################################################################
# Setup inputs and outputs

# Import all ATL_* and Dockerfile environment variables. We lower-case
# these for compatability with Ansible template convention. We also
# support CATALINA variables from older versions of the Docker images
# for backwards compatability, if the new version is not set.
env = {k.lower(): v
       for k, v in os.environ.items()}


# Setup Jinja2 for templating
jenv = j2.Environment(
    loader=j2.FileSystemLoader('/usr/local/share/postgresql/'),
    autoescape=j2.select_autoescape(['xml']))


######################################################################
# Utils

def set_perms(path, user, group, mode):
    shutil.chown(path, user=user, group=group)
    os.chmod(path, mode)
    for dirpath, dirnames, filenames in os.walk(path):
        shutil.chown(dirpath, user=user, group=group)
        os.chmod(dirpath, mode)
        for filename in filenames:
            shutil.chown(os.path.join(dirpath, filename), user=user, group=group)
            os.chmod(os.path.join(dirpath, filename), mode)


def set_ownership(path, user, group):
    shutil.chown(path, user=user, group=group)
    for dirpath, dirnames, filenames in os.walk(path):
        shutil.chown(dirpath, user=user, group=group)
        for filename in filenames:
            shutil.chown(os.path.join(dirpath, filename), user=user, group=group)

def check_perms(path, uid, gid, mode):
    stat = os.stat(path)
    return all([
        stat.st_uid == int(uid),
        stat.st_gid == int(gid),
        stat.st_mode & mode == mode
    ])

def gen_cfg(tmpl, target, user='root', group='root', mode=0o644, overwrite=True):
    if not overwrite and os.path.exists(target):
        logging.info(f"{target} exists; skipping.")
        return

    logging.info(f"Generating {target} from template {tmpl}")
    cfg = jenv.get_template(tmpl).render(env)
    try:
        with open(target, 'w') as fd:
            fd.write(cfg)
    except (OSError, PermissionError):
        logging.warning(f"Container not started as root. Bootstrapping skipped for '{target}'")
    else:
        set_perms(target, user, group, mode)


RUN_USER = env['sys_user']
RUN_GROUP = env['sys_group']
PG_DATA = env['pgdata']
PG_CONFIG_DIR = env['pg_config_dir']

gen_cfg('patroni.yml.j2', f'{PG_CONFIG_DIR}/patroni.yml' , user=RUN_USER, group=RUN_GROUP,mode=0o640 , overwrite=True)
