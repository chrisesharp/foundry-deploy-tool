#!/bin/bash

source ../.env

if [ -z ${FOUNDRY_USERNAME} ]; then echo "FOUNDRY_USERNAME is unset" ; exit ; fi
if [ -z ${FOUNDRY_PASSWORD} ]; then echo "FOUNDRY_PASSWORD is unset" ; exit ; fi

CLOUD=$1
export IMAGE=foundryvtt
# export VERSION=9.280
# export FOUNDRY_VERSION=9.280
export VERSION=11.308.0
export FOUNDRY_VERSION=11.308
export IBMREG=de.icr.io/ces-images
export GKEREG=us.gcr.io/foundry-vtt-294720
export DOREG=registry.digitalocean.com/chrisesharp

case $CLOUD in
  ("ibm") export REPO=$IBMREG/$IMAGE ;;
  ("gke") export REPO=$GKEREG/$IMAGE ;;
  ("do")
    export REPO=$DOREG/$IMAGE
    docker login -u ${DO_PAT} -p ${DO_PAT} $DOREG
    ;;
  ("") echo "Need to specify cloud [ibm|gke|do]"; exit ;;
esac 

docker build \
  --build-arg VERSION=$VERSION \
  --build-arg FOUNDRY_MINIFY_STATIC_FILES=true \
  --tag $REPO:$VERSION \
  https://github.com/felddy/foundryvtt-docker.git#develop
  # --build-arg FOUNDRY_VERSION=$FOUNDRY_VERSION \
# docker build \
#   --build-arg FOUNDRY_USERNAME=\'${FOUNDRY_USERNAME}\' \
#   --build-arg FOUNDRY_PASSWORD=\'${FOUNDRY_PASSWORD}\' \
#   --build-arg VERSION=${VERSION} \
#   --tag $REPO:$VERSION \
#   https://github.com/felddy/foundryvtt-docker.git#develop

docker push $REPO:$VERSION
