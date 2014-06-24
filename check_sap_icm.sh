#!/bin/ksh
#
#
#  check_sap_icm.sh
#
#  written by Silvan Hunkirchen for Computacenter 
#
#  v 0.1 initial Script

user=$1
profile=$2

if [ $# -ne 2 ]; then
   echo "Illegal arguments."
   echo ""
   echo "Usage: check_sap_icm.sh {sapsid} {profile-location}"
   exit 2;
fi

if [ "$user" = "DEHQ0HP1" ];then
        user="hp1adm";
else
        user=`echo $user"adm"| /usr/bin/tr 'A-Z' 'a-z'`
fi

icm=`su - $user -c "icmon -ping pf=$profile" | grep status | cut -d ":" -f2 | sed 's/ //g'`
if [ $? -eq "0" ];then
        if [ "$icm" == "ICM_STATUS_RUN" ];then
                echo "ICM status: $icm"
                exit 0;
        elif [ "$icm" == "ICM_STATUS_INIT" ];then
                echo "ICM status: $icm";
                exit 1;
        else
                echo "ICM status: $icm";
                exit 2;
        fi
elif [ $? -eq "1" ]; then
        echo "ICM not reachable";
        exit 2;
else
        echo "ICM check failed - something wrong";
        exit 3;
fi
