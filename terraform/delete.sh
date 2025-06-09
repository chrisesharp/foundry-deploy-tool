#!/bin/bash

source ../.env

if [ -z ${FOUNDRY_USERNAME} ]; then echo "FOUNDRY_USERNAME is unset" ; exit ; fi
if [ -z ${FOUNDRY_PASSWORD} ]; then echo "FOUNDRY_PASSWORD is unset" ; exit ; fi

export TF_VAR_do_token=${DO_KEY}
export TF_VAR_pvt_key=${PVT_KEY}
export TF_VAR_foundry_user=${FOUNDRY_USERNAME}
export TF_VAR_foundry_password=${FOUNDRY_PASSWORD}
# terraform destroy -var "do_token=${DO_KEY}" -var "pvt_key=${PVT_KEY}" -var "foundry_user=${FOUNDRY_USERNAME}" -var "foundry_password=${FOUNDRY_PASSWORD}" -auto-approve
terraform destroy -auto-approve