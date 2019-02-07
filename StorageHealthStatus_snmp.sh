#!/bin/bash
#	 _______________________________________________________________________________________ 
#	/	Bash script to check LINUX based SAN/Storage systems' RAID and Disk health.	\
#	|	Should be used via SNMP.                                                    	|
#	|											|									|
#	|	Created by Béla Tóth			                                        |
#	|	Released:    2018.07.06.                                         		|
#	|	Last modify: -                                           			|
#	\_______________________________________________________________________________________/
#
# ez kell az snmpd.conf-ba: pass .1.3.6.1.4.1.8073.2.255   /bin/bash /opt/bin/StorageHealthStatus.sh
#	SNMP service start: /etc/rc.d/rc.snmpd start
#	SNMP service stop:  /etc/rc.d/rc.snmpd stop
#	SNMP status check:  ps | grep snmp or ps | grep snmpd
#	SNMPWALK:			snmpwalk -v2c -O n -c public localhost .1.3.6.1.4.1.8073.2.255
# Source global definitions

BASEOID=".1.3.6.1.4.1.8073.2.255"
COMMAND="$1" 		# ez lehet: -n (walknál next) -g (sima GET) -s (set)
RETURNOID="$2" 		# maga az OID
IFS='.' read -r -a AROID <<< "$2" #	AROID = Array of Return OID
#	10th index is top level tree (e.g.: TREE_DRIVE)
#	11th index is the device itself (e.g.: /dev/sda...)
#	12th index is sub level tree (e.g.: TREE_DRIVE_ID)

TREE_DRIVE="1" 			# Top level tree for drives.
TREE_DRIVE_ID="1" 		# This is the subtree for device id check.
TREE_DRIVE_HEALTH="2" 	# This is the subtree for health check.
TREE_DRIVE_SN="3" 		# This is the subtree for serial number check.
TREE_DRIVE_TEMP="4" 	# This is the subtree for temperature check.
TREE_DRIVE_TBW="5" 		# This is the subtree for temperature check.

TREE_SYSTEM="2"			# Top level tree for system stats.

#	Initial check. If the BASEOID is not within the RETURNOID, script running halts.
if [[ $RETURNOID != *"$BASEOID"* ]]; then
	echo "first exit"
	exit
fi

#	If called only the BASEOID, initiate a full run from the top tree level.
if [ -z ${AROID[10]} ]; then
	AROID[10]="1"
fi

#	The is the Top level tree of drive statistics.
if [ ${AROID[10]} == "1" ]; then	
	#	If illegal oid given... exit.
	if [ ! -z ${AROID[13]} ]; then
		exit
	fi
	
	#   Check if no hdscache file exist and create
	#   FIXME!
	
	    
	#	Checking "hdscache" files age. The value is represented in seconds.
	get_hdscache_age=($(($(date +%s) - $(date +%s -r "/opt/StorageHealthStatus/hdscache"))))

	#	Checking the "hdscache" file if it's older than 12hours. If so, renews it.
	#	43200 is 12hours in seconds.
	if [ $get_hdscache_age -gt 43200 ]; then
		#	cache HDSentinel's output.
		/opt/sbin/HDSentinel -solid | grep -v "?" > "/opt/StorageHealthStatus/hdscache";
	fi

	#	Loads the cached HDS stats from file into an array.
	readarray drive_health < /opt/StorageHealthStatus/hdscache
	
	# check if walk
	if [[ $COMMAND == "-n" ]]; then
		
		#	Checking if it's the 1st subtree.
		if [ -z ${AROID[11]} ]; then
			AROID[11]="1"
		fi
		
		# echo '${AROID[12]}:' ${AROID[12]}
		# echo '${#drive_health[@]}:' ${#drive_health[@]}
		# echo '${AROID[11]}:' ${AROID[11]}
		
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
		if [ ${AROID[12]} -lt ${#drive_health[@]} ];then
			((AROID[12]++))
		fi
		
		# check if its last oid
		if [[ ${AROID[12]} -eq ${#drive_health[@]} ]] && [[ ${AROID[11]} -eq 5 ]]; then
			AROID[10]="2"
			AROID[11]=""
			AROID[12]=""
		fi		
	fi
	
	case ${AROID[11]} in
		"1")	# This is the subtree for device id check.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $1}'	
			exit
			;;
		"2")	# This is the subtree for health check.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "integer"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $3}'
			exit
			;;
		"3")	# This is the subtree for serial number check.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "string"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $6}'
			exit
			;;
		"4")	# This is the subtree for temperature check.
			echo "$BASEOID.${AROID[10]}.${AROID[11]}.${AROID[12]}"
			echo "integer"
			echo ${drive_health[((AROID[12]-1))]} | awk '{print $2}'
			exit
			;;
	esac		
fi	

#	The is the Top level tree of drive statistics.
if [ ${AROID[10]} == "2" ]; then	
	exit
fi
