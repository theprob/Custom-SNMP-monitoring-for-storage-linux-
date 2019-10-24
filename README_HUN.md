1.	Felmásolni az /opt/ folderbe a "StorageHealthMonitoring" mappát. (Ez tartalmazza a szükséges fájlokat.)

2.	Futtathatóvá tenni a "StorageHealthStatus_snmp.sh" és a "HDSentinel" fájlokat. (chmod +x StorageHealthStatus_snmp.sh & chmod +x HDSentinel)

3.	Telepíteni az snmp csomagokat:				yum -y install net-snmp net-snmp-utils

4.	Kiegészíteni az snmp.conf fájlt az alábbiakkal (/etc/snmp/snmpd.conf):
		view    systemview    included   .1.3.6.1.4.1.8073.2.255
		rocommunity public <10.0.11.0/24> (módosítandó arra az IP-re és subnet-re, ahonnan monitorozunk)
		pass .1.3.6.1.4.1.8073.2.255   /bin/bash /opt/StorageHealthMonitoring/StorageHealthStatus_snmp.sh

		ESOS esetén:
			comment:	agentAddress  udp:127.0.0.1:161
			add:		agentAddress udp:161
			uncomment:	rocommunity public  localhost
			comment:	rocommunity public  default    -V systemonly


5.	Selinux állapotának elleőrzése: 			getenforce
	6.a	Ha be van kapcsolva ("Enforcing")
		6.a.a	semanage package telepítése:	yum -y install policycoreutils-python
		6.a.b	snmpd_t engedélyezése:			semanage permissive -a snmpd_t

6.	Tűzfal beállítása:
		Config fájl létrehozása snmp-hez. (/etc/firewalld/services/snmp.xml) (https://unix.stackexchange.com/questions/214388/how-to-let-the-firewall-of-rhel7-the-snmp-connection-passing)
												firewall-cmd --zone=public --add-service snmp --permanent
												firewall-cmd --reload

7.	SNMP szolgáltatás újraindítása.
		CentOS-nél:
			service snmpd restart

		ESOS:
			SNMP service stop:  				/etc/rc.d/rc.snmpd stop
			SNMP service start: 				/etc/rc.d/rc.snmpd start			
			SNMP status check:  				ps | grep snmp
												ps | grep snmpd

8.	Tesztelés:
		2x (első meghívás után hozza létre a hdcache fájlt)
												snmpwalk -v2c -O n -c public localhost .1.3.6.1.4.1.8073.2.255





Selinux extention-re alternatíva (nem működött):		
	sudo grep snmp /var/log/audit/audit.log | grep denied | audit2allow -M StorageHealthMonitoring
	cat StorageHealthMonitoring.te ; cat StorageHealthMonitoring.te | wc -l
	sudo semodule -i StorageHealthMonitoring.pp			
