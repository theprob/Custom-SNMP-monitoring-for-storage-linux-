#!/bin/bash
#	 _______________________________________________________________________________
#	/	Bash script to check LINUX based SAN/Storage systems' RAID and Disk health.	\
#	|	Should be used via SNMP.                                                    |
#	|																				|
#	|	Created by Béla Tóth			                                            |
#	|	Released:    2019.01.26.                                         			|
#	|	Last modify: 2019.02.07.                                   					|
#	\_______________________________________________________________________________/
#
# ez kell az snmpd.conf-ba: pass .1.3.6.1.4.1.8073.2.255   /bin/bash /opt/bin/StorageHealthStatus.sh
#	SNMP service start: /etc/rc.d/rc.snmpd start
#	SNMP service stop:  /etc/rc.d/rc.snmpd stop
#	SNMP status check:  ps | grep snmp or ps | grep snmpd
#	SNMPWALK:			snmpwalk -v2c -O n -c public localhost .1.3.6.1.4.1.8073.2.255
# Source global definitions

#	Default folder path
FPATH="/opt/StorageHealthMonitoring"

BASEOID=".1.3.6.1.4.1.8073.2.255"
COMMAND="$1" 		# ez lehet: -n (walknál next) -g (sima GET) -s (set)
RETURNOID="$2" 		# maga az OID
ISWALKING=false
IFS='.' read -r -a AROID <<< "$2" #	AROID = Array of Return OID
#	10th index is top level tree (e.g.: TREE_DRIVE)
#	11th index is the device itself (e.g.: /dev/sda...)
#	12th index is sub level tree (e.g.: TREE_DRIVE_ID)

TREE_DRIVE="1" 			# Top level tree for drives.
TREE_DRIVE_ID="1" 		# This is the subtree for device id check.
TREE_DRIVE_HEALTH="2" 	# This is the subtree for health check.
TREE_DRIVE_SN="3" 		# This is the subtree for serial number check.
TREE_DRIVE_TEMP="4" 	# This is the subtree for temperature check.
TREE_DRIVE_PN="5" 		# This is the subtree for product number check.

TREE_IOSTAT="2"			# Top level tree for system stats.
TREE_IOSTAT_ID="1"		# This is the subtree for device id.
TREE_IOSTAT_rrqm="2"	# This is the subtree for rrqm/s.
TREE_IOSTAT_wrqm="3"	# This is the subtree for wrqm/s.
TREE_IOSTAT_rps="4"		# This is the subtree for r/s.
TREE_IOSTAT_wps="5"		# This is the subtree for w/s.
TREE_IOSTAT_rMB="6"		# This is the subtree for rMB/s.
TREE_IOSTAT_wMB="7"		# This is the subtree for wMB/s.
TREE_IOSTAT_avgrq="8"	# This is the subtree for avgrq-sz.
TREE_IOSTAT_avgqu="9"	# This is the subtree for avgqu-sz.
TREE_IOSTAT_await="10"	# This is the subtree for await.
TREE_IOSTAT_rawait="11"	# This is the subtree for r_await.
TREE_IOSTAT_wawait="12"	# This is the subtree for w_await.
TREE_IOSTAT_svctm="13"	# This is the subtree for svctm.
TREE_IOSTAT_util="14"	# This is the subtree for %util.

TREE_RAID="3"			# Top level tree for RAID stats.
TREE_RAID_ID="1"		# This is the subtree for RAID id.
TREE_RAID_FAILED_DEVICES="2"	# This is the subtree for failed devices in the RAID.
TREE_RAID_ACTIVE_DEVICES="3"	# This is the subtree for active devices in the RAID.
TREE_RAID_WOKRING_DEVICES="4"	# This is the subtree for working devices in the RAID.
TREE_RAID_SPARE_DEVICES="5"	# This is the subtree for spare devices in the RAID.


#	Initial check. If the BASEOID is not within the RETURNOID, script running halts.
if [[ $RETURNOID != *"$BASEOID"* ]]; then
	exit
fi

#	If called only the BASEOID, initiate a full run from the top tree level.
if [ -z ${AROID[10]} ]; then
	AROID[10]="1"
	ISWALKING=true
fi

#	The is the Top level tree of drive statistics.
if [ ${AROID[10]} == $TREE_DRIVE ]; then
	#	If illegal oid given... exit.
	if [ ! -z ${AROID[13]} ]; then
		exit
	fi

	#   Checks if "hdscache" file's exists and create if not.
	if [ ! -f "$FPATH/hdscache" ]; then
		"$FPATH/HDSentinel" -solid | grep -v "?" > "$FPATH/hdscache";
	fi


	#	Checking "hdscache" files age. The value is represented in seconds.
	get_hdscache_age=($(($(date +%s) - $(date +%s -r "$FPATH/hdscache"))))

	#	Checking the "hdscache" file if it's older than 12hours. If so, renews it.
	#	43200 is 12hours in seconds.
	if [ $get_hdscache_age -gt 43200 ]; then
		#	cache HDSentinel's output.
		"$FPATH/HDSentinel" -solid | grep -v "?" > "$FPATH/hdscache";
	fi

	#	Loads the cached HDS stats from file into an array.
	readarray drive_health < "$FPATH/hdscache"

	# check if walk
	if [[ $COMMAND == "-n" ]]; then

		#	Checking if it's the 1st subtree.
		if [ -z ${AROID[11]} ]; then
			AROID[11]="1"
		fi

		#	Increments the OIDs AROID[11]
		#	${#drive_health[@]} = number of elements
		if [[ ${AROID[12]} -eq ${#drive_health[@]} ]]; then
			((AROID[11]++))
			AROID[12]="0"
		fi

		#	Initiate snmp walking and initialize the first element.
		if [ -z "${AROID[12]}" ]; then
			AROID[12]="0"
		fi

		#	Increments the OIDs (AROID[12])
		if [ ${AROID[12]} -lt ${#drive_health[@]} ]; then
			((AROID[12]++))
		fi
	fi

	case ${AROID[11]} in
		$TREE_DRIVE_ID )	# This is the subtree for device id.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $1}'
			exit
			;;
		$TREE_DRIVE_HEALTH )	# This is the subtree for health check.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "integer"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $3}'
			exit
			;;
		$TREE_DRIVE_SN )	# This is the subtree for serial number.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $6}'
			exit
			;;
		$TREE_DRIVE_TEMP )	# This is the subtree for temperature check.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "integer"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $2}'
			exit
			;;
		$TREE_DRIVE_PN )	# This is the subtree for model.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $5}'
			exit
			;;
	esac

	if [ "$ISWALKING"=true ]; then
		AROID[10]="2"
		AROID[13]=""
	fi
fi

#	The is the Top level tree of IOStat.
if [ ${AROID[10]} == $TREE_IOSTAT ]; then
	#	If illegal oid given... exit.
	if [ ! -z ${AROID[13]} ]; then
		exit
	fi

	#	Create/Update the iostat cache file.
	if [ ! -f "$FPATH/iostatcache" ]; then
		iostat -mxd | grep sd > "$FPATH/iostatcache";
	fi

	#	Checking "iostatcache" files age. The value is represented in seconds.
	get_iostatcache_age=($(($(date +%s) - $(date +%s -r "$FPATH/iostatcache"))))

	#	Checking the "iostatcache" file if it's older than 12hours. If so, renews it.
	#	1800 is 30mins in seconds.
	if [ $get_iostatcache_age -gt 1800 ]; then
		#	cache iostat's output.
		iostat -mxd | grep sd > "$FPATH/iostatcache";
	fi

	#	Loads the cached iostat from file into an array.
	readarray iostat < "$FPATH/iostatcache"

	# check if walk
	if [[ $COMMAND == "-n" ]]; then

		#	Checking if it's the 1st subtree.
		if [ -z ${AROID[11]} ]; then
			AROID[11]="1"
		fi

		#	Increments the OIDs AROID[11]
		#	${#iostat[@]} = number of elements
		if [[ ${AROID[12]} -eq ${#iostat[@]} ]]; then
			((AROID[11]++))
			AROID[12]="0"
		fi

		#	Initiate snmp walking and initialize the first element.
		if [ -z "${AROID[12]}" ]; then
			AROID[12]="0"
		fi

		#	Increments the OIDs (AROID[12])
		if [ ${AROID[12]} -lt ${#iostat[@]} ]; then
			((AROID[12]++))
		fi
	fi

	case ${AROID[11]} in
		$TREE_IOSTAT_ID )	# This is the subtree for device id.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo /dev/${iostat[((AROID[12]-1))]} | awk '{print $1}'
			exit
			;;
		$TREE_IOSTAT_rrqm )	# This is the subtree for rrqm/s.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $2}'
			exit
			;;
		$TREE_IOSTAT_wrqm )	# This is the subtree for wrqm/s.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $3}'
			exit
			;;
		$TREE_IOSTAT_rps )	# This is the subtree for r/s.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $4}'
			exit
			;;
		$TREE_IOSTAT_wps )	# This is the subtree for w/s.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $5}'
			exit
			;;
		$TREE_IOSTAT_rMB )	# This is the subtree for rMB/s.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $6}'
			exit
			;;
		$TREE_IOSTAT_wMB )	# This is the subtree for wMB/s.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $7}'
			exit
			;;
		$TREE_IOSTAT_avgrq ) # This is the subtree for avgrq-sz.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $8}'
			exit
			;;
		$TREE_IOSTAT_avgqu ) # This is the subtree for avgqu-sz.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $9}'
			exit
			;;
		$TREE_IOSTAT_await ) # This is the subtree for await.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $10}'
			exit
			;;
		$TREE_IOSTAT_rawait ) # This is the subtree for r_await.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $11}'
			exit
			;;
		$TREE_IOSTAT_wawait ) # This is the subtree for w_await.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $12}'
			exit
			;;
		$TREE_IOSTAT_svctm ) # This is the subtree for svctm.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $13}'
			exit
			;;
		$TREE_IOSTAT_util ) # This is the subtree for %util.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${iostat[((AROID[12]-1))]} | awk '{print $14}'
			exit
			;;
	esac

	if [ "$ISWALKING"=true ]; then
		AROID[10]="3"
	fi
fi

#	The is the Top level tree of RAID statistics.
if [ ${AROID[10]} == $TREE_RAID ]; then
	#	If illegal oid given... exit.
	if [ ! -z ${AROID[13]} ]; then
		exit
	fi

	#	Create/Update the mdadm cache file.
	if [ ! -f "$FPATH/mdadmcache" ]; then
		mdadm --detail /dev/md/* | egrep '(dev/md|Active|Working|Failed|Spare)' | \
			sed -e 's/Active Devices//;s/Working Devices//;s/Failed Devices//;s/Spare Devices//' | \
			tr -s ' '  '\n' | tr -s ':'  '\n' | awk '{printf "%s%s",$0,(NR%5?FS:RS)}'  > "$FPATH/mdadmcache";
	fi

	#	Checking "mdadmcache" files age. The value is represented in seconds.
	get_mdadmcache_age=($(($(date +%s) - $(date +%s -r "$FPATH/mdadmcache"))))

	#	Checking the "mdadmcache" file if it's older than 12hours. If so, renews it.
	#	1800 is 30mins in seconds.
	if [ $get_mdadmcache_age -gt 1800 ]; then
		#	cache mdadm's output.
		mdadm --detail /dev/md/* | egrep '(dev/md|Active|Working|Failed|Spare)' | \
			sed -e 's/Active Devices//;s/Working Devices//;s/Failed Devices//;s/Spare Devices//' | \
			tr -s ' '  '\n' | tr -s ':'  '\n' | awk '{printf "%s%s",$0,(NR%5?FS:RS)}'  > "$FPATH/mdadmcache";
	fi

	#	Loads the cached mdadm stats from file into an array.
	readarray mdadmcache < "$FPATH/mdadmcache"

	# check if walk
	if [[ $COMMAND == "-n" ]]; then

		#	Checking if it's the 1st subtree.
		if [ -z ${AROID[11]} ]; then
			AROID[11]="1"
		fi

		#	Increments the OIDs AROID[11]
		#	${#mdadmcache[@]} = number of elements
		if [[ ${AROID[12]} -eq ${#mdadmcache[@]} ]]; then
			((AROID[11]++))
			AROID[12]="0"
		fi

		#	Initiate snmp walking and initialize the first element.
		if [ -z "${AROID[12]}" ]; then
			AROID[12]="0"
		fi

		#	Increments the OIDs (AROID[12])
		if [ ${AROID[12]} -lt ${#mdadmcache[@]} ];then
			((AROID[12]++))
		fi
	fi

	case ${AROID[11]} in
		$TREE_RAID_ID )	# This is the subtree for RAID id.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${mdadmcache[((AROID[12]-1))]} | awk '{print $1}'
			exit
			;;
		$TREE_RAID_FAILED_DEVICES )	# This is the subtree for "Failed devices".
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "integer"
			echo ${mdadmcache[((AROID[12]-1))]} | awk '{print $4}'
			exit
			;;
		$TREE_RAID_ACTIVE_DEVICES )	# This is the subtree for "active devices".
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "integer"
			echo ${mdadmcache[((AROID[12]-1))]} | awk '{print $2}'
			exit
			;;
		$TREE_RAID_WOKRING_DEVICES )	# This is the subtree for "working devices".
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "integer"
			echo ${mdadmcache[((AROID[12]-1))]} | awk '{print $3}'
			exit
			;;
		$TREE_RAID_SPARE_DEVICES )	# This is the subtree for "spare devices".
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "integer"
			echo ${mdadmcache[((AROID[12]-1))]} | awk '{print $5}'
			exit
			;;
	esac
fi
