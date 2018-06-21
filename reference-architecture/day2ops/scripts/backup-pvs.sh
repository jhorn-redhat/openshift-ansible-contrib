#!/bin/bash

# Backup persistent volumes of projects listed in /etc/backup-pvs/vars.yml.

# To run this script daily, create /etc/cron.d/backup-pvs with this content:
# 0 5 * * * root /usr/local/sbin/backup-pvs.sh

# For this to work, the following RPM packages need to be installed:
# samba-client samba-common cifs-utils

(

set -eu

# vars.sh has to define the following shell variables:
# BACKUP_DIR, BACKUP_MAX_DAYS, BACKUP_USER, SMB_SHARE, SMB_USER, SMB_PASSWORD
. /etc/backup-pvs/vars.sh

mount -t cifs $SMB_SHARE $BACKUP_DIR \
  -o vers=3.0,username=$SMB_USER,password=$SMB_PASSWORD,sec=ntlmssp,uid=$BACKUP_USER,gid=$BACKUP_USER

cd /usr/local/backup-restore-pvs

# vars.yml needs to define the following Ansible variable:
# project_names

sudo -u $BACKUP_USER ansible-playbook \
  -e @/etc/backup-pvs/vars.yml \
  -e local_backup_dir=$BACKUP_DIR \
  backup-pvs.yml

# Delete old backups.

find $BACKUP_DIR/* -mindepth 1 -type d -mtime $BACKUP_MAX_DAYS -exec rm -rf {} \;

umount $BACKUP_DIR

) >&/var/log/backup-pvs.log
