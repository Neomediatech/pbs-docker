#!/bin/bash
set -eo pipefail
shopt -s nullglob

# logging functions
pbs_log() {
	local type="$1"; shift
	printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
}
pbs_note() {
	pbs_log Note "$@"
}
pbs_warn() {
	pbs_log Warn "$@" >&2
}
pbs_error() {
	pbs_log ERROR "$@" >&2
	exit 1
}

# Verify that the minimally required password settings are set for new databases.
docker_verify_minimum_env() {
	if [ -z "$ADMIN_PASSWORD" ]; then
		pbs_error $'Password option is not specified\n\tYou need to specify one of ADMIN_PASSWORD'
	fi
}

# Loads various settings that are used elsewhere in the script
docker_setup_env() {
    declare -g USERS_ALREADY_EXISTS
	if [ -f "/etc/proxmox-backup/user.cfg" ]; then
		USERS_ALREADY_EXISTS='true'
	fi
}

docker_setup_pbs() {
    #Set pbs user
    proxmox-backup-manager user update root@pam --enable 0
    proxmox-backup-manager user create admin@pbs
    proxmox-backup-manager user update admin@pbs --password $ADMIN_PASSWORD
    proxmox-backup-manager acl update / Admin --auth-id admin@pbs

    #Set pbs default store
    #proxmox-backup-manager datastore create Store1 /backup/store1
}

chown -R backup:backup /etc/proxmox-backup
chown -R backup:backup /var/log/proxmox-backup
chown -R backup:backup /var/lib/proxmox-backup
chown -R backup:backup /run/proxmox-backup
chmod -R 700 /etc/proxmox-backup

RELAY_HOST=${RELAY_HOST:-ext.home.local}
sed -i "s/RELAY_HOST/$RELAY_HOST/" /etc/postfix/main.cf
PBS_ENTERPRISE=${PBS_ENTERPRISE:-no}
if [ "$PBS_ENTERPRISE" != "yes" ]; then
    rm -f /etc/apt/sources.list.d/pbs-enterprise.list
fi

docker_verify_minimum_env

# Start api first in background
echo -n "Starting Proxmox backup API..."
/usr/lib/x86_64-linux-gnu/proxmox-backup/proxmox-backup-api &
while true; do
    if [ ! -f /run/proxmox-backup/api.pid ]; then
        echo -n "..."
        sleep 3
    else
        break
    fi
done

#sleep 10
echo "OK"

docker_setup_env

# there's no user setup, so it needs to be initialized
if [ -z "$USERS_ALREADY_EXISTS" ]; then
    docker_setup_pbs
fi

echo "Starting Rsyslogd..."
rsyslogd

echo "Starting Postfix..."
/etc/init.d/postfix start || ok=1

echo "Running PBS..."
exec gosu backup /usr/lib/x86_64-linux-gnu/proxmox-backup/proxmox-backup-proxy "$@"


