#!/bin/bash

function gp_init_standalone() {
  sudo chmod -R ug+rw ${GPDATA}

  local GP_CONFIG_FILE_INIT="/opt/gpdb/conf/gpinitsystem.conf"

  export DATA_DIRECTORY="${GPDATA}/primary1" &&
    mkdir -pv "${COORDINATOR_DIRECTORY}" "${DATA_DIRECTORY}" &&
    echo "Begin to init Greenplum using config file: ${GP_CONFIG_FILE_INIT}" &&
    gpinitsystem -a -c ${GP_CONFIG_FILE_INIT} &&
    echo "GreenplumDB has been successfully init and now started!" &&
    echo 'host  all  all  0.0.0.0/0  password' >>"${COORDINATOR_DATA_DIRECTORY}/pg_hba.conf" &&
    gpconfig -c log_statement -v none &&
    gpconfig -c gp_enable_global_deadlock_detector -v on
}

function gp_init_cluster() {
  echo "Init GPDB" && gp_init_standalone &&
    echo "Update GPDB config" && gpstop -u
}

sudo service ssh start && sleep 3s

if [ "$(ls -A ${GPDATA})" = "" ]; then
  echo "No data files found in ${GPDATA}, please init GPDB first!"
else
  echo "Starting existing GPDB" && gpstart -a
fi
# tail -f gpAdminLogs/*.log
bash
