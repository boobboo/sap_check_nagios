#!/usr/bin/ksh
#
#
#  check_sap_javastack.sh
#  requires sapcontrol from SAP Installation
#
#  written by Silvan Hunkirchen for Computacenter 2009
#
#  v 0.1 initial Script
#  feature:
#       - check SAP Javastack via sapcontrol
#  v 1.0 debugging
#       - better checking of the status and better parsing of the output of sapcontrol
#       - possibility of excluding services
#  v 1.2 Users logged in
#       - show users currently logged in
#
#  v 1.3 Dispatcher working  / ICM attached to Java node

# supported functions :
#   J2EEGetProcessList
#   J2EEGetWebSessionList2
#
#
ret=0
# Values needed by script
FUNCTION=$1
SAPCONTROL=$2
USER=$3
PASS=$4
SN=$5
SID=$6
exclude=$7
host=`hostname`
sidadm=`echo $SID`adm

# setting inital variables
status=""

count_exclude=0

case $1 in
J2EEGetProcessList)
  # old - bug = awk will overwrite returncode of the application
  # result=`su  - $sidadm -c "$SAPCONTROL -user $USER $PASS -format script -host $host -nr $SN -function $FUNCTION | grep -e type -e statetext"| awk '{print $3 $4}'`
# get servernames that are configured
  result_server=`su  - $sidadm -c "$SAPCONTROL -user $USER $PASS -format script -host $host -nr $SN -function $FUNCTION | grep -e type"| awk '{print $3 $4}'`
# get status of each server -- could be easier but multidimentional arrays are not possible in ksh
  result_status=`su  - $sidadm -c "$SAPCONTROL -user $USER $PASS -format script -host $host -nr $SN -function $FUNCTION | grep -e statetext"| awk '{print $3 $4}'`
  check_result=`echo $?`
  if [ "$check_result" -eq "0" ];then
  {
# create all necessary arrays for exclude list, servernames and serverstatus
        set -A exclude_list `echo "$exclude"`
        count_exclude=${#exclude_list[@]}

        set -A server_name `echo "$result_server"|grep -v notset`
        count_servers_name=${#server_name[@]}

        set -A server_status `echo "$result_status"|grep -v notset`
        count_servers_status=${#server_status[@]}

        exclude_index=0
        if [ "$count_exclude" -gt "0" ];then
# loop through the exclude list and unset all servernames and status if the exclude matches
           while [[ "$exclude_index" -lt "$count_exclude" ]]
           do
                index=0
                while [[ "$index" -lt "$count_servers_name" ]]
                do
                  if [ "${server_name[$index]}" == "${exclude_list[$exclude_index]}" ];then
# actual unset the servers not wanted to be checked
                     unset server_name[$index]
                     unset server_status[$index]
                  fi
                let "index = index + 1"
                done
            let "exclude_index = exclude_index + 1"
          done
        fi

        index=0
# loop through the array again to check the serverstatus and create necessary exit codes
        while [[ "$index" -lt "$count_servers_name" ]]
        do
              if [ -n "${server_status[$index]}" ]; then
                if [ "${server_status[$index]}" != "Running" ];then
                  status=${status}" Server ${server_name[$index]} is ${server_status[$index]}<br>"
                  crit=1
                else
                  status=${status}" ${server_name[$index]} is running<br>"
                fi
              fi

          let "index = index + 1"
        done
  }
  else
  {
        echo "Javastack not reachable, probably login problems"
        exit 2
  }
  fi
  if [ "$crit" == "1" ];then
    echo $status
    exit 2
  else
    echo "All java servers are running<br>"$status
    exit 0
  fi
  ;;

J2EEGetWebSessionList2)
  user_count=`su  - $sidadm -c "$SAPCONTROL -user $USER $PASS -host $host -nr $SN -function $FUNCTION | grep -v Guest "|awk '{print $17}' | cut -d "," -f  1 |sort |uniq |wc -l | tr -d ' '`
  check_result=`echo $?`
  if [ "$check_result" -eq "0" ];then
  {
    echo "User count: $user_count|'Usercount'=$user_count;500;1000;0;2000"
    exit 0;
  }
  else
  {
    echo "User not reached - error"
    exit 2;
  }
  fi
  ;;

icmstatus)
  profile=`ps -ef |grep ig.sap | grep profile | awk '{print $11}'`
  alive=`su - $sidadm -c "wdispmon -ping $profile"`
  check_result=`echo $?`
  if [ "$check_result" -eq "0" ];then
  {
     echo "ICMON connected and alive"
     exit 0;
  }
  else
  {
     echo "ICMON most likely not connected, or dead"
     exit 2;
  }
  fi
  ;;

dispatcher)
  profile=`ps -ef | grep sapstartsrv | grep SCS | awk '{print $10}'`
  result=`su - $sidadm -c "dpmon -p $profile"`
  check_result=`echo $?`
  if [ "$check_result" -eq "0" ];then
  {
     echo "Dispatcher is alive"
     exit 0;
  }
  else
  {
     echo "Dispatcher most likely dead"
     exit 2;
  }
  fi
  ;;



*|--help)
  echo "check_sap_javastack.sh
  currently only supporting to check if SAP javastack processes are up and running
  called with
  ./check_sap_javastack.sh FUNCTION <Place of SAPCONTROL> USER PASS <SN of System> sid <exclude>
  ie. ./check_sap_javastack.sh J2EEGetProcessList /usr/sap/SID/JC00/exe/sapcontrol admin secret 00 bwd
  or
  ./check_sap_javastack.sh J2EEGetProcessList /usr/sap/SID/JC00/exe/sapcontrol admin secret 00 bwd "SERVERINSTANCE_1 SERVERINSTANCE_2"
       for excluding SERVERINSTANCE_1 and SERVERINSTANCE_2
  "
        exit 1
  ;;
esac
