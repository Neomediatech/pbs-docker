> [!WARNING]
> **Maybe something is not working, use this image with caution, bad things can happens. YHBW**  

# Proxmox Backup Server on a Docker container
Proxmox Backup Server on a Docker container  

## Known limits
* **Postfix is not working**
* (and maybe many other things)  

## How to run
`./run.sh` ;-)  
What does [run.sh](run.sh) do:
* set docker ENV vars if they are set in the script or in the `.envs` file
* set shell script vars if they are set in the script or in the `.shell-vars` file (see [example](#environment-variables))
* check if datastore exists; if not, it exit prior tu run the container (maybe in future i'll make it more smart, see [To DO](#to-do) section)
* run the container
  
or  
`docker run -d --name pbs neomediatech/pbs`

## Environment Variables
| Name                | Description                                                     | Default         |
| ------------------- | --------------------------------------------------------------- | --------------- |
| ADMIN_PASSWORD      | Password to access PBS web interface (mandatory)                | (none)          |
| RELAY_HOST          | Hostname to use to relay email from Postfix (NOT WORKING!)      |                 |
| PBS_ENTERPRISE      | If set to "yes", enterprise repository will be retained         | no              |

Set vars in `run.sh` script and/or set them in `.envs` file.  
Example `.envs` file:
```
ADMIN_PASSWORD=myrealsecretpassword
RELAY_HOST=10.40.50.4
```
## run.sh script shell vars
| Name                | Description                                                     | Default         
| ------------------- | --------------------------------------------------------------- | --------------- 
| INTERACTIVE         | Run the container in "interactive mode" (run it in foreground)  <br /> CTRL+C will end the container | no 
| MOUNT_PBS_MOUNT     | mount the mountpoint set in PBS_MOUNT var? Must be in the fstab host | yes
| CREATE_DATASTORE    | Create the datastore if it doesn't exists? (The name will be "pbs") | no
| NAME                | Proxmox Backup Server name | pbs
| PBS_DATASTORE_NAME  | The datastore name | pbs
| BASE_PATH           | Path where to store PBS configurations, users, etc... | /srv/pbs
| PBS_MOUNT           | Path to store backups | /media/pbs-backup
  
`.shell-vars` example file:
```
NAME="myserver-pbs"
PBS_DATASTORE_NAME="backups"
BASE_PATH="/srv/pbs"
INTERACTIVE="no"
MOUNT_PBS_MOUNT="no"
CREATE_DATASTORE="yes"
PBS_MOUNT="/mnt/pbs-backup"

```
## Mountpoints/volumes
Put your docker bindmount in the script [run.sh](run.sh) or in the `.volumes` file  
`.volumes` example file:
```
${BASE_PATH}/data:/data
${BASE_PATH}/config:/etc/proxmox-backup
${BASE_PATH}/data/logs:/var/log/proxmox-backup
${BASE_PATH}/data/lib:/var/lib/proxmox-backup
${BASE_PATH}/data/bin:/srv/bin
```  
  
## To DO
- [ ] Option to create the datastore if it doesn't exists
- [ ] Make Postfix working, to send emails

