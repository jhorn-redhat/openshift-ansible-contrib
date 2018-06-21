#!/bin/bash

# Backup metadata and persistent volumes of projects listed in 
# /etc/backup-ocp-projects/vars.yml.

# To run this script daily, create /etc/cron.d/backup-ocp-projects with this content:
# 0 5 * * * root /usr/local/sbin/backup-ocp-projects.sh

# For this to work, the following RPM packages need to be installed:
# samba-client samba-common cifs-utils

(

set -eu

# vars.sh has to define the following shell variables:
# MOUNT_POINT, BACKUP_MAX_DAYS, BACKUP_USER, SMB_SHARE, SMB_USER, SMB_PASSWORD
. /etc/backup-ocp-projects/vars.sh

mount -t cifs $SMB_SHARE $MOUNT_POINT \
  -o vers=3.0,username=$SMB_USER,password=$SMB_PASSWORD,sec=ntlmssp,uid=$BACKUP_USER,gid=$BACKUP_USER

cd /usr/local/backup-restore-projects

# vars.yml needs to define the following Ansible variable:
# project_names

sudo -u $BACKUP_USER ansible-playbook \
  -e @/etc/backup-ocp-projects/vars.yml \
  -e local_backup_dir=$MOUNT_POINT \
  backup-pvs.yml

sudo -u $BACKUP_USER ansible-playbook \
  -e @/etc/backup-ocp-projects/vars.yml \
  -e local_backup_dir=$MOUNT_POINT \
  backup-projects.yml

# Delete old backups.

find $MOUNT_POINT/* -mindepth 1 -maxdepth 1 -type d -mtime $BACKUP_MAX_DAYS -exec rm -rf {} \;

umount $MOUNT_POINT

) >&/var/log/backup-ocp-projects.log
