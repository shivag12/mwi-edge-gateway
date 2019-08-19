#!/bin/bash

#############################################################################
# Copyright 2019 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#############################################################################


set +x

chmod +x ./envvars.sh
source ./envvars.sh
BASEDIR=${PWD}

function isPortFree() {
    USED=$(netstat -tulpn | grep LISTEN | grep ":$1 ")
    if [ "$USED" == "" ]; then
	true
    else
	false
    fi
}

function getFreePort() {
    FREE_PORT="false"
    PORT=0
    while [ "$FREE_PORT" == "false" ]
    do
	PORT=$(shuf -i 2000-65000 -n 1)
       	FREE_PORT=$(isPortFree $PORT)
    done
    echo $PORT
}

function createInputJson() {
  echo "Create input json"
  if [ -f "${INPUT_FILE}" ];
  then
    rm "${INPUT_FILE}"
  fi

  cat <<EOT >> "${INPUT_FILE}"
  {
      "services": [
          {
              "org": "$HZN_ORG_ID",
              "url": "$SERVICE_URL",
              "versionRange": "$VERSION_RANGE",
              "variables": {
                "MWI_TENANT_ID": "$MWI_TENANT_ID",
                "TENANT_ID": "$MWI_TENANT_ID",
                "MWI_HOST":"$MWI_HOST",
                "LOG_DNA_KEY": "$LOG_DNA_KEY",
                "LOG_TO_CLOUD": "$LOG_TO_CLOUD",
                "WIOTP_DEVICE_TYPE": "$WIOTP_DEVICE_TYPE",
                "WIOTP_DEVICE_ID": "$WIOTP_DEVICE_ID",
                "WIOTP_CLIENT_ID": "$WIOTP_CLIENT_ID",
                "WIOTP_DEVICE_PW": "$WIOTP_DEVICE_PW",
                "WIOTP_ORG": "$WIOTP_ORG",
                "MWI_USER_ID": "$MWI_USER_ID",
                "MWI_ORG_KEY": "$MWI_CONTEXT"
              }
          }
      ]
  }
EOT
}

function uninstall() {
  echo "Uninstall HORIZON and DOCKER if present"
  ./setupEdgeNode.sh --uninstall
}

function install() {
  echo "Find available port for Horizon ..."
  HZN_API_LISTEN=$(getFreePort)
  HORIZON_URL="http://127.0.0.1:${HZN_API_LISTEN}"
  export HZN_API_LISTEN
  export HORIZON_URL
  echo "Using Port ${HZN_API_LISTEN}"
  echo "Install HORIZON and DOCKER"
  ./setupEdgeNode.sh -o "${WIOTP_ORG}" -dt "${WIOTP_DEVICE_TYPE}" -di "${WIOTP_DEVICE_ID}" -dp "${WIOTP_DEVICE_PW}" -cf "${INPUT_FILE}" -v
}

function configure() {
  cp ${BASEDIR}/configs/routing.json /etc/wiotp-edge/routing.json
  sed "s/URL_PLACEHOLDER/http:\/\/127.0.0.1:${HZN_API_LISTEN}/g" ${BASEDIR}/configs/mwi_startup.sh > /etc/profile.d/mwi_startup.sh
  chmod +x /etc/profile.d/mwi_startup.sh
}

uninstall
createInputJson
install
configure
