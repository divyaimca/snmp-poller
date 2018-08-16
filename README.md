# snmp-poller
A poller tool developed by perl and snmp used to monitor any thing on network 

1.	This is an open source tool used to query managed devices using provisioning policy to an interface.
2.	To poll snmp interface we have to set up a policy for the provisioning group of nodes to be 'snmp' polled.
3.	All the interfaces that match the policy will be snmp polled by the snmp poller.
4.	By default the snmp poller will poll every 5 minutes every interface that is marked POLL.
5.	SNMP managed hosts and SNMP poller host configured to belong to same community.
6.	Community string is provided to SNMP poller to use during authentication.
7.  SNMP poller should be provided with the list of OIDs to query .
8.	SNMP poller executes at given point of time interval an SNMP GET request for administrational and operational status information.
9.  Once SNMP poller receives messages, it forwards those messages to any event collector like BMC Event adapter or any as SNMP traps.



#	Environment 

Considering that there are devices on network with SNMP enabled and some OID values of its need to be monitored by a utility using SNMP Polling. The SNMP_Poller utility will poll monitoring data and parse it to get the exact value which it compares with the threshold value defined in the device config file. If the utility finds breach in the threshold value during the comparison, it will send TRAPS to the installed Event adapter cell. While sending the TRAP, the SNMP_Poller utility also sends 2 additional support OID values which helps to identify more about the device.
#	Requirements

1.	The following UNIX utilities should be installed in the SNMP_Poller Server.
          Net-SNMP
          Perl
          Netcat
          
2.	Fully functional Event adapter installed in SNMP_Poller linux server & root user privilege on the same server.

3.	Install the following perl modules on the same Event adapter server

Config::Simple
Net::SNMP
#	 “snmp_poller” Utility Configuration

1.	Download the files (Snmp_Poller.pl, main.cfg, device1.cfg ) from this git repo.

2.	Login to the Event adapter installed server and create a directory for placing the configuration file 

mkdir –p /etc/Snmp_Poller
mkdir –p /etc/Snmp_Poller/Device_Conf

3.	Copy the Snmp_Poller.pl and main.cfg file in that location (/etc/Snmp_Poller) by using WinSCP or any other software.

4.	Copy the device file into /etc/Snmp_Poller/Device_Conf directory.

5.	Give executable permission to the Snmp_Poller.pl utility.  

chmod 755 /etc/Snmp_Poller/ Snmp_Poller.pl


          * Updating main Configuration file

Update the below parameters with correct values in main.cfg file:

Hostname=  <IP Address of the Eventadapter Server>
Port=  <Port of BEIM Server to receive trap>
Config_Dir= <Path of the device config files> 
Config_Files= <Name of the device config files separated with a space>
log_path= <Path where log file will be generated>
log_file= <Name of the log file>
log_size= <Size of the log file in byte after reaching which log rotation will happen on next execution>
log_enable= <yes – To enable logging, no – To disable logging>
community_get= < Community string configured in devices, Default: public>
community_trap= <Community string configured in BEIM Adapter, Default: public>
snmptrap= <Path of the snmptrap command>
snmpget= <Path of the snmpget command>
snmptranslate= <Path of the snmptranslate command>
mkdir= <Path of mkdir>
touch= <Path of touch>
nc= <Path of netcat command>

          * Updating device configuration files

The device configuration files should contain the below format with 7 fields separated with a colon (:) 


129.221.5.33:161:(\w+.*)(.*\d+)(.*):hrDeviceStatus.1:3:sysName.0:sysDescr.0




The fields should be:

1. IP Address of the device that needs to be monitored
2. Port of the device in which snmp service is running
3. Regular Expression which will extract the monitoring value from the polled data:

Example 1. . The polled data received from the device is : 

HOST-RESOURCES-MIB::hrDeviceStatus.1 = INTEGER: running(2)

So the regex: (\w+.*)(.*\d+)(.*)  is grouped into 3 values and the second group is the numeric value which we want to extract and compare it to threshold.

In the above snmp polled data, the second group in the regex will extract the value 2.

Example 2.  The polled data received from device is :

UCD-SNMP-MIB::memAvailReal.0 = INTEGER: 1011592 kB

Here the regex will be: (\w+.*\s)(\d+)(.*) is grouped in 3 values and the 2nd group here extracts the required value 1011592 to compare with threshold.

4. The SNMP OID which will be polled from the device. e.g. memAvailReal.0

5. The threshold value which will be compared to the extracted value using RegEx used in field 3.

6. Additional Support OID the value of which will be collected from the device and sent in TRAP.

7. Another additional Support OID the value of which will be collected from the device and sent in TRAP.

#	Validation
	Polling monitored OID

This will check whether the actual OID which needs to be monitored is polled by this utility.

1.	Start the service running & check the status by using the following command

./Snmp_Poller.pl &
[1] 11477

2.	Check the log file content in real time

tail -f /var/log/SnmpPoller/snmppoller_log

And the monitored OID will be found in the log with below line:

Mon Mar 31 14:26:27 2014 : Running : /usr/bin/snmpget -v2c -c public 129.221.8.98 hrDeviceStatus.768

Where hrDeviceStatus.768 is the OID that is monitored on host 129.221.8.98 using snmpget.

          *	Existence of device config file
This feature will check the existence of all the device config files specified in the main.cfg file.
Update the main.cfg file with below two parameters:

Config_Dir= "/root/snmpscripts/Conf_Dir"
Config_Files=  device.cfg abcd.cfg

Where device.cfg file exist and abcd.cfg doesn’t exist.
So Execute the utility now which will check the existence of the config files:

[root@centos6snmp snmp_poller]# ./Snmp_Poller.pl
Mon Mar 31 14:31:09 2014 : Conf. file /root/snmpscripts/Conf_Dir/abcd.cfg doesnot exist

Here it checks for the file existence before processing further.

          *Log file Generation

This feature is used to generate the logs from utility which records all step wise activity, errors, etc. 

Update main.cfg file with below parameters:

log_path= "/var/log/SnmpPoller"
log_file= "snmp_poller.log"

Execute the utility:


./Snmp_Poller.pl & [1] 11477

And check the logs are generated in real time with below command:

tail -f /var/log/SnmpPoller/snmppoller_log


          *Log Rotation
This check will ensure new logfiles are generated in each execution of utility if defined logsize is reached.
Update main.cfg file with below parameter with bytes:
log_size= "102400"

Execute the utility again and again.

Go insde the log path and check different log files are generated with timestamp appended when the defined size reached.
ls -l /var/log/SnmpPoller/
-rw-r--r--. 1 root root  3164 Mar 31 15:27 snmppoller.log
-rw-r--r--. 1 root root  3164 Mar 31 15:26 snmppoller.log.2014_Mar_31_15_26_17
-rw-r--r--. 1 root root  3164 Mar 31 15:26 snmppoller.log.2014_Mar_31_15_26_25
-rw-r--r--. 1 root root  3164 Mar 31 15:26 snmppoller.log.2014_Mar_31_15_26_32
-rw-r--r--. 1 root root  3164 Mar 31 15:26 snmppoller.log.2014_Mar_31_15_26_51
-rw-r--r--. 1 root root  3164 Mar 31 15:26 snmppoller.log.2014_Mar_31_15_27_03
          * Logging Enable/Disable

Update the main.cfg with: TO enable log change “no” to “yes”

log_enable= "no"

Now go to log file path and check for real time log:
tail -f /var/log/SnmpPoller/snmppoller_log
There will be no update found in the log file.
          * Threshold value comparison

Update the device config file with threshold file mentioned:
129.221.8.98:161:(\w+.*\s)(\d+)(.*):memAvailReal.0:1200:sysName.0:sysDescr.0

Where 1200 is the threshold.
Now check the log with real time to find the below entries if actual value breached threshold value: 
If threshold value breached:
Mon Mar 31 14:30:53 2014 : Now calling trap.. Thresold breached for 129.221.8.98 for OID -> memAvailReal.0 .... Thresold: 1200.... Actual::988212

And if threshold value is not breached for below device config entry: 
129.221.8.98:161:(\w+.*\s)(\d+)(.*):memAvailReal.0:12000000:sysName.0:sysDescr.0

Mon Mar 31 15:25:16 2014 : Thresold not breached for OID -> memAvailReal.0.... Everything fine for 129.221.8.98....Thresold: 12000000.... Actual:988212

          * Processing Supported OIDs 
This feature will check in case of breaching threshold value , the generated trap from the utility will have 2 additional support OID information as defined in the device.cfg file.

Entry in device.cfg:

129.221.8.98:161:(\w+.*\s)(\d+)(.*):memAvailReal.0:1200:sysName.0:sysDescr.0

So if this threshold value is breached the utility will generate a trap with below command which can be seen in the realtime log file:
tail -f /var/log/SnmpPoller/snmppoller_log

And this lines will be found where the highlighted ones are the additional supported OIDs.
Mon Mar 31 14:26:30 2014 : Now calling trap.. Thresold breached for 129.221.8.98 for OID -> memAvailReal.0 .... Thresold: 1200.... Actual::988336

Mon Mar 31 14:26:30 2014 : Running : snmptrap -v 1 -c public 129.221.8.105:163 .1.3.6.1.4.1.2021.4.6.0 129.221.8.98 6 123 '' .1.3.6.1.4.1.2021.4.6.0 i '988336' .1.3.6.1.2.1.1.5.0 s 'STRING: centos6snmp' .1.3.6.1.2.1.1.1.0 s 'STRING: Linux centos6snmp 2.6.32-431.el6.x86_64 #1 SMP Fri Nov 22 03:15:09 UTC 2013 x86_64'

          *Remote port reachability
Mention the port of the device in the config file:

129.221.8.98:164:(\w+.*\s)(\d+)(.*):memAvailReal.0:1200:sysName.0:sysDescr.0

Here 164 is the port and if it’s not reachable then it will throw error and go to next line which is dumped in the log file 

Mon Mar 31 15:25:32 2014 : Mon Mar 31 15:25:32 2014 : snmp service is not reachable on remotehost : 129.221.8.98 with 164

And if it’s reachable then it will give the message in log file:

Mon Mar 31 15:25:26 2014 : snmp service is reachable on remotehost : 129.221.8.98 with port 164

          * Child threads creation per device config file:

Update the main config file with multiple device config files:
Config_Files=  device.cfg test1.cfg test2.cfg test3.cfg

Execute the utility:
[root@centos6snmp snmp_poller]# ./Snmp_Poller.pl &
[1] 12628





Run the ps command in terminal and it will display all the forked child threads:
[root@centos6snmp snmp_poller]# ps
  PID TTY          TIME CMD
10843 pts/0    00:00:00 bash
12628 pts/0    00:00:00 Snmp_Poller.pl
12632 pts/0    00:00:00 Snmp_Poller.pl
12633 pts/0    00:00:00 Snmp_Poller.pl
12634 pts/0    00:00:00 Snmp_Poller.pl
12635 pts/0    00:00:00 Snmp_Poller.pl

OR else in the real time log file the following entries can be found:
Mon Mar 31 16:18:44 2014 : Child thread  with PID 12632 forked for : (/root/snmpscripts/Conf_Dir/device.cfg)
Mon Mar 31 16:18:44 2014 : Child thread  with PID 12633 forked for : (/root/snmpscripts/Conf_Dir/test1.cfg)
Mon Mar 31 16:18:44 2014 : Child thread  with PID 12634 forked for : (/root/snmpscripts/Conf_Dir/test2.cfg)
Mon Mar 31 16:18:44 2014 : Child thread  with PID 12635 forked for : (/root/snmpscripts/Conf_Dir/test3.cfg)

          *Limitation of max 50 Child threads for utility

Update the main.cfg file with 50+ device config files:

Config_Files=  test1.cfg test1.cfg test1.cfg test1.cfg test2.cfg test3.cfg test4.cfg test5.cfg test6.cfg test7.cfg test8.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg test1.cfg





Then execute the utility and it will throw error and exit :

[root@centos6snmp snmp_poller]# ./Snmp_Poller.pl
Mon Mar 31 16:23:24 2014 : Can't create 52 Child Threads.

          *Parallel execution of child threads:

This feature will tell that all the threads are processed at same parallel i.e. the time taken to process 1 device config file or multiple config files are same.

NOTE: THE PARALLEL CHILD THREAD EXECUTION DEPEND IMMENSLY ON PROCESSOR CAPACITY. THIS FEATURE REQUIRES OPTIMIZED PROCESSOR.

Update the main.cfg file with 1 device config file and record the time of execution of utility:

Config_Files=  test1.cfg

[root@centos6snmp snmp_poller]# time ./Snmp_Poller.pl &
[1] 12990

This execution took 3.19 second in real to process 1 device config file:
real    0m3.191s
user    0m0.152s
sys     0m0.010s

Now update the main.cfg with multiple device config files:

Config_Files=  test1.cfg test1.cfg test1.cfg test1.cfg


Now execute the utility:

[root@centos6snmp snmp_poller]# time ./Snmp_Poller.pl &
[1] 13013
real    0m3.662s
user    0m0.546s
sys     0m0.031s

This took same 3seconds to process 5 device config files.

NOTE: To test on more and more device config files, use multicore high end processor.
