#!/bin/bash

source ../.env

if [ -z ${FOUNDRY_USERNAME} ]; then echo "FOUNDRY_USERNAME is unset" ; exit ; fi
if [ -z ${FOUNDRY_PASSWORD} ]; then echo "FOUNDRY_PASSWORD is unset" ; exit ; fi

export TF_VAR_do_token=$DO_PAT
export TF_VAR_pvt_key=$HOME/.ssh/id_do
export TF_VAR_foundry_user=${FOUNDRY_USERNAME}
export TF_VAR_foundry_password=${FOUNDRY_PASSWORD}

worldbundler

if [ $? -eq 0 ]
then
    terraform apply -auto-approve
else
    exit
fi

ipv4_address=`terraform show -json |jq '.values.root_module.resources[1].values.ipv4_address'  | sed -e 's/^"//' -e 's/"$//'`
echo 'IP address:' ${ipv4_address}

DNS=`curl https://www.duckdns.org/update/${DNS_DOMAIN}/${DNS_TOKEN}/${ipv4_address}`
echo 'Updating DNS:' ${DNS}

sleep 1
open http://${DNS_DOMAIN}.duckdns.org:30000/