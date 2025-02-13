#!/usr/bin/env bash


export request="wget --progress=bar:force:noscroll -c --tries=2 "

function log() {
    echo "$0:${BASH_LINENO[*]}": $@
}

function validate_url(){
  EXTRA_PARAMS=''
  if [ -n "$2" ]; then
    EXTRA_PARAMS=$2
  fi
  if [[ `wget -S --spider $1  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
    ${request} $1 $2
  else
    echo -e "URL : \e[1;31m $1 does not exists"
    echo -e "\033[0m "
  fi
}


function generate_random_string() {
  STRING_LENGTH=$1
  random_pass_string=$(cat /dev/urandom | tr -dc '[:alnum:]' | head -c "${STRING_LENGTH}")
  if [[ ! -f ${EXTRA_CONFIG_DIR}/.pass_${STRING_LENGTH}.txt ]]; then
    echo "${random_pass_string}" > "${EXTRA_CONFIG_DIR}"/.pass_"${STRING_LENGTH}".txt
  fi
  export RAND=$(cat "${EXTRA_CONFIG_DIR}"/.pass_"${STRING_LENGTH}".txt)
}


function create_dir() {
  DATA_PATH=$1

  if [[ ! -d ${DATA_PATH} ]]; then
    echo "Creating" "${DATA_PATH}" "directory"
    mkdir -p "${DATA_PATH}"
  fi
}

function delete_file() {
    FILE_PATH=$1
    if [  -f "${FILE_PATH}" ]; then
        rm "${FILE_PATH}"
    fi

}

function delete_folder() {
    FOLDER_PATH=$1
    if [  -d "${FOLDER_PATH}" ]; then
        rm -r "${FOLDER_PATH}"
    fi

}


# Function to add custom crs in geoserver data directory
# https://docs.geoserver.org/latest/en/user/configuration/crshandling/customcrs.html
function setup_custom_crs() {
  if [[ ! -f ${GEOSERVER_DATA_DIR}/user_projections/epsg.properties ]]; then
    # If it doesn't exists, copy from ${EXTRA_CONFIG_DIR} directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/epsg.properties ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/epsg.properties "${GEOSERVER_DATA_DIR}"/user_projections/
    else
      # default values
      cp -r "${CATALINA_HOME}"/data/user_projections/epsg.properties "${GEOSERVER_DATA_DIR}"/user_projections/epsg.properties
    fi
  fi
}

# Function to enable cors support thought tomcat
# https://documentation.bonitasoft.com/bonita/2021.1/enable-cors-in-tomcat-bundle
function web_cors() {
  if [[ ! -f ${CATALINA_HOME}/conf/web.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/web.xml  ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/web.xml  "${CATALINA_HOME}"/conf/
    else
      # default values
      cp /build_data/web.xml "${CATALINA_HOME}"/conf/
    fi
  fi
}

# Function to add users when tomcat manager is configured
# https://tomcat.apache.org/tomcat-8.0-doc/manager-howto.html
function tomcat_user_config() {
  if [[ ! -f ${CATALINA_HOME}/conf/tomcat-users.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/tomcat-users.xml ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/tomcat-users.xml "${CATALINA_HOME}"/conf/tomcat-users.xml
    else
      # default value
      envsubst < /build_data/tomcat-users.xml > "${CATALINA_HOME}"/conf/tomcat-users.xml
    fi
  fi

}
# Helper function to download extensions
function download_extension() {
  URL=$1
  PLUGIN=$2
  OUTPUT_PATH=$3
  if curl --output /dev/null --silent --head --fail "${URL}"; then
    ${request} "${URL}" -O "${OUTPUT_PATH}"/"${PLUGIN}".zip
  else
    echo -e "Plugin URL does not exist:: \e[1;31m ${URL}"
    echo -e "\033[0m "
    exit 1
  fi

}

# A little logic that will fetch the geoserver war zip file if it is not available locally in the resources dir
function download_geoserver() {

if [[ ! -f /tmp/resources/geoserver-${GS_VERSION}.zip ]]; then
    if [[ "${WAR_URL}" == *\.zip ]]; then
      destination=/tmp/resources/geoserver-${GS_VERSION}.zip
      ${request} "${WAR_URL}" -O "${destination}"
      unzip /tmp/resources/geoserver-"${GS_VERSION}".zip -d /tmp/geoserver
    else
      destination=/tmp/geoserver/geoserver.war
      mkdir -p /tmp/geoserver/ &&
      ${request} "${WAR_URL}" -O ${destination}
    fi
else
  unzip /tmp/resources/geoserver-"${GS_VERSION}".zip -d /tmp/geoserver
fi

}

# Helper function to setup cluster config for the clustering plugin
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html
function cluster_config() {
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/cluster.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/cluster.properties ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/cluster.properties "${CLUSTER_CONFIG_DIR}"/cluster.properties
    else
      # default values
      envsubst < /build_data/cluster.properties > "${CLUSTER_CONFIG_DIR}"/cluster.properties
    fi
  fi
}

# Helper function to setup broker config. Used with clustering configs
# https://docs.geoserver.org/stable/en/user/community/jms-cluster/index.html

function broker_config() {
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/embedded-broker.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/embedded-broker.properties ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/embedded-broker.properties "${CLUSTER_CONFIG_DIR}"/embedded-broker.properties
    else
      # default values
      envsubst < /build_data/embedded-broker.properties > "${CLUSTER_CONFIG_DIR}"/embedded-broker.properties
    fi
  fi
}

function broker_xml_config() {
  if [[ ! -f ${CLUSTER_CONFIG_DIR}/broker.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/broker.xml ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/broker.xml "${CLUSTER_CONFIG_DIR}"/broker.xml
    else
      # default values
      if [[  ${DB_BACKEND} =~ [Pp][Oo][Ss][Tt][Gg][Rr][Ee][Ss] ]]; then
        envsubst < /build_data/broker.xml > "${CLUSTER_CONFIG_DIR}"/broker.xml
        sed -i -e '11,13d' "${CLUSTER_CONFIG_DIR}"/broker.xml
      else
        cp /build_data/broker.xml "${CLUSTER_CONFIG_DIR}"/broker.xml
        sed -i -e '15,26d' {CLUSTER_CONFIG_DIR}/broker.xml
      fi
    fi
  fi
}

# Helper function to configure s3 bucket
# https://docs.geoserver.org/latest/en/user/community/s3-geotiff/index.html
function s3_config() {
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/s3.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/s3.properties ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/s3.properties "${GEOSERVER_DATA_DIR}"/s3.properties
    else
      # default value
      envsubst < /build_data/s3.properties > "${GEOSERVER_DATA_DIR}"/s3.properties
    fi
  fi
}

# Helper function to install plugin in proper path

function install_plugin() {
  DATA_PATH=/community_plugins
  if [ -n "$1" ]; then
    DATA_PATH=$1
  fi
  EXT=$2

  unzip "${DATA_PATH}"/"${EXT}".zip -d /tmp/gs_plugin
  if [[ -f /geoserver/start.jar ]]; then
    cp -r -u -p /tmp/gs_plugin/*.jar /geoserver/webapps/geoserver/WEB-INF/lib/
  else
    cp -r -u -p /tmp/gs_plugin/*.jar "${CATALINA_HOME}"/webapps/geoserver/WEB-INF/lib/
  fi
  rm -rf /tmp/gs_plugin

}

# Helper function to setup disk quota configs and database configurations

function default_disk_quota_config() {
  if [[ ! -f ${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/geowebcache-diskquota.xml ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/geowebcache-diskquota.xml "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml
    else
      # default value
      envsubst < /build_data/geowebcache-diskquota.xml > "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota.xml
    fi
  fi
}

function jdbc_disk_quota_config() {

  if [[ ! -f ${GEOWEBCACHE_CACHE_DIR}/geowebcache-diskquota-jdbc.xml ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/geowebcache-diskquota-jdbc.xml ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/geowebcache-diskquota-jdbc.xml "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml
    else
      # default value
      envsubst < /build_data/geowebcache-diskquota-jdbc.xml > "${GEOWEBCACHE_CACHE_DIR}"/geowebcache-diskquota-jdbc.xml
    fi
  fi
}

# Function to setup control flow https://docs.geoserver.org/stable/en/user/extensions/controlflow/index.html
function setup_control_flow() {
  if [[ ! -f "${GEOSERVER_DATA_DIR}"/controlflow.properties ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/controlflow.properties ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/controlflow.properties "${GEOSERVER_DATA_DIR}"/controlflow.properties
    else
      # default value
      envsubst < /build_data/controlflow.properties > "${GEOSERVER_DATA_DIR}"/controlflow.properties
    fi
  fi

}

function setup_logging() {
  if [[ ! -f "${CATALINA_HOME}"/log4j.properties ]]; then
    # If it doesn't exists, copy from ${EXTRA_CONFIG_DIR} directory if exists
    if [[ -f ${EXTRA_CONFIG_DIR}/log4j.properties ]]; then
      cp -f "${EXTRA_CONFIG_DIR}"/log4j.properties "${CATALINA_HOME}"/log4j.properties
    else
      # default value
      envsubst < /build_data/log4j.properties > "${CATALINA_HOME}"/log4j.properties
    fi
  fi

}

function geoserver_logging() {
  echo "
<logging>
  <level>${GEOSERVER_LOG_LEVEL}.properties</level>
  <location>logs/geoserver.log</location>
  <stdOutLogging>true</stdOutLogging>
</logging>
" > /tmp/logging.xml
  if [[ ! -f ${GEOSERVER_DATA_DIR}/logging.xml ]];then
    envsubst < /tmp/logging.xml > "${GEOSERVER_DATA_DIR}"/logging.xml
  fi
  if [[ ! -f ${GEOSERVER_DATA_DIR}/logs/geoserver.log ]];then
    touch "${GEOSERVER_DATA_DIR}"/logs/geoserver.log
  fi
  rm /tmp/logging.xml
}

# Function to read env variables from secrets
function file_env {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

function set_vars() {
  MAXLEN=20
  generate_random_string ${MAXLEN} # Temporary not sure that that is need any more...

  if [ -z "${INSTANCE_STRING}" ];then
    if [ ! -z "${HOSTNAME}" ]; then
      hlength=${#HOSTNAME}
      if [ ${hlength} -gt ${MAXLEN} ]; then
        INSTANCE_STRING="${HOSTNAME: -${MAXLEN}}"
      else
        INSTANCE_STRING="${HOSTNAME}"
       fi
    else
      INSTANCE_STRING=${RAND}
    fi
  fi

  generate_random_string 14 # Temporary not sure that that is need any more...

  CLUSTER_CONFIG_DIR="${GEOSERVER_DATA_DIR}/cluster/instance_${INSTANCE_STRING: -14}"
  MONITOR_AUDIT_PATH="${GEOSERVER_DATA_DIR}/monitoring/monitor_${INSTANCE_STRING: -14}"
  CLUSTER_LOCKFILE="${CLUSTER_CONFIG_DIR}/.cluster.lock"
}



function postgres_ssl_setup() {
  if [[ ${SSL_MODE} == 'verify-ca' || ${SSL_MODE} == 'verify-full' ]]; then
        if [[ -z ${SSL_CERT_FILE} || -z ${SSL_KEY_FILE} || -z ${SSL_CA_FILE} ]]; then
                exit 0
        else
          export PARAMS="sslmode=${SSL_MODE}&sslcert=${SSL_CERT_FILE}&sslkey=${SSL_KEY_FILE}&sslrootcert=${SSL_CA_FILE}"
        fi
  elif [[ ${SSL_MODE} == 'disable' || ${SSL_MODE} == 'allow' || ${SSL_MODE} == 'prefer' || ${SSL_MODE} == 'require' ]]; then
       export PARAMS="sslmode=${SSL_MODE}"
  fi

}

function patch_gwc_s3_settings() {
	log Replacing S3 servers configuration from env/configmap/etc...
	if [ -z "${GEOSERVER_DATA_DIR}" -o -z "${s3_id}" -o -z "${s3_default}" -o -z "${s3_enabled}"   -o -z "${s3_bucket}"  -o -z "${s3_awsAccessKey}"  -o -z "${s3_awsSecretKey}"  -o -z "${s3_access}"  -o -z "${s3_maxConnections}"  -o -z "${s3_useHTTPS}"  -o -z "${s3_useGzip}"  -o -z "${s3_endpoint}"  ]; then
		log some vars are missing. Kept w/o changes
		log GEOSERVER_DATA_DIR: ${GEOSERVER_DATA_DIR}
		log s3_id: ${s3_id}
		log s3_default: ${s3_default}
		log s3_enabled: ${s3_enabled}
		log s3_bucket: ${s3_bucket}
		log s3_awsAccessKey: ${s3_awsAccessKey}
		log s3_awsSecretKey: ${s3_awsSecretKey}
		log s3_access: ${s3_access}
		log s3_maxConnections: ${s3_maxConnections}
		log s3_useHTTPS: ${s3_useHTTPS}
		log s3_useGzip: ${s3_useGzip}
		log s3_endpoint: ${s3_endpoint}
		log Do nothing...
	else
		GWC_PATH="${GEOWEBCACHE_CACHE_DIR}/geowebcache.xml" ;

		if [ -r "${GWC_PATH}" ]; then
			log "Patching....GWC_PATH: ${GWC_PATH}"
			cp "${GWC_PATH}" "${GWC_PATH}.orig"
			cat "${GWC_PATH}" | xmlstarlet ed -d "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores" -t elem -n S3BlobStore -v "" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t attr -n default -v ${s3_default} |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n id -v "${s3_id}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n enabled -v "${s3_enabled}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n bucket -v "${s3_bucket}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n awsAccessKey -v "${s3_awsAccessKey}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n awsSecretKey -v "${s3_awsSecretKey}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n access -v "${s3_access}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n maxConnections -v "${s3_maxConnections}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n useHTTPS -v "${s3_useHTTPS}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n useGzip -v "${s3_useGzip}" |
				xmlstarlet ed -s "/_:gwcConfiguration/_:blobStores/_:S3BlobStore" -t elem -n endpoint -v "${s3_endpoint}" > "${GWC_PATH}.new"
				#log Please fill the difference:
				#diff -ru "${GWC_PATH}.orig" "${GWC_PATH}.new"
				log mv "${GWC_PATH}.new" "${GWC_PATH}"
				mv "${GWC_PATH}.new" "${GWC_PATH}"
				log Replaced.
		else
			log "${GWC_PATH}" is absent
		fi
	fi
}

