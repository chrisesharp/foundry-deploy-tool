#!/bin/bash

source ../.env

worldbundler

scp foundry-upload.tgz $PI_SSH:/tmp
ssh $PI_SSH rm -rf /home/chrissharp/FoundryVTT
ssh $PI_SSH tar xvf /tmp/foundry-upload.tgz

PID=`ssh $PI_SSH ps -ef |grep run_foundryvtt.sh |awk '{ print $2}'`

echo 'IP address:' ${PI_IP}

DNS=`curl https://www.duckdns.org/update/${DNS_DOMAIN}/${DNS_TOKEN}/${PI_IP}`
echo 'Updating DNS:' ${DNS}

sleep 1
open http://${DNS_DOMAIN}.duckdns.org:30000/

if [ -z ${PID} ]; then
    ssh $PI_SSH /home/chrissharp/run_foundryvtt.sh
else
    kill -9 $PID
    ssh $PI_SSH /home/chrissharp/run_foundryvtt.sh
fi