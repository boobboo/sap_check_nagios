#!/bin/ksh
#
# written by Silvan Hunkirchen
# checks the state of a 3494 tape library with mtlib
# Cases:
# 1.
# 2.
#
# Will enable Nagios to check the state of X-Library
#
#

# Global variables

se=adsm_prod
pw=
user=


# Setting session variables
case=$1
drive=$2
libname=$3
source=$4
ret=0
dsmadm=/usr/bin/dsmadmc
mtlib=/usr/bin/mtlib

case $1 in
drive)
        status=`$dsmadm -se=$se -id=$user -password=$pw "select online from drives where library_name='$libname' and drive_name='$drive'"`
        error=`echo $?"`
        if [ "$error" -eq "0" ];then
                status_drive=`$dsmadm -se=$se -id=$user -password=$pw "select online from drives where library_name='$libname' and drive_name='$drive'"| tail -4 | head -1`
                result=`echo $status_drive|grep "NO"`
                if [ "$result" == "NO" ];then
                        echo "Drive $drive is offline"
                        ret=2
                else
                        echo "Drive $drive is online"
                fi
        else
        echo "Error in SQL Syntax. Prolly invalid Drive or Library selected"
        ret=1
        fi
        ;;
path)
        status=`$dsmadm -se=$se -id=$user -password=$pw "select online from paths where destination_name='$drive' and LIBRARY_NAME='$libname' and source_name='$source'"`
        error=`echo $?`
        if [ "$error" -eq "0" ];then
                status_path=`$dsmadm -se=$se -id=$user -password=$pw "select online from paths where destination_name='$drive' and LIBRARY_NAME='$libname' and source_name='$source'"| tail -4 | head -1`
                result=`echo $status_path|grep "NO"`
                if [ "$result" == "NO" ];then
                        echo "PATH $drive is offline"
                        ret=2
                else
                        echo "PATH $drive is online"
                fi
        else
        echo "Error in SQL Syntax. Prolly invalid Path or Library selected"
        ret=1
        fi
        ;;
session)
        status=`$dsmadm -se=$se -id=$user -password=$pw -displaymode=list "select count(State) as MEDIAW from SESSIONS where state='MediaW'"|grep MEDIAW:| cut -d ":" -f2 `
        error=`echo $?`
         if [ "$error" -eq "0" ];then
                if [ "$status" -gt "30" ];then
                        echo "$status MediaW on TSM Server. Please check sessions"
                        ret=2
                else
                        echo "$status MediaW on TSM Server. All seems to be ok"
                fi
        else
        echo "Unkonwn error occured"
        ret=1
        fi
        ;;

freescratch_prod)
        status=`$dsmadm -se=$se -id=$user -password=$pw -displaymode=list -commadelimited -dataonly=yes run scratch| head -1`
        error=`echo $?`
         if [ "$error" -eq "0" ];then
                if [ "$status" -le "10" ];then
                        echo "$status Tapes defined as Scratch. Be aware! |'Scratch'=$status;10;5;0;100"
                        ret=1
                elif [ "$status" -le "5" ];then
                        echo "$status Tapes defined as Scratch. Hurry to fill up with some new ones!|'Scratch'=$status;10;5;0;100"
                        ret=2
                else
                        echo "$status Tapes defined as Scratch. All Ok!|'Scratch'=$status;10;5;0;100"
                fi
        else
        echo "Unkonwn error occured"
        ret=1
        fi
        ;;

freescratch_test)
        status=`$dsmadm -se=$se -id=$user -password=$pw -displaymode=list "run copyscratch"|grep COPYSCRATCH:|cut -d ":" -f2|awk '{print $1}'`
        error=`echo $?`
         if [ "$error" -eq "0" ];then
                if [ "$status" -le "10" ];then
                        echo "$status Tapes defined as Scratch. Be aware!|'Scratch'=$status;10;5;0;100"
                        ret=1
                elif [ "$status" -le "5" ];then
                        echo "$status Tapes defined as Scratch. Hurry to fill up with some new ones!|'Scratch'=$status;10;5;0;100"
                        ret=2
                else
                        echo "$status Tapes defined as Scratch. All Ok!|'Scratch'=$status;10;5;0;100"
                fi
        else
        echo "Unkonwn error occured"
        ret=1
        fi
        ;;

db_usage)
        status=`$dsmadm -se=$se -id=$user -password=$pw -displaymode=list -commadelimited -dataonly=yes "select FREE_SPACE_MB from DB"`
        error=`echo $?`
         if [ "$error" -eq "0" ];then
                if [ "$status" -le "100" ];then
                        echo "$status MB on DB are free. Please expand the database |'DB Space used'=$status;98;99;0;100"
                        ret=2
                else
                        echo "$status MB on Database are free |'DB Space used'=$status;98;99;0;100"
                fi
        else
          echo "Unkonwn error occured"
        ret=1
        fi
        ;;
stgpool)
        status=`$dsmadm -se=$se -id=$user -password=$pw -displaymode=list "select count(*) as stgpoolcount from volumes where stgpool_name like '%$drive%' and devclass_name like 'FC%'"| grep STGPOOLCOUNT | awk '{print $2}'`
        stgpoolmax=`$dsmadm -se=$se -id=$user -password=$pw -displaymode=list  "select maxscratch from stgpools where stgpool_name like '%$drive%'"| grep MAXSCRATCH:|awk '{print $2}'`
        stgpoolmax=`echo $stgpoolmax| sed 's/ /+/g'| bc`
        stgpoolwarn=`echo $stgpoolmax - 5 | bc`
        error=`echo $?`
         if [ "$error" -eq "0" ];then
          echo "Used tapes for $drive: $status |'Used Tapes $drive'=$status;$stgpoolwarn;$stgpoolmax;0;$stgpoolmax"
          #echo "Used tapes for $drive: $status |'Used Tapes $drive'=$status;$stgpoolwarn;$stgpoolmax;;"
          #echo "Used tapes for $drive: $status |'Used Tapes $drive'=$status;;;;"
        else
          echo "Unkonwn error occured"
        ret=1
        fi
        ;;
readonly)
        status=`$dsmadm -se=$se -id=$user -password=$pw -displaymode=list  "select volume_name from volumes where access not like 'READWRITE' and access not like 'OFFSITE' and location = '' and devclass_name not like 'DISK'" | grep VOLUME_NAME| awk '{print $2}'`
        if [ "$status" == "" ];then
            echo "No tapes are readonly"
        else
            echo "Following tapes are readonly: $status"
            ret=2
        fi
        ;;
cleaning)

        status=`$mtlib -l /dev/$drive -qL|grep "avail 3592 cleaner cycles.."| cut -d . -f3`
        if [ "$status" -le "50" ];then
                echo "Less than 50 cycles left, checkin new cleaning tapes|'Cycles'=$status;50;10;;"
                ret=2
        else
                echo "$status cycles left, all ok|'Cycles'=$status;;;;"
        fi
        ;;
*)
        echo "no option set."
        ret=1
        ;;
esac
exit $ret
