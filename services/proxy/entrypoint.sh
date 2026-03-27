#!/bin/sh

# Generate host keys only if they don't already exist in the mounted volume
if [ ! -f /etc/ssh/keys/ssh_host_rsa_key ]; then
    ssh-keygen -A
    cp /etc/ssh/ssh_host_*_key* /etc/ssh/keys/
fi

# Symlink them back so sshd finds them
for key in /etc/ssh/keys/ssh_host_*; do
    ln -sf "$key" /etc/ssh/
done

exec /usr/sbin/sshd -D -e
