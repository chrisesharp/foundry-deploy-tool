#!/bin/bash

docker run -it --env CONTAINER_VERBOSE=true --env-file .env -p 30000:30000/tcp -v ./mnt/FoundryVTT:/data -u 421:421 felddy/foundryvtt:13

