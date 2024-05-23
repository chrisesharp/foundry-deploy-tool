#!/bin/bash

source ../.env

if [ -z ${FOUNDRY_USERNAME} ]; then echo "FOUNDRY_USERNAME is unset" ; exit ; fi
if [ -z ${FOUNDRY_PASSWORD} ]; then echo "FOUNDRY_PASSWORD is unset" ; exit ; fi

CLOUD=$1
export IMAGE=foundryvtt
# export VERSION=11.315.1
# export FOUNDRY_VERSION=11.315.1
export VERSION=12.320.0
export FOUNDRY_VERSION=12.320
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

# docker buildx build --builder multi --platform linux/amd64,linux/arm64 \
docker build \
  --push \
  --build-arg FOUNDRY_MINIFY_STATIC_FILES=true \
  --build-arg FOUNDRY_USERNAME=$FOUNDRY_USERNAME \
  --build-arg FOUNDRY_PASSWORD=$FOUNDRY_PASSWORD \
  --build-arg VERSION=$VERSION \
  --build-arg FOUNDRY_VERSION=$FOUNDRY_VERSION \
  --tag $REPO:$VERSION \
  https://github.com/felddy/foundryvtt-docker.git#develop

# docker build \
#   --push \
#   --build-arg VERSION=$VERSION \
#   --build-arg FOUNDRY_MINIFY_STATIC_FILES=true \
#   --tag $REPO:$VERSION \
#   https://github.com/felddy/foundryvtt-docker.git#develop

