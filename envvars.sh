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


# *****************************  EDIT HERE ***************************** #
# Watson IoT Platform
WIOTP_ORG=""
WIOTP_REGION="" # us,uk,ch,de,nl
WIOTP_DEVICE_TYPE=""
WIOTP_DEVICE_ID=""
WIOTP_DEVICE_TOKEN=""
# Maximo Worker Insights
MWI_HOST=""
MWI_TENANT=""
MWI_CONTEXT=""
MWI_USER_ID=""
# LogDNA (optional)
LOG_TO_CLOUD=true
LOG_DNA_KEY=""
# **************************** EDIT END ******************************** #

HZN_ORG_ID="${HZN_ORG_ID:-IBM-WorkerInsight}"
SERVICE_URL="${SERVICE_URL:-https://internetofthings.ibmcloud.com/service/iot-gateway-client}"
VERSION_RANGE="${VERSION_RANGE:-[0.0.0,INFINITY)}"
HZN_API_LISTEN="${HZN_API_LISTEN:-8888}"
HORIZON_URL="http://127.0.0.1:${HZN_API_LISTEN}"
# Watson IoT Platform
WIOTP_CLIENT_ID="g:${WIOTP_ORG}:${WIOTP_DEVICE_TYPE}:${WIOTP_DEVICE_ID}"
WIOTP_DEVICE_PW="${WIOTP_DEVICE_TOKEN}"
WIOTP_SOLUTION=""
# Maximo Worker Insights
MWI_TENANT_ID="${MWI_TENANT}"
TENANT_ID="${MWI_TENANT}"
# Edge
INPUT_FILE="$(pwd)/input.json"

export WIOTP_ORG
export WIOTP_ORG_ID
export WIOTP_REGION
export WIOTP_DEVICE_TYPE
export WIOTP_DEVICE_ID
export WIOTP_CLIENT_ID
export WIOTP_DEVICE_TOKEN
export WIOTP_DEVICE_PW
export WIOTP_SOLUTION

export HZN_ORG_ID
export SERVICE_URL
export VERSION_RANGE

export INPUT_FILE

export MWI_HOST
export MWI_TENANT
export MWI_TENANT_ID
export TENANT_ID
export MWI_CONTEXT
export MWI_USER_ID
export HORIZON_URL
