# Custom-SNMP-monitoring-for-storage-linux-

## Getting started

With this script you are able to monitor any HDD or SSD in you linux based servers via SNMP.
The script itself is a simple bash code, using HDSentinels free linux edition.

```
HDS ref.: http://www.hdsentinel.hu/hard_disk_sentinel_linux.php
```

I uploaded both files, but you can download the latest HDS version any time from the HDS official site.
Just be sure to rename it to "HDSentinel".

### I have test it on the following distros so far:

    CentOS 7
    ESOS

##  Installation and config guide:

The below commands using yum, if you have othe package manager, please search for the proper commands to obtain the same settings!

1.	Create a folder under /opt/ and name it "StorageHealthMonitoring".
	(so you should get the following path: /opt/StorageHealthMonitoring)

2.	Copy the "StorageHealthStatus_snmp.sh" and "HDSentinel" files into previously created folder.
	(under /opt/StorageHealthMonitoring/)
	Make both files executable:
```    
chmod +x StorageHealthStatus_snmp.sh
chmod +x HDSentinel
``` 

3.Install the SNMP packages:

```
CentOS: yum -y install net-snmp net-snmp-utils
```

4.Modify the snmp.conf file as follows (/etc/snmp/snmpd.conf):

```
view    systemview    included   .1.3.6.1.4.1.8073.2.255
rocommunity public <10.0.0.0/8> (Modify the subnet, from where you will query the server. You can add multiple subnets with new lines.)
pass .1.3.6.1.4.1.8073.2.255   /bin/bash /opt/StorageHealthMonitoring/StorageHealthStatus_snmp.sh
```
In you are using ESOS, you should take following steps in addition:
```
comment:	agentAddress  udp:127.0.0.1:161
add:		agentAddress udp:161
uncomment:	rocommunity public  localhost
comment:	rocommunity public  default    -V systemonly
```

5.Restart the SNMP service.
On CentOS:
```
service snmpd restart
```
On ESOS:
```
SNMP service stop:  	/etc/rc.d/rc.snmpd stop
SNMP service start:	/etc/rc.d/rc.snmpd start			
SNMP status check:  	ps | grep snmp
			ps | grep snmpd
```
    
6.Check SeLinux status (you can skip this step, if using ESOS):
```
getenforce
```
If the result is "Enforcing", issue commands mentioned on 6.a otherwise continue with step 7.
    
6.a.a	Install "semanage" packages:
```
yum install policycoreutils-python
```
6.a.b	Set "snmpd_t" to permissive:
```
semanage permissive -a snmpd_t
```
		
7.Configure firewall (you can skip this step, if using ESOS).

Create config file for snmp service:
```
(https://unix.stackexchange.com/questions/214388/how-to-let-the-firewall-of-rhel7-the-snmp-connection-passing)
```
Issue the following commands:
```
firewall-cmd --zone=public --add-service snmp --permanent
firewall-cmd --reload
```
    
## Running tests

snmpwalk the OID listed below. You should walk it twice, because the 1st run creates a cache file with the outputs.
```
snmpwalk -v2c -O n -c public localhost .1.3.6.1.4.1.8073.2.255
```	
