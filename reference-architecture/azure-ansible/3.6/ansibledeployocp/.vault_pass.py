#!/usr/bin/env python
import os
try:
    print os.environ['ANSIBLE_VAULT_LAB_PASSWORD_FILE']
except:
    exit

