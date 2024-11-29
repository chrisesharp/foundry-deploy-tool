#!/bin/bash

source ../.env

CLOUD=$1
if [ -z ${CLOUD} ] ; then echo "Need to specify cloud [do]"; exit ; fi
if [ -z ${BACKUPDIR} ] ; then export BACKUPDIR="./backup/${CLOUD}"; fi

DROPLET=$(terraform show -json |jq '.values.root_module.resources[1].values.ipv4_address' | sed -e 's/^"//' -e 's/"$//')
echo "Copying data from ${DROPLET} to ${BACKUPDIR}/FoundryVTT/"
mkdir -p "${BACKUPDIR}/FoundryVTT/"

# Copy from Mac to Droplet
#rsync --progress --partial -avz -e "ssh -i ~/.ssh/mac_token -l root -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" ${BACKUPDIR} ${DROPLET}:/mnt/FoundryVTT

# Copy from Droplet to Mac
# rsync --progress --partial -avz -e "ssh -i ~/.ssh/mac_token -l root -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" ${DROPLET}:/mnt/FoundryVTT ${BACKUPDIR}

ssh root@${DROPLET} -i ~/.ssh/mac_token "cd /mnt ; tar zcf - ./FoundryVTT | cat > /tmp/backup.tgz"
scp -i ~/.ssh/mac_token scp://root@${DROPLET}//tmp/backup.tgz /tmp
pushd ${BACKUPDIR}
tar xf /tmp/backup.tgz
rm /tmp/backup.tgz
popd
