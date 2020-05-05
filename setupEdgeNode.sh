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

AGENT_INSTALLER_VERION=1.0
export AGENT_INSTALLER_VERION

# Unset the following variables if installing using horizon released package.
HORIZONVERSION=
# HORIZONVERSION="2.22.10~la~ppa~raspbian.stretch"
export HORIZONVERSION
HORIZONREPO=
# HORIZONREPO=testing
export HORIZONREPO

# Change the following variables if default domain and region is different
WIOTP_INSTALL_REGION="us"
export WIOTP_INSTALL_REGION
WIOTP_INSTALL_DOMAIN="internetofthings.ibmcloud.com"
export WIOTP_INSTALL_DOMAIN

CURDIR=`pwd`
export CURDIR


# Get OS and architecture
DISTID=$(lsb_release -is)
export DISTID
CODENAME=$(lsb_release -cs)
export CODENAME
ARCH=$(dpkg --print-architecture)
export ARCH

# Logging and error handling functions
function log() { printf '%s\n' "$*"; }
function error() { log "ERROR: $*" >&2; }
function fatal() { error "$*"; exit 1; }
function usage_fatal() { error "$*"; usage >&2; exit 1; }


# Help
function usage() {
    cat <<EOF
Usage: Command to install horizon packages and register to run Core IoT Services
       To install:   $0 --install
       To uninstall: $0 --uninstall
       To install and configure: $0 -o <org> -dt <deviceType> -di <deviceId> -dp <deviceToken>

Options:
  -h,        --help                 Display this usage message and exit.
  -v,        --verbose              Verbose output.
  -i,        --install              Install Edge Agent and dependent packages.
  -u,        --uninstall            Uninstall Edge Agent and dependent packages.
  -o <val>,  --org <val>            WIoTP Organization Id. Required for configuration.
  -dt <val>, --deviceType <val>     Edge Gateway type. Required for configuration.
  -di <val>, --deviceId <val>       Edge Gateway Id. Required for configuration.
  -dp <val>, --deviceToken <val>    Edge Gateway token. Required for configuration.
  -cf <val>, --customFile <val>     Horizon custom input file path
  -dm <val>, --domain <val>         WIoTP internet domain.
                                    Default is internetofthings.ibmcloud.com.
  -r <val>,  --region <val>         WIoTP Organization Region: us,uk,ch,de,nl.
                                    Default is us.
  -cn <val>, --edgeCN <val>         Common Name (CN) to be used for the Server
                                    Certificate for the Edge Connector.
  -te <val>, --testEnv <val>        WIoTP Test envionment.
  -tp <val>, --testCertPath <val>   WIoTP Test environment CA certificate path.


Example for WIoTP public or test enviironment:
sudo ./$0 -o "xxxxxx" -dt "GWType1" -di "GWNode1" -dp "testPassw0rd"
sudo ./$0 -o "xxxxxx" -dt "GWType1" -di "GWNode1" -dp "testPassw0rd" -te "hou02-1.test" -tp "/wiotp/test_env_ca.pem"


EOF
}


#
# Install Horizon agent and CLI, and configure it for WIoTP core services
#
function installAgent() {
    log "Install Edge Agent and dependent packaages"

    if [ "${CODENAME}" == "buster" ] ; then
        NEEDRESTART_SUSPEND=true
        export NEEDRESTART_SUSPEND
    fi

    # Check and install docker
    docker -v > /dev/null 2>&1
    if [ $? -ne 0 ]
    then
        echo "Install docker"
        apt-get update
        apt-get install -y -qq make wget jq mosquitto-clients apt-transport-https ca-certificates curl net-tools lsb-release wget

        if [ "${CODENAME}" == "buster" ] ; then

            # Workaround for installing dockerr on buster
            apt-get install sudo
            sudo apt-get -y -qq install apt-transport-https gnupg2 software-properties-common
            curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
            sudo add-apt-repository "deb [arch=${ARCH}] https://download.docker.com/linux/debian buster stable"
            sudo apt-get update -qq
            # sudo apt-get install -y -qq docker-ce docker-compose

        else

            curl -fsSL get.docker.com | sh
            apt-get update -qq

        fi
    fi

    # Install horizon and horizon-cli
    isInstalled=1
    # check for horizon-cli
    hzn version > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        isInstalled=0
    fi
    # check for horizon
    if [ ! -d /etc/horizon ]; then
        isInstalled=0
    fi

    if [ $isInstalled -eq 0 ]
    then
        echo "Install horizon"
        wget -qO - http://pkg.bluehorizon.network/bluehorizon.network-public.key | apt-key add -
        aptrepo=updates
        if [[ ! -z $HORIZONREPO ]]; then
            aptrepo=$HORIZONREPO
	fi

        # set repo list
        repoListFile="/etc/apt/sources.list.d/bluehorizon.list"

        if [ "${CODENAME}" == "bionic" ] || [ "${CODENAME}" == "xenial" ] ; then
            CODENAME=xenial
            echo "deb [arch=${ARCH}] http://pkg.bluehorizon.network/linux/ubuntu $CODENAME-la-$aptrepo main" > $repoListFile
        fi

        if [ "${CODENAME}" == "jessie" ] || [ "${CODENAME}" == "stretch" ] || [ "${CODENAME}" == "buster" ] ; then
            # set to stretch till EF releases pakcges for other versions
            CODENAME=stretch

            if [ "${ARCH}" == "" ] ; then
                ARCH="armhf"
            fi

            if [ "${DISTID}" == "Debian" ]  || [ "${DISTID}" == "debian" ] ; then
                echo "deb [arch=$ARCH] http://pkg.bluehorizon.network/linux/debian $CODENAME-$aptrepo main" > $repoListFile
            else
                echo "deb [arch=$ARCH] http://pkg.bluehorizon.network/linux/raspbian $CODENAME-la-$aptrepo main" > $repoListFile
            fi

        fi

        apt-get update

        if [[ -z $HORIZONREPO ]]; then
            apt-get install -y horizon horizon-cli
        else
            if [[ -z $HORIZONVERSION ]]; then
                apt-get install -y horizon horizon-cli
            else
                apt-get install -y horizon=${HORIZONVERSION} horizon-cli=${HORIZONVERSION}
            fi
        fi
    fi

    if [ "${CODENAME}" == "buster" ] ; then
        NEEDRESTART_SUSPEND=
        export NEEDRESTART_SUSPEND
    fi
}

#
# Uninstall unregister node and uninstall horizon
#
function uninstallAgent() {
    # Check if dependent packages are installed
    if [ ! -d /etc/horizon ]; then
        fatal "Edge agent and dependent packages are not found"
    fi

    log "Uninstall Edge Agent and dependent packaages"

    if [ "${CODENAME}" == "buster" ] ; then
        NEEDRESTART_SUSPEND=true
        export NEEDRESTART_SUSPEND
    fi

    hzn unregister
    apt-get purge -y horizon
    apt-get purge -y horizon-cli
    apt-get purge -y docker-ce
    apt-get purge -y docker-ce-cli

    if [ "${CODENAME}" == "buster" ] ; then
        NEEDRESTART_SUSPEND=
        export NEEDRESTART_SUSPEND
    fi

    # remove any residual config files
    rm -rf /etc/horizon > /dev/null 2>&1
    rm -rf /etc/wiotp-edge > /dev/null 2>&1
    rm -rf /var/wiotp-edge > /dev/null 2>&1
}


#
# Create edge config template
#
function createEdgeConfigTemplate() {
    log "Create WIoTP edge config template"

cat <<EOF > /etc/wiotp-edge/edge.conf.template
# Configuration file for the Edge-Node.
# Configuration item details are iin GitHub

### Mandatory Configuration
GatewayClientId
GatewayAuthToken

### Basic Configuration Parameters
PersistenceRootPath /var/wiotp-edge/persist
LogRootPath /var/wiotp-edge/log
TraceRootPath /var/wiotp-edge/trace
LogLevel INFO
TraceLevel INFO
MaxDevices 100
StoreRetentionTime 3600
StoreRetentionBytes 52428800

### Advanced Configuration Parameters
DeviceSecuredPort 8883
DeviceNonSecuredPort 0
LocalBrokerAddress edge-mqttbroker
LocalBrokerCaFile /broker/ca/ca.cert.pem
LocalBrokerPort 2883
TotalTraceSizePercent 10
TraceFileSizeKB 20000
LogToSyslog false
LogToCloud false
StdoutTrace false

### Edge Connector (EC) configuration parameters
EC.CloudMqttKeepAlive 10
EC.StartupConnTimeout 60
EC.ReconnectTimeout 30
EC.CloudReconInterval 10
EC.QuiescenceTime 5
EC.cloudPort 8883
# Default value of EC CloudAddress: <orgId>.messaging.internetofthings.ibmcloud.com
# EC.CloudAddress
# EC.CloudCaFile
EC.EnableMqttPersistence false
EC.StoreFlushIntervalMilli 10000
EC.StoreColdStart false
EC.DeviceAuthCache Persist
EC.WildcardSubscription false
EC.CloudCleanSession false
IM.ForwardUnprocessedMessages True

EOF

}

#
# Create edgeCoreIoT service template
#
function createCoreIoTServiceTempate() {
    log "Create WIoTP Core IoT service template"

cat <<EOF > /etc/wiotp-edge/hznEdgeCoreIoTInput.json.services.template
{
    "services": [
        {
            "org": "IBM-WIoTP",
            "url": "https://internetofthings.ibmcloud.com/wiotp-edge/services/core-iot",
            "versionRange": "[0.0.0,INFINITY)",
            "variables": {
            }
        }
    ]
}

EOF
}

# Create certs for edge
function createEdgeCertificate() {
    CA_PASSWORD=$WIOTP_INSTALL_DEVICE_TOKEN
    CN_ADDRESS_PARAM=$WIOTP_INSTALL_EDGE_CN

    # Insure that openssl is installed on the edge node
    OPENSSL_PATH=$(command -v openssl)
    if [[ -z $OPENSSL_PATH ]]; then
      fatal "The openssl command, which is required by this shell script, is not installed on this system."
    fi

    if [[ -z $CN_ADDRESS_PARAM ]]; then
      EXTRA_SUBJECT_NAMES=""
    else
      IP_ADDRESS_REGEX='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'
      IP_ADDRESS_REGEX+='0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))$'
      if [[ ${CN_ADDRESS_PARAM} =~ ${IP_ADDRESS_REGEX} ]]; then
        EXTRA_SUBJECT_NAMES="IP:${CN_ADDRESS_PARAM}, "
      else
        EXTRA_SUBJECT_NAMES="DNS:${CN_ADDRESS_PARAM}, "
      fi
    fi

    # get list of network addresses on this computer
    ADDRESSES=()

    if [ "Linux" = "$(uname)" ]; then

      ADDRESS=""
      ACTIVE=""
      while read -r LINE; do
        WORDS=($LINE)
        PREFIX="${WORDS[0]%:}"
        if [[ "${PREFIX}" =~ ^[0-9]+$ ]]; then
          if [ "${ADDRESS}" != "" ] && [ "${ACTIVE}" != "" ]; then
            ADDRESSES+=($ADDRESS)
            ADDRESS=""
            ACTIVE=""
          fi
          if [ "${WORDS[8]}" = "UP" ]; then
            ACTIVE="Y"
          fi
        elif [ "${WORDS[0]}" = "inet" ]; then
          ADDRESS="${WORDS[1]%/*}"
        fi
      done < <(ip address)

      if [ "${ADDRESS}" != "" ] && [ "${ACTIVE}" != "" ]; then
        ADDRESSES+=($ADDRESS)
      fi

    elif [ "Darwin" = "$(uname)" ]; then

      for INTERFACE in $(ifconfig -l) ; do
        ADDRESS=""
        ACTIVE=""
        while read -r WORD1 WORD2 REST; do
          if [ "${WORD1}" = "inet" ]; then
            ADDRESS="${WORD2}"
          elif [ "${WORD1}" = "status:" ] && [ "${WORD2}" = "active" ]; then
            ACTIVE="Y"
          fi
        done < <(ifconfig ${INTERFACE})
        if [ "${ADDRESS}" != "" ] && [ "${ACTIVE}" != "" ]; then
          ADDRESSES+=($ADDRESS)
        fi
      done

    else
      fatal "You are running this script on an unsupported Operating system."
    fi

    ADDRESS_COUNT=${#ADDRESSES[@]}
    if [ $ADDRESS_COUNT -eq 0 ]; then
      if [ -z $CN_ADDRESS_PARAM ]; then
        log "No network interfaces were discovered and neither the"
        log "-cn parameter nor the --edgeConnectorCN parameter was specified."
        log "Rerun after fixing the network interfaces or specify"
        log "either the -cn parameter or the --edgeConnectorCN parameter."
        exit 1
      else
        CN_ADDRESS=${CN_ADDRESS_PARAM}
      fi
    else
      for ADDRESS in ${ADDRESSES[@]}; do
        if [ -z ${CN_ADDRESS} ]; then
          CN_ADDRESS=${ADDRESS}
        else
          EXTRA_SUBJECT_NAMES="${EXTRA_SUBJECT_NAMES}IP:${ADDRESS}, "
        fi
      done
    fi

    # Read the config file for the persistence root directory
    if [ -z $CONFIG_FILE ]; then
      CONFIG_FILE=/etc/wiotp-edge/edge.conf
    fi

    logIfVerbose "Config File: $CONFIG_FILE will be used."

    PERSIST_ROOT_DIRECTORY=/var/wiotp-edge/persist

    while read -r LINE; do

      if [ "${LINE}" != "" ] && [ "${LINE:0:1}" != "#" ]; then
        FIELDS=($LINE)

        if [ "${FIELDS[0]}" == "PersistenceRootPath" ] && [ "${FIELDS[1]}" != "" ]; then
          PERSIST_ROOT_DIRECTORY=${FIELDS[1]}
        fi
      fi

    done < ${CONFIG_FILE}

    # Determine the country based on the locale for the time
    if [ "Darwin" = "$(uname)" ]; then
       COUNTRY=US
    else
       COUNTRY=$(echo "${LC_TIME}" | awk '{ print substr( $0, 4, 2 ) }')
       if [ "${COUNTRY}" == "" ]; then
          COUNTRY=US
       fi
    fi

# Create a configuration file to create the CA
sed /\$COUNTRY/s//${COUNTRY}/ <<'EOF' > ca.conf
[ req ]
    default_bits           = 2048
    default_keyfile        = key.pem
    distinguished_name     = req_distinguished_name
    prompt                 = no
    output_password        =
    req_extensions         = v3_ca
[ req_distinguished_name ]
    C                      = $COUNTRY
    ST                     = CAState
    L                      = CACity
    O                      = CAOrg
    OU                     = Edge Node
    CN                     = localhost
    emailAddress           = some@thing
[ v3_ca ]
    basicConstraints       = CA:true

EOF

# Create a configuration file to create the certificate request for the broker
sed /\$COUNTRY/s//${COUNTRY}/ <<'EOF' > broker.conf
[ req ]
    default_bits           = 2048
    default_keyfile        = key.pem
    distinguished_name     = req_distinguished_name
    prompt                 = no
    output_password        =
[ req_distinguished_name ]
    C                      = $COUNTRY
    ST                     = SomeState
    L                      = SomeCity
    O                      = SomeOrg
    OU                     = Edge Node
    CN                     = localhost
    emailAddress           = some@thing

EOF

# Create a configuration file to create the certificate request for the connector
sed "/\COUNTRY/s//${COUNTRY}/; /\CN_ADDRESS/s//${CN_ADDRESS}/g; /\EXTRA_SUBJECT_NAMES/s//${EXTRA_SUBJECT_NAMES}/" <<'EOF' > connector.conf
[ req ]
    default_bits           = 2048
    default_keyfile        = key.pem
    distinguished_name     = req_distinguished_name
    prompt                 = no
    output_password        =
    req_extensions         = v3_req
[ req_distinguished_name ]
    C                      = COUNTRY
    ST                     = SomeState
    L                      = SomeCity
    O                      = SomeOrg
    OU                     = Edge Node
    CN                     = CN_ADDRESS
    emailAddress           = some@thing
[ v3_req ]
    subjectAltName = IP:CN_ADDRESS, EXTRA_SUBJECT_NAMES DNS:edge-connector, DNS:localhost, IP:127.0.0.1

EOF

    # Get the password for the CA key file
    if [ -z $CA_PASSWORD ]; then
      read -s -p "Enter password for the CA key file: " CA_PASSWORD
      if [[ ${#CA_PASSWORD} -lt 4 ]]; then
          fatal "The CA file password was less then four characters long"
      fi
      read -s -p "Verify the password for the CA key file: " CA_PASSWORD_VERIFY
      echo
      if [[ ${CA_PASSWORD} != ${CA_PASSWORD_VERIFY} ]]; then
          fatal "The password for the CA file didn't verify"
      fi
      echo ""
    else
      logIfVerbose "The CA Private key is configured to use the device credential password by default."
    fi

    BROKER_DIR=${PERSIST_ROOT_DIRECTORY}/broker
    DC_DIR=${PERSIST_ROOT_DIRECTORY}/dc

    # Create directories to hold files
    mkdir -p ${BROKER_DIR}/ca
    mkdir -p ${BROKER_DIR}/certs
    mkdir -p ${DC_DIR}/ca
    mkdir -p ${DC_DIR}/certs

    # Cleanup old files in case they exist
    rm -f ${BROKER_DIR}/ca/ca.key.pem ${BROKER_DIR}/ca/ca.cert.pem
    rm -f ${BROKER_DIR}/certs/broker_key.pem ${BROKER_DIR}/certs/broker_cert.pem
    rm -f ${DC_DIR}/certs/key.pem ${DC_DIR}/certs/cert.pem ${DC_DIR}/ca/ca.pem

    # Generating the key and certificate for the CA
    output=$(echo "${CA_PASSWORD}" | openssl genrsa -aes256 -passout stdin -out ${BROKER_DIR}/ca/ca.key.pem 4096 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"


    chmod 400 ${BROKER_DIR}/ca/ca.key.pem

    output=$(echo "${CA_PASSWORD}" | openssl req -key ${BROKER_DIR}/ca/ca.key.pem  -new -x509 \
                                             -days 7300 -sha256 -extensions v3_ca \
                                             -out ${BROKER_DIR}/ca/ca.cert.pem -passin stdin \
                                             -config ca.conf 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    chmod 444 ${BROKER_DIR}/ca/ca.cert.pem


    # Generating the key and certificate for the local broker
    output=$(openssl genrsa -aes256 -passout pass:passw0rd -out key.pem 2048 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    output=$(openssl rsa -in key.pem -passin pass:passw0rd -out ${BROKER_DIR}/certs/broker_key.pem 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    chmod 400 ${BROKER_DIR}/certs/broker_key.pem

    output=$(openssl req -new -key ${BROKER_DIR}/certs/broker_key.pem -out ${BROKER_DIR}/certs/broker.csr \
                -config broker.conf 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    output=$(echo "${CA_PASSWORD}" | openssl x509 -req -in ${BROKER_DIR}/certs/broker.csr -days 500 -sha256 \
                                         -CA ${BROKER_DIR}/ca/ca.cert.pem -CAkey ${BROKER_DIR}/ca/ca.key.pem \
                                         -CAcreateserial -out ${BROKER_DIR}/certs/broker_cert.pem \
                                         -passin stdin 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    chmod 444 ${BROKER_DIR}/certs/broker_cert.pem


    # Generating the key and certificate for the edge-connector
    output=$(openssl genrsa -aes256 -passout pass:passw0rd -out key.pem 2048 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    output=$(openssl rsa -in key.pem -passin pass:passw0rd -out ${DC_DIR}/certs/key.pem 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    chmod 400 ${DC_DIR}/certs/key.pem

    output=$(openssl req -new -key ${DC_DIR}/certs/key.pem -out ${DC_DIR}/certs/cert.csr \
                -config connector.conf 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    output=$(echo "${CA_PASSWORD}" | openssl x509 -req -in ${DC_DIR}/certs/cert.csr -days 500 -sha256 \
                                         -CA ${BROKER_DIR}/ca/ca.cert.pem -CAkey ${BROKER_DIR}/ca/ca.key.pem \
                                         -CAcreateserial -out ${DC_DIR}/certs/cert.pem \
    				         -extfile connector.conf -extensions v3_req \
                                         -passin stdin 2>&1)
    checkrc $? "$output"
    logIfVerbose "$output"

    chmod 444 ${DC_DIR}/certs/cert.pem

    cp ${BROKER_DIR}/ca/ca.cert.pem ${DC_DIR}/ca/ca.pem
    rm key.pem broker.conf connector.conf ca.conf

}


# Fetch WIoTP CA certificates using openssl command
function getWIoTPCertfiicates() {
    log "Set CA Certs for the WIoTP"
    mkdir -p /tmp/wiotp_certs
    cd /tmp/wiotp_certs
    rm -f wiotpcerts*.pem
    HOST=$httpDomain
    PORT="443"
    if [[ ! -z $WIOTP_INSTALL_TEST_ENV ]] ; then
        HOST="$WIOTP_INSTALL_TEST_ENV.internetofthings.ibmcloud.com"
	if [[ ! -z $WIOTP_INSTALL_TEST_CAPATH ]] ; then
	    # Copy Test CA to required location
	    if [ -f $WIOTP_INSTALL_TEST_CAPATH ] ; then
	        USECAPATH=$WIOTP_INSTALL_TEST_CAPATH
	    fi
	fi
    fi
    PKICERTDIR=/etc/ssl/certs
    if [ -e /etc/pki/tls/certs ] ; then
        PKICERTDIR=/etc/pki/tls/certs
    fi

    # Connect and get certs
    log "Get certificates from $HOST:$PORT using openssl command"
    if [[ ! -z $USECAPATH ]] ; then
        cat $USECAPATH | awk '/BEGIN CERT/ {p=1} ; p==1; /END CERT/ {p=0}' | awk 'split_after == 1 {n++;split_after=0} /-----END CERTIFICATE-----/ {split_after=1} {print > "wiotpcerts" n ".pem"}'
    else
        echo "\n" | openssl s_client -host $HOST -port $PORT -showcerts 2>/dev/null | awk '/BEGIN CERT/ {p=1} ; p==1; /END CERT/ {p=0}' | awk 'split_after == 1 {n++;split_after=0} /-----END CERTIFICATE-----/ {split_after=1} {print > "wiotpcerts" n ".pem"}'
    fi

    # Update horizon pem
    log "Update horizon trust store"
    if [ -f /etc/horizon/trust/horizon.pem ]; then
        mv /etc/horizon/trust/horizon.pem /etc/horizon/trust/horizon.pem.old
    fi
    if [ ! -f /etc/horizon/trust/horizon.pem ]  ; then
        mkdir -p /etc/horizon/trust
	touch /etc/horizon/trust/horizon.pem
    fi
    for i in `ls wiotpcerts*.pem` ; do
        cat $i >> /etc/horizon/trust/horizon.pem
    done

    # Create hash links in PKICERTDIR
    log "Create certificate hash in public trust store"
    j=0
    for i in `ls wiotpcerts*.pem` ; do
	log "Process certificate $i"
        hash=`openssl x509 -hash -in $i -noout`
        f=$PKICERTDIR/wiotpcerts-${HOST}-${PORT}-${j}.pem
	log "Move certificate $i to $f and link to hash ${hash}"
        mv -f $i $f
        j=$((j+1))
        ln -sf $f $PKICERTROOT/${hash}.0
    done

    update-ca-certificates
}

# Create edge component public key file
function createEdgePublicKey() {
    cat << EOF > /etc/wiotp-edge/publicWIoTPEdgeComponentsKey.pem
-----BEGIN CERTIFICATE-----
MIIFCDCCAvCgAwIBAgIUWTk2u96XKFYcvoBH6YH4rPuQAzowDQYJKoZIhvcNAQEL
BQAwLTEMMAoGA1UEChMDSUJNMR0wGwYDVQQDDBR3aW90cC1kZXZAdXMuaWJtLmNv
bTAeFw0xODAzMDkwMzI3MTdaFw0yMzAzMDkxNTI3MTdaMC0xDDAKBgNVBAoTA0lC
TTEdMBsGA1UEAwwUd2lvdHAtZGV2QHVzLmlibS5jb20wggIiMA0GCSqGSIb3DQEB
AQUAA4ICDwAwggIKAoICAQDJl3AgMHJNlkWDDK/Fe/b4MfkOf4UctqCVXwJDqrCq
dxnj798My0aAdprjq6iYP/W5Q859JeMUhNQwgfIWCoM3Q52WaGRZE7SIg5/PziE6
1eZk7KpPApyNFJD7rEKULDF2mh3SXtWd6WQ202CclWgPkvHaVk5Wlq1iaERaxVuO
/260plQGz0cMsesqV/N7mhutqNcG0QDa32/cxsR3ET9l3ObA9JGWufe/Wooklyra
wJqCLPQ4P+LsAGjKqDj58/zDrmKXe5Wnxcr5o9oL0vBoZh0AWtWtMu54iqFnEtke
lNDShguRp4uulfhwTpsw0Ug8DJ0um8qcfRQNL019hkh9k1sKawZgDcKIPVY8YTqZ
SfiIdX/OrE/Khlhe8asLTtxqB91XU2/60j/ChTX+wcNAL8h47CWPKUXiriuatq7M
7hwMv33JAytqQQ67wzbKDyVAWN0Eki/iabUUTl8SGLVkv2Oku1HD+1wqJEQQYIi4
8LxYsll/T6jRnTAiG2NdR0vDBbkgIGkT4nsXaFcqOsyUJ/jWiuhO3F9FWJA7r5jK
39aTWw4SYk3CWOo6EP58tc+wLIgN+jbUC5pivkC9dP/PT92GLHa8tcBc/SsHzXcb
ULU45VlDxYcs/2VazM04LmspmBZdQBrg2AV78W3tUe7+gpT+urqHdfoLMcIG1aXk
wQIDAQABoyAwHjAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADANBgkqhkiG
9w0BAQsFAAOCAgEAGWWhe957QQ5R7XnzLiJd/8fcd2nOeuW30zBnFHZj+KX2pGcU
3BeTfi+OwaEHEAjp/bgN/9O8orqEilmL2/bKvwI7ORF6YJkvi83iqqBKRaUsizTS
ipib/MMqVx1C+bYseAduMQ18pcOly4uvBbH73xlOA8qdpRZ58m3pxbvnvaILbAyJ
YmC3+qSLRBnRKq3d3C+cNJhk2qSZd9Bk2FHp5isxDLpzfhIZo4VKvAatIobjYlYF
ZGyrWNjes7dE47bGNhBFShCgpvjw0Z6olPtHgu8jNF9IaFGRrrKcylj2LsImNHJw
BrapkhAIPKpGDYz6GSHi2vLGazAzggWdg4rimug8kpYIRTkzO8pxMLFmLeXb+V9t
K1ioWojdoRelDn20FTs7K6/1NaiXaxBN4HZ1Ux/VIPtvB+Jf2nIfFfrjWapPtXLi
yZf/mhG70buP1IAmsSfU2U/oAtKpC1s9Epf10Q0YaBD3qtSdcY+QqKs1F7YBwkOn
Ql937kuDqPl+loCIH4DXW+q+ZJmiIBvxvUSaZYhvaYadIb3OTFvw4xtL0xQqewiT
14OYpB/156kLg2XULSwPLc0JhQ1YdG+dmQRv1NJi8X73Hp4HlgCNamJ3zBoukVTK
8hakcJSy6E8J6K1yQZkp86yFouM3/27F33queQbE/XOxgbXdjgGlK7ppAMQ=
-----END CERTIFICATE-----
EOF
}

# Verbose logging
function logIfVerbose() {
  if [ ! -z $VERBOSE ]; then
    log $1
  fi
}

# Error checker
function checkrc {
    if [[ $1 -ne 0 ]]; then
        fatal "Last command exited with rc $1, exiting."
    fi
}


###########################################################################
# Main
#

log "IBM Watson IoT Platform Edge Agent installer and configurator"
log "Version: $AGENT_INSTALLER_VERION"
log ""

# Parse arguments
while [ "$#" -gt 0 ]; do
    arg=$1
    case $1 in
        # convert "--opt=the value" to --opt "the value".
        # the quotes around the equals sign is to work around a
        # bug in emacs' syntax parsing
        --*'='*) shift; set -- "${arg%%=*}" "${arg#*=}" "$@"; continue;;
        -h|--help) usage; exit 0;;
        -i|--install) INSTALL="true";;
        -u|--uninstall) uninstallAgent; exit 0;;
        -o|--org) shift; WIOTP_INSTALL_ORGID=$1;;
        -dt|--deviceType) shift; WIOTP_INSTALL_DEVICE_TYPE=$1;;
        -di|--deviceId) shift; WIOTP_INSTALL_DEVICE_ID=$1;;
        -dp|--deviceToken) shift; WIOTP_INSTALL_DEVICE_TOKEN=$1;;
	-cf|--customFile) shift; CUSTOM_HZN_INPUT_FILE=$1;;
        -te|--testEnv) shift; WIOTP_INSTALL_TEST_ENV=$1;;
        -tp|--testCAPath) shift; WIOTP_INSTALL_TEST_CAPATH=$1;;
        -r|--region) shift; WIOTP_INSTALL_REGION=$1;;
        -dm|--domain) shift; WIOTP_INSTALL_DOMAIN=$1;;
        -cn|--edgeCN) shift; WIOTP_INSTALL_EDGE_CN=$1;;
        -v|--verbose) VERBOSE='-v';;
        -*) usage_fatal "unknown option: '$1'";;
        *) break;; # reached the list of file names
    esac
    shift || usage_fatal "option '${arg}' requires a value"
done

# Set variables
if [ -z $WIOTP_INSTALL_TEST_ENV ]; then
  httpDomainPrefix=$WIOTP_INSTALL_ORGID
  httpDomain=$WIOTP_INSTALL_DOMAIN
  mqttDomainPrefix=$WIOTP_INSTALL_ORGID.messaging
  regionPrefix=$WIOTP_INSTALL_REGION
else
  httpDomainPrefix=$WIOTP_INSTALL_ORGID.$WIOTP_INSTALL_TEST_ENV
  httpDomain=$WIOTP_INSTALL_TEST_ENV.$WIOTP_INSTALL_DOMAIN
  mqttDomainPrefix=$WIOTP_INSTALL_ORGID.messaging.$WIOTP_INSTALL_TEST_ENV
  regionPrefix=$WIOTP_INSTALL_REGION.$WIOTP_INSTALL_TEST_ENV
fi
VAR_DIR="/var"
ETC_DIR="/etc"

INSTALL_AND_REGISTER="true"
if [ "$INSTALL" == "true" ]; then
    INSTALL_AND_REGISTER="false"
fi

# Check if dependent packages are installed
hzn version > /dev/null 2>&1
if [ $? -ne 0 ]; then
    log "Dependent packages are not installed yet. Installing required packages."
    INSTALL="true"
else
    log "Dependent packages are already installed."
fi


# Check for install case
if [ "$INSTALL" == "true" ]; then
    installAgent

    # check if node is already registered
    hzn node list | grep "state" | grep '"state": "configured"' > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        log "Edge node is already registered."
    else
        # Create edge and core-iot configuration templates
        mkdir -p /etc/wiotp-edge
        createEdgeConfigTemplate
        createCoreIoTServiceTempate
        createEdgePublicKey

        # Set WIoTP Certs
        getWIoTPCertfiicates
        cp /etc/wiotp-edge/publicWIoTPEdgeComponentsKey.pem /etc/horizon/trust/.

        # Set anax configuration file
        log "Update anax configuration"
        if [ ! -f /etc/horizon/anax.json ]
        then
            cp /etc/horizon/anax.json.example /etc/horizon/anax.json

            # Read the json object in /etc/horizon/anax.json
            anaxJson=$(jq '.' /etc/horizon/anax.json)
            checkrc $?

            # Change the value of ExchangeURL in /etc/horizon/anax.json
            anaxJson=$(jq ".Edge.ExchangeURL = \"https://$httpDomainPrefix.$WIOTP_INSTALL_DOMAIN/api/v0002/edgenode/\" " <<< $anaxJson)
            checkrc $?

            # Change the value of APIListen in /etc/horizon/anax.json
	          anaxJson=$(jq ".Edge.APIListen = \"127.0.0.1:${HZN_API_LISTEN}\" " <<< $anaxJson)
            checkrc $?

            # Change the value of CSSURL in /etc/horizon/anax.json
            anaxJson=$(jq ".Edge.FileSyncService.CSSURL = \"https://$httpDomainPrefix.$WIOTP_INSTALL_DOMAIN/api/v0002/cssnode/\" " <<< $anaxJson)
            checkrc $?

            # Write the new json back to /etc/horizon/anax.json
            echo "$anaxJson" > $ETC_DIR/horizon/anax.json

            # Updating the bashrc with local API url. 
            # Issue : HZN NODE LIST or HZN AGREEMENT LIST commands are failing because of the APIListen URL is not properly configured,
            # Everytime have to run the mwi_Startup.sh file and in everytime after restart.
            # Fix : Add the API Listen URL in the end of the bashrc file. 
            # Name : Shiva G
            echo -e "export HORIZON_URL = http://127.0.0.1:${HZN_API_LISTEN}" >>  ~/.bashrc

        fi

        # Enable horizon service
        systemctl daemon-reload
        systemctl enable horizon.service
        systemctl restart horizon

        if [ "$INSTALL_AND_REGISTER" == "false" ]; then
            exit 0
        fi

        sleep 5
    fi
fi

# check if node is already registered
hzn node list | grep "state" | grep '"state": "configured"' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    log "Edge node is already registered."

    # Check agreement list
    hzn agreement list
    log
    log "If you want to register this node, unregister and then register the node."
    log
    exit 0
fi

# Check if dependent packages are installed
if [ ! -d /etc/horizon ]; then
    fatal "Dependent packages are not installed yet. Please install required packages using -i or --install option."
fi

# CA certificate file for curl
CACERT='--cacert /etc/horizon/trust/horizon.pem'
if [ "${WIOTP_INSTALL_TEST_ENV}" != "" ] ; then
    VERIFY='-k'
fi

# Check for valid configuration options
if [[ -z $WIOTP_INSTALL_DEVICE_ID ]] || [[ -z $WIOTP_INSTALL_DEVICE_TYPE ]] || [[ -z $WIOTP_INSTALL_DEVICE_ID ]] || [[ -z $WIOTP_INSTALL_DEVICE_TOKEN ]]; then
    usage_fatal "Values for the following options are required: --org, --deviceType, --deviceId, --deviceToken"
fi

# Check for valid regions
if [[ "${WIOTP_INSTALL_REGION}" != "us" && "${WIOTP_INSTALL_REGION}" != "uk" && "${WIOTP_INSTALL_REGION}" != "de" && "${WIOTP_INSTALL_REGION}" != "ch" && "${WIOTP_INSTALL_REGION}" != "nl" ]];then
    usage_fatal "Invalid region."
fi

VAR_DIR="/var"
ETC_DIR="/etc"

# Check if domain exists
log "Verifying domain: https://$httpDomain"
output=$(curl -s $VERBOSE $CACERT -o /dev/null -w "%{http_code}" https://$httpDomain)
if [[ $output -ne 200 ]]; then
  fatal "Could not reach https://$httpDomain. Check if the domain name is correct or CA Certificates in trust store or valid."
fi

# Check if org exists
log "Verifying wiotp organization: https://$httpDomainPrefix.$WIOTP_INSTALL_DOMAIN"
output=$(curl -s $VERBOSE $CACERT -o /dev/null -w "%{http_code}" https://$httpDomainPrefix.$WIOTP_INSTALL_DOMAIN)
if [[ $output -ne 200 ]]; then
  fatal "Could not reach https://$httpDomainPrefix.$WIOTP_INSTALL_DOMAIN. Check if the value passed to --org is correct."
fi

# Verify Device type, Id and Token
log "Verifying Edge gateway device type and Id"
output=$(curl -s $VERBOSE $CACERT -o /dev/null -w "%{http_code}" -u "$WIOTP_INSTALL_ORGID/g@$WIOTP_INSTALL_DEVICE_TYPE@$WIOTP_INSTALL_DEVICE_ID:$WIOTP_INSTALL_DEVICE_TOKEN" https://$httpDomainPrefix.$WIOTP_INSTALL_DOMAIN/api/v0002/edgenode/orgs/$WIOTP_INSTALL_ORGID/nodes/g@$WIOTP_INSTALL_DEVICE_TYPE@$WIOTP_INSTALL_DEVICE_ID)

if [[ $output -ne 200 ]]; then
  log "ERROR: Could not access device $WIOTP_INSTALL_DEVICE_ID of type $WIOTP_INSTALL_DEVICE_TYPE. ResponseCode: $output"
  log "1. Check if 'Edge Capabilities' is enabled in IBM Watson IoT Platform."
  log "2. Check if the device type (with 'Edge Capabilities' toggle was enabled) is created."
  log "3. Check if a device was created under that device type."
  log "4. Make sure the device credentials are correct."
  exit 1
fi


# Create the edge.conf using the edge.conf.template
edge_conf_template_path="${ETC_DIR}/wiotp-edge/edge.conf.template"
edge_conf_path="${ETC_DIR}/wiotp-edge/edge.conf"
cp $edge_conf_template_path $edge_conf_path


# Generate edge-mqttbroker certificates
log "Generating Edge internal certificates ..."
mkdir -p ${VAR_DIR}/wiotp-edge/persist/
createEdgeCertificate
checkrc $?


# Set input file for registering the node.
# If not specified using --file option, the command will use
# default WIoTP core-iot service definition file.
CORE_IOT_HZN_INPUT_FILE=$ETC_DIR/wiotp-edge/hznEdgeCoreIoTInput.json

log "Checking patterns"
output=$(curl -s $VERBOSE $CACERT -H "Content-type: application/json" -u "$WIOTP_INSTALL_ORGID/g@$WIOTP_INSTALL_DEVICE_TYPE@$WIOTP_INSTALL_DEVICE_ID:$WIOTP_INSTALL_DEVICE_TOKEN" https://$httpDomainPrefix.$WIOTP_INSTALL_DOMAIN/api/v0002/edgenode/orgs/$WIOTP_INSTALL_ORGID/patterns/$WIOTP_INSTALL_DEVICE_TYPE)

echo
echo "Patterns:"
echo
echo $output
echo

servicesArray=$(jq -r ".patterns.\"$WIOTP_INSTALL_ORGID/$WIOTP_INSTALL_DEVICE_TYPE\".services | to_entries[]" <<< $output)

logIfVerbose "Pattern in services format."
emptyConfigJson=$(jq '.' ${CORE_IOT_HZN_INPUT_FILE}.services.template)
checkrc $?
arrayKey="services"
servicesFormat=true

# By default WIoTP Edge core-iot
# Create the hznEdgeCoreIoTInput.json using the hznEdgeCoreIoTInput.json.template and user inputs
log "Creating hzn config input file"

configJson=$(jq ".\"$arrayKey\"[0].variables.WIOTP_DEVICE_AUTH_TOKEN = \"$WIOTP_INSTALL_DEVICE_TOKEN\" " <<< $emptyConfigJson)
checkrc $?

configJson=$(jq ".\"$arrayKey\"[0].variables.WIOTP_DOMAIN = \"$mqttDomainPrefix.$WIOTP_INSTALL_DOMAIN\" " <<< $configJson)
checkrc $?

configJson=$(jq ".\"$arrayKey\"[0].variables.WIOTP_CLIENT_ID = \"g:$WIOTP_INSTALL_ORGID:$WIOTP_INSTALL_DEVICE_TYPE:$WIOTP_INSTALL_DEVICE_ID\" " <<< $configJson)
checkrc $?

# Write the service json definition file
echo "$configJson" > $CORE_IOT_HZN_INPUT_FILE

if [[ ! -z $CUSTOM_HZN_INPUT_FILE ]]; then
    if [[ -e $CUSTOM_HZN_INPUT_FILE ]]; then

        logIfVerbose "Merging custom hzn config input file ..."

        # Temporary files to store the arrays of both hznEdgeCoreIoTInput.json and
        # the custom service input json passed to "-f"
        # so that "jq -s '.=.|add'" command can concatenated the arrays
        CORE_IOT_ARRAY_FILE="/tmp/origArray.json"
        CUSTOM_ARRAY_FILE="/tmp/customArray.json"

        # Read the Json object from hznEdgeCoreIoTInput.json
        coreIoTJson=$(jq '.' $CORE_IOT_HZN_INPUT_FILE)
        checkrc $?
        # Read the Json object from the custom service input json
        customJson=$(jq '.' $CUSTOM_HZN_INPUT_FILE)
        checkrc $?

        # Extract the "global" array from coreIoTJson
        coreIoTGlobalArray=$(jq -r '.global' <<< $coreIoTJson)
        checkrc $?
        # Extract the "global" array from customJson
        customGlobalArray=$(jq -r '.global' <<< $customJson)
        checkrc $?
        # Write the "global" array in the temporary file
        echo "$coreIoTGlobalArray" > $CORE_IOT_ARRAY_FILE
        echo "$customGlobalArray" > $CUSTOM_ARRAY_FILE
        # Merge both "global" arrays by reading them from the temporary files with "jq -s"
        mergedGlobalArray=$(jq -s '.=.|add' $CORE_IOT_ARRAY_FILE $CUSTOM_ARRAY_FILE)
        checkrc $?

        # Extract the "services" array from coreIoTJson
        coreIoTServicesArray=$(jq -r '.services' <<< $coreIoTJson)
        checkrc $?
        # Extract the "services" array from customJson
        customServicesArray=$(jq -r '.services' <<< $customJson)
        checkrc $?
        # Write the "services" array in the temporary file
        echo "$coreIoTServicesArray" > $CORE_IOT_ARRAY_FILE
        echo "$customServicesArray" > $CUSTOM_ARRAY_FILE
        # Merge both "services" arrays by reading them from the temporary files with "jq -s"
        mergedServicesArray=$(jq -s '.=.|add' $CORE_IOT_ARRAY_FILE $CUSTOM_ARRAY_FILE)
        checkrc $?
        outputJson=$(jq ".services = $mergedServicesArray " <<< $coreIoTJson)
        checkrc $?

        # Remove temporary files
        rm $CORE_IOT_ARRAY_FILE $CUSTOM_ARRAY_FILE

        outputJson=$(jq ".global = $mergedGlobalArray " <<< $outputJson)
        checkrc $?

        # Write all merged arrays (global, services) and write them back to hznEdgeCoreIoTInput.json
        echo "$outputJson" > $CORE_IOT_HZN_INPUT_FILE
    else
        fatal "File $CUSTOM_HZN_INPUT_FILE not found."
    fi
fi



# Register Edge node with horizon exchange server
log "Registering Edge node"
log "hzn register -n \"g@$WIOTP_INSTALL_DEVICE_TYPE@$WIOTP_INSTALL_DEVICE_ID:$WIOTP_INSTALL_DEVICE_TOKEN\" -f /etc/wiotp-edge/hznEdgeCoreIoTInput.json $WIOTP_INSTALL_ORGID $WIOTP_INSTALL_DEVICE_TYPE $VERBOSE"
hzn register -n "g@$WIOTP_INSTALL_DEVICE_TYPE@$WIOTP_INSTALL_DEVICE_ID:$WIOTP_INSTALL_DEVICE_TOKEN" -f /etc/wiotp-edge/hznEdgeCoreIoTInput.json $WIOTP_INSTALL_ORGID $WIOTP_INSTALL_DEVICE_TYPE $VERBOSE
checkrc $?

log "Agent registration complete."
