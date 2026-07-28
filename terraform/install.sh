#!/bin/bash

source ../.env

if [ -z ${FOUNDRY_USERNAME} ]; then echo "FOUNDRY_USERNAME is unset" ; exit ; fi
if [ -z ${FOUNDRY_PASSWORD} ]; then echo "FOUNDRY_PASSWORD is unset" ; exit ; fi

export TF_VAR_do_token=${DO_KEY}
export TF_VAR_pvt_key=${PVT_KEY}
export TF_VAR_foundry_user=${FOUNDRY_USERNAME}
export TF_VAR_foundry_password=${FOUNDRY_PASSWORD}
export TF_VAR_duckdns_token=${DNS_TOKEN}
export TF_VAR_duckdns_subdomain=${DNS_DOMAIN}
export TF_VAR_certs=${CERTS}

worldbundler

if [ $? -eq 0 ]
then
    # terraform apply -var "do_token=${DO_KEY}" -var "pvt_key=${PVT_KEY}" -var "foundry_user=${FOUNDRY_USERNAME}" -var "foundry_password=${FOUNDRY_PASSWORD}" -auto-approve
    # SSH_AUTH_SOCK= prevents Terraform's SSH client from consulting the macOS SSH agent.
    # Both connection blocks already supply private_key directly, so the agent is never
    # needed. Without this, the agent interaction corrupts the local tty even with </dev/null.
    SSH_AUTH_SOCK= terraform apply -auto-approve </dev/null 2>&1 | tee terraform-apply.log
    TF_EXIT=${PIPESTATUS[0]}
else
    exit
fi

if [ $TF_EXIT -eq 0 ]
then
ipv4_address=`terraform show -json |jq '.values.root_module.resources[] |select(.address=="digitalocean_droplet.foundryvtt").values.ipv4_address' | sed -e 's/^"//' -e 's/"$//'`
echo 'IP address:' ${ipv4_address}

# DNS=`curl https://www.duckdns.org/update/${DNS_DOMAIN}/${DNS_TOKEN}/${ipv4_address}`
# echo 'Updating DNS:' ${DNS}

sleep 1
open https://${DNS_DOMAIN}.duckdns.org:30000/
else
    echo "Something went wrong: $?"
fi