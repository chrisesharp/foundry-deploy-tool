#!/bin/bash

source ../.env

if [ -z ${FOUNDRY_USERNAME} ]; then echo "FOUNDRY_USERNAME is unset" ; exit ; fi
if [ -z ${FOUNDRY_PASSWORD} ]; then echo "FOUNDRY_PASSWORD is unset" ; exit ; fi

export TF_VAR_do_token=${DO_KEY}
export TF_VAR_pvt_key=${PVT_KEY}
export TF_VAR_pub_key=${PUB_KEY}
export TF_VAR_foundry_user=${FOUNDRY_USERNAME}
export TF_VAR_foundry_password=${FOUNDRY_PASSWORD}
export TF_VAR_duckdns_token=${DNS_TOKEN}
export TF_VAR_duckdns_subdomain=${DNS_DOMAIN}
# Auto-detect public IPv4 and IPv6 addresses; fall back to OPERATOR_IP from .env if detection fails
DETECTED_IPV4=$(curl -4 -s --max-time 3 https://ifconfig.me 2>/dev/null || curl -4 -s --max-time 3 https://api.ipify.org 2>/dev/null)
DETECTED_IPV6=$(curl -6 -s --max-time 3 https://ifconfig.me 2>/dev/null || curl -6 -s --max-time 3 https://api64.ipify.org 2>/dev/null)
DETECTED_IPS=$(echo "${DETECTED_IPV4} ${DETECTED_IPV6}" | xargs | tr ' ' ',')
export TF_VAR_operator_ip=${DETECTED_IPS:-${OPERATOR_IP}}

# terraform destroy -var "do_token=${DO_KEY}" -var "pvt_key=${PVT_KEY}" -var "foundry_user=${FOUNDRY_USERNAME}" -var "foundry_password=${FOUNDRY_PASSWORD}" -auto-approve
SSH_AUTH_SOCK= terraform destroy -auto-approve </dev/null 2>&1 | tee terraform-destroy.log