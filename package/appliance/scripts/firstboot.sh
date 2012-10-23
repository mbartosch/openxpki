#!/bin/bash

touch /tmp/firstboot

# Expire the user account
passwd -e user

# Regenerate ssh keys
rm /etc/ssh/ssh_host*key*
dpkg-reconfigure -fnoninteractive -pcritical openssh-server
