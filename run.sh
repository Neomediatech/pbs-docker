#!/bin/bash
# shell vars set here will be overridden by same shell vars set in $BASE_PATH/.shell-vars file
BASE_PATH="/srv/pbs"
IMAGE="pbs"
NAME="pbs"
VOLUMES="" # volumes set here will be added to volumes found in $BASE_PATH/.volumes file (if it exists)
PORTS="-p 8007:8007"
OPTIONS="--mount type=tmpfs,destination=/run/proxmox-backup/shmem"
#OPTIONS="$OPTIONS --restart=always"
ENVS="" # vars set here will override same vars in $BASE_PATH/.env file
ENTRYPOINT=""
#ENTRYPOINT="--entrypoint /bin/bash"
INTERACTIVE="no"
MOUNT_PBS_MOUNT="yes"
CREATE_DATASTORE="no"
PBS_MOUNT="/media/pbs-backup"
PBS_DATASTORE_NAME="pbs"

if [ -f $BASE_PATH/.shell-vars ]; then
    source $BASE_PATH/.shell-vars
fi

PBS_DATASTORE_DIR="${PBS_MOUNT}/pbs"

if [ -f $BASE_PATH/.volumes ]; then
    for VOLUME in $(cat $BASE_PATH/.volumes); do
        VOLUMES="$VOLUMES -v $(eval "echo $VOLUME")"
    done
fi
VOLUMES="$VOLUMES -v $PBS_DATASTORE_DIR:$PBS_DATASTORE_DIR"

if [ -f $BASE_PATH/.env ]; then
    ENVS="--env-file $BASE_PATH/.env $ENVS"
fi

if [ "$INTERACTIVE" == "yes" ]; then
    RUN_OPTIONS="-it --rm"
else
    RUN_OPTIONS="-d --rm"
fi

if [ $MOUNT_PBS_MOUNT == "yes" ]; then
    umount $PBS_MOUNT 2>/dev/null
    set -e
    mount $PBS_MOUNT
    set +e
fi

if [ ! -d "$PBS_DATASTORE_DIR/.chunks" ]; then
    if [ "$CREATE_DATASTORE" == "yes" ]; then
        docker stop $NAME 1>/dev/null 2>/dev/null; docker rm $NAME 1>/dev/null 2>/dev/null; docker pull $IMAGE 1>/dev/null 2>/dev/null
        mkdir -p $PBS_DATASTORE_DIR
        docker run -d --rm $PORTS --name $NAME --hostname $NAME $OPTIONS $VOLUMES $ENVS $ENTRYPOINT $IMAGE 1>/dev/null
        docker exec -it $NAME bash -c 'while true;do if [ ! -f /run/proxmox-backup/proxy.pid ]; then echo "Waiting to Proxmox Backup become alive..."; sleep 3;else exit;fi;done'
        docker exec -it $NAME proxmox-backup-manager datastore list | grep -q $PBS_DATASTORE_NAME 
        if [ $? -eq 0 ]; then
            docker exec -it $NAME proxmox-backup-manager datastore update --maintenance-mode type="offline" $PBS_DATASTORE_NAME
            docker exec -it $NAME proxmox-backup-manager datastore remove $PBS_DATASTORE_NAME
        fi
        echo "Creating the datastore $PBS_DATASTORE_NAME into $PBS_DATASTORE_DIR..."
        docker exec -it $NAME proxmox-backup-manager datastore create $PBS_DATASTORE_NAME $PBS_DATASTORE_DIR 1>/dev/null
    else
        echo " "
        echo "WARNING!"
        echo "$PBS_DATASTORE_DIR does not exists,"
        echo "drive not mounted or mount point incorrect"
        echo "exiting..."
        echo " "
        exit 1
    fi
fi

echo "Stopping existing Proxmox Backup Server instances..."
docker stop $NAME 2>/dev/null
echo "Deleting old Proxmox Backup Server instances..."
docker rm $NAME 2>/dev/null
echo "Pulling new version of Proxmox Backup Server Docker image..."
docker pull $IMAGE 2>/dev/null
echo "Starting Proxmox Backup Server..."
docker run $RUN_OPTIONS $PORTS --name $NAME --hostname $NAME $OPTIONS $VOLUMES $ENVS $ENTRYPOINT $IMAGE

echo " "
echo "Useful commands:"
echo "docker exec -it $NAME proxmox-backup-manager sync-job list"
echo "docker exec -it $NAME proxmox-backup-manager sync-job run <id>"
echo "docker exec -it $NAME proxmox-backup-manager prune-job run prune-all"
echo "docker exec -it $NAME proxmox-backup-manager datastore list"
echo "docker exec -it $NAME proxmox-backup-manager garbage-collection start $PBS_DATASTORE_NAME"
echo " "

