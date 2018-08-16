#!/usr/bin/perl
#
#############################################################################################
### Date : 29/03/2014
### Contact : divyashree.kumar@gmail.com
### Purpose : Utility for Polling OID infos from devices using SNMP, monitor the data
###           and send traps to Event  Adpater to generate events 
### Licensed under GNU GPL
#############################################################################################
use strict;
use warnings;
use Config::Simple;
use POSIX qw(strftime);
$|=1;
#use Number::Bytes::Human qw(format_bytes);
use POSIX;
#use Benchmark qw/cmpthese timethese/;

##
# Variables are collected from config.cfg file
##
my $cfg = new Config::Simple('main.cfg');

my $host = $cfg->param('Hostname');
my $port = $cfg->param('Port');
my $conf_files = $cfg->param('Config_Files');
my $confpath = $cfg->param('Config_Dir');
my $log_file =  $cfg->param('log_file');
my $logfilepath = $cfg->param('log_path');
my $logsize = $cfg->param('log_size');
my $log = "$logfilepath/$log_file";
my $snmptrap = $cfg->param('snmptrap');
my $snmpget = $cfg->param('snmpget');
my $snmptranslate = $cfg->param('snmptranslate');
my $mkdir = $cfg->param('mkdir');
my $touch = $cfg->param('touch');
my $nc = $cfg->param('nc');
my $logging = $cfg->param('log_enable');
my $community1 = $cfg->param('community_get');
my $community2 = $cfg->param('community_trap');
##
# Current time stamp is collected from local_time subroutine
##

my $currenttimestamp = local_time();

chomp($currenttimestamp);

##
# $conf_files is splitted to the files in it and saved in array @files
##

my @files = split(' ',$conf_files);


##
# Calling Conf_FIle_Process in whihc conf file existence are checked and other main subroutines are called
##
#timethese(-10, {
       	Conf_File_Process();
#});
##
# number_of_child detect limits the number of childs that will be created as per number of OID conf files mentioned in the main config file
# Here the number of childs are restricted to 11 now, 
# This subroutine returns true/false
# false - programme exit with error message and exit code 99 ( if number of files/childs in more than 50 )
# true - return 1 (if number of files/childs is less than 50) which is passed to other subroutines to process further
##

sub number_of_childs
  { 
    my $currenttimestamp = local_time();
    my $arrsize = scalar @files;
#    print $arrsize,"\n";
    unless ($arrsize <= 50)
     {
          print "$currenttimestamp : Can't create $arrsize Child Threads.\n";
          
          exit(99);          
     }
    else
     {
         return(0);
     }
}

##
# This is used to enable logging or disable logging
# If value retunred from number_of_child is true/1 then it will processed further by calling logrotate() and main()
# And it checks the logg_enable string in no/yes in main config file
# if log_enable is yes it will dump all STDOUT to the $log file
# if log_enable is no it will dump all STDOUT to /dev/null
##

sub logging
   {
     my $currenttimestamp = local_time();
     my $proceed = number_of_childs();
#     print $proceed,"\n";
     my @array = @_;
     if ($proceed == 0)
        {
           if ("$logging" eq "yes")
               {
                   logrotate();
                   open STDOUT, '>>', "$log" or die "Can't redirect STDOUT: $!";
                   open STDERR, ">&STDOUT"     or die "Can't add to  STDOUT: $!";
                   main(@array);
               }
           else
               {
                   logrotate();
                   open STDOUT, '>/dev/null' or warn "Can't open /dev/null: $!";
                   open STDERR, ">&STDOUT"     or die "Can't add to  STDOUT: $!";
                   main(@array);
               }
        }
   }



##
# This subroutine check the config file directory exist or not
# Then it cross checks the config files in the mentioned directory exist or not
# For the existed config files it create an array and pass the array to the logging() to process further
##

sub Conf_File_Process
   {
     my @conf_files = ();
     if (! -d $confpath)
       {
        print "$currenttimestamp : Configuration file directory : $confpath doesnot exist\n";
        exit (99);
       }
    else
      {
        foreach my $file (@files)
           {
               my $file = "$confpath/$file";
               if (-e $file)
                  {
                     push(@conf_files,$file);
                  }
               else
                  {
                    print "$currenttimestamp : Conf. file $file doesnot exist\n";
                  }
           } 
      }
# foreach (@conf_files) {print $_,"\n";}

 logging(@conf_files);
}


##
# here main() programme is called which creates the childs per file
# It chechs the number of existing files inherited from logging() and create one child process per file
# Each child calls doall() subroutine and processs each config file with it
# ALl the childs process the config files simultaneously
# Which makes the preocess faster
# It records the PID of each child corresponding to the config files mentioned
# After child finished the doall() processing it sends the exit signal to its parent and exit
# The doall(0 takes input as the config file, BEM aadapter and port to which the signals will be sent
##
#

sub main
{
  my @children;
  my @conf_files = @_;
  
  foreach my $file (@conf_files)
  {
#    print $_,"\n";
    my $pid = fork();
 
    if( $pid )
    {
      $currenttimestamp = local_time();
      chomp($currenttimestamp);
 #If $pid is non zero, then the parent is running
      print "$currenttimestamp : Child thread  with PID $pid forked for : ($file)\n";
      push(@children, $pid);
    }
    else
    {
      # Else we are a child process ($pid == 0)
      my $rc = doall($file,$host,$port);
      exit($rc);
    }
  }
 
  foreach my $n (@children)
  {
    my $pid = waitpid($n,0); # waitpid returns the pid that finished, see perldoc -f waitpid
    my $rc = $? >> 8; # remove signal / dump bits from rc
    $currenttimestamp = local_time();
    chomp($currenttimestamp);

    print "$currenttimestamp : PID $pid finished with rc $rc\n";
  }
}

##
#This logrotate() is responsible for rotating the log files
#It checks the size of logfile as mentioned in the main config file
#If log file reaches that size its renamed by appending the timestamp
#and new logfile is touched
##

sub logrotate
{
  if (!-d $logfilepath)
        {
 #           print "$currenttimestamp : LogFile Directory Doesnot exist, Creating $logfilepath..\n";
            system("$mkdir -p $logfilepath");
        }
  else
        {
           system("$touch $logfilepath");
        }
  
  my $log = "$logfilepath/$log_file";
  unless (-e $log)
      {
         system ("touch $log");
      } 
  my $log_size = -s "$log";
#  print "$currenttimestamp : File Size is : $log_size\n";
  if ($log_size  >= $logsize)
	{
       #   print "$currenttimestamp : Logfile size reached 100KB.\n";
       #	  print "$currenttimestamp : Rotating logfile size.\n";
	  my $append = `date +%G_%b_%d_%k_%M_%S`;
	  my $new_log_file = "$log.$append";
	  chomp($new_log_file); 
	  rename("$log", "$new_log_file") || die ( "$currenttimestamp : Error in renaming log file" );
	  system("$touch $log"); 
	}
#   return($log);
}

##
#This subroutine is responsible for passing the current time to wherever its called
##

sub local_time
 {

    #my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    #$year += 1900;
    #print "$sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst\n";
    my $now_time_string = localtime; 
    #print "$now_string\n";

    #my $now_time_string = strftime "%a %b %e %H:%M:%S %Y", localtime;
    #print "$now_time_string\n";
    return($now_time_string);

}

###
# This is the most important subroutine which is responsible for processing all the config\
# uration files by collecting all the fields mentioned in it
# It has 3 sub-subroutines
###

sub doall
{
  $currenttimestamp = local_time();
  chomp($currenttimestamp);

  printf STDERR "$currenttimestamp : child %s started file=%s\n", $$, $_[0];

  my ($nms, $port) = ("$_[1]", "$_[2]");
  open(IN, "$_[0]") or die "$currenttimestamp : Could not open conf file : $!";

  while (<IN>)
     {
	chomp($_);
        if ( $_ !~ /^#.*/ && $_ !~ /^$/)
            {  
	       $currenttimestamp = local_time();
               chomp($currenttimestamp);
               print "$currenttimestamp : Processing line from config file : $_\n";
               if (/(.*\d+):(\d+):(.*):(.*):(.*):(.*):(.*)/)
                   {
	              my ($Host, $SPort, $Regex, $OidStr, $Thresold, $Support1, $Support2) = ($1, $2, $3, $4, $5, $6, $7);
        	 
                      print "$currenttimestamp : Checking SNMP is running is Remote System : $Host on port $SPort..\n";
		      print "$currenttimestamp : ";
		      system("$nc -zu $Host $SPort");
		
		      unless ($? == 0)
			 {
			     print "$currenttimestamp : snmp service is not reachable on remotehost : $Host with $SPort\n";
		             next;
			 }
		      else
                         {   
			     print "$currenttimestamp : snmp service is reachable on remotehost : $Host with port $SPort\n";
			     if ($Regex ne "" && $Thresold ne "")
                               {
			           print "$currenttimestamp : Yes there is thresold defined for $OidStr So calling PollFromSender....\n";

                                   my ($SnmpMib, $Oid, $OidType, $OidVal) = PollFromSender($Host, $OidStr);	
				   print "$currenttimestamp : Collecting Support poll infromation from Support_Poll...\n";	
			           my ($O1, $V1, $T1, $O2, $v2, $T2) = Support_Poll($Host, $Support1, $Support2);
				   print "$currenttimestamp : Support Poll Details Collected, Now feeding thresold details in to CompThre_SendTrap...\n";
			           my $Result = CompThre_SendTrap($Regex, $Thresold, $Oid, $OidType, $OidVal, $Host, $O1, $V1, $T1, $O2, $v2, $T2, $OidStr, $nms, $port);
	                       }	
	                }
	          }	
            }   
     }

###
# This is responsible for polling the OID from the client process the output 
# and send it back where its called
## 

   sub PollFromSender
     {

       foreach my $arg (@_)
          {
             $currenttimestamp = local_time();
             chomp($currenttimestamp);
             my $pollcmd = "$snmpget -v2c -c $community1 $_[0] $_[1]";
             print "$currenttimestamp : Running : $pollcmd\n";
             open (PR, "$snmpget -v2c -c $community1 $_[0] $_[1] |") || die "Unable to Poll data : $!\n";
             while (<PR>)
                  {   

                      printf  "$currenttimestamp : Now Processing the polled data line  : $_";
       	              if (/(\w+-?\w+)-MIB::(\w+[.\d]*)\s=\s(\w+):\s(.*)/i)
	                  {
                               my ($SnmpMib, $OidStr, $OidType, $OidVal) = ($1, $2, $3, $4);
                               chomp($SnmpMib,$OidStr,$OidType,$OidVal);
       		               $OidStr = `$snmptranslate -On $SnmpMib-MIB::$OidStr`;
                               return ("$SnmpMib","$OidStr","$OidType","$OidVal")
	                 }
                 }     	
        }       
    } 

###
# This is responsible for comparing the thresold value mentioned in the config file
# and the exact value that is received from PollFromSender
# By caomparision if the exact value found is breaching the thresold value
# then it sends trap to the BEM adapter
# The exact value is extracted by using the RegEx mentioned in the config files
###

  sub CompThre_SendTrap
      {

          my ($Oid, $Type, $Value, $Thresold, $Regex, $Sender, $O1, $V1, $T1, $O2, $V2, $T2, $OidStr, $nms, $port);	
          foreach my $arg (@_)
               {
                  chomp ($arg);
                 ($Regex,$Thresold, $Oid,$Type,$Value,$Sender) = ($_[0],$_[1],$_[2], $_[3],$_[4],$_[5]);
                 ($O1,$V1, $T1, $O2, $V2, $T2,$OidStr, $nms, $port) = ($_[6],$_[7],$_[8],$_[9],$_[10],$_[11],$_[12],$_[13],$_[14]);
                 chomp($Oid);
	      }
	
#	print $Thresold,"\t",$Regex,"\t",$Oid,"\t",$Type,"\t",$Value,"\t",$O1,"\t", $V1,"\t", $T1, "\t",$O2,"\t", $V2,"\t", $T2,"\t";
	  if (/$Regex/)
               {
                  $currenttimestamp = local_time();
		  chomp($currenttimestamp);
#		  print "I am here\n";
	          my $Result = $2;
#			print $_;
#			print $Result,"\n";
	#		print $Thresold,"\n";
		  if ($Result >= $Thresold)
                        {
                            
		            my $Octet_Str = Octet_Str($Type);

			    print "$currenttimestamp : Now calling trap.. Thresold breached for $Sender for OID -> $OidStr .... Thresold: $Thresold.... Actual::$Result\n";
 
	   	            my $TrapCmd = "snmptrap -v 1 -c $community2 $nms:$port $Oid $Sender 6 123 '' $Oid $Octet_Str '$Result' $O1 $T1 '$V1' $O2 $T2 '$V2'";
			    print "$currenttimestamp : Running : $TrapCmd\n";
			    system("$TrapCmd");	
			}
                  else
                     {
		        print "$currenttimestamp : Thresold not breached for OID -> $OidStr .... Everything fine for $Sender....Thresold: $Thresold.... Actual:$Result\n";
		     }
		} 
		
	
    }

###
# This collects/polls supporting data which are required while sending traps to the BEM adapter
# The polled data is formatted and fed into the CompThre_SendTrap for sending trap
## 

  sub Support_Poll
      {

	my ($Host, $SupportOID1, $SupportOID2);
	foreach (@_)
            {
		$Host = $_[0]; $SupportOID1 = $_[1]; $SupportOID2=$_[2];
	    }
#	print $Host,"\t",$SupportOID1,"\t",$SupportOID2;

        my $SuppMib1 = `$snmptranslate -IR $SupportOID1`;#print $SuppMib1;
	my $SuppMib2 = `$snmptranslate -IR $SupportOID2`;#print $SuppMib2;
	
        my $SuppOid1 = `$snmptranslate -On $SuppMib1`; #print $SuppOid1;
	my $SuppOid2 = `$snmptranslate -On $SuppMib2`; #print $SuppOid2;
        my $SuppOid1Val = `$snmpget -v2c -c $community1 -Ov $Host  $SuppOid1`;#print $SuppOid1Val;
	my $type1 = Octet_Str($SuppOid1Val);# print $type1;
	my $SuppOid2Val = `$snmpget -v2c -c $community1 -Ov $Host  $SuppOid2`;#print $SuppOid2Valnmpget
	my $type2 = Octet_Str($SuppOid2Val); #print $type2;
        return ($SuppOid1, $SuppOid1Val, $type1, $SuppOid2, $SuppOid2Val, $type2);

     }


###
# This collects the octetstring of different data type values collected from the SNMP Oid values
# It changes in to its shorter from and sned it to where its being called
###

sub Octet_Str
    {
	my ($Str, $Oct_str);
	foreach (@_)
           {
		$Str = $_[0];
	   }

	if ($Str =~ /string/i)
           {
		$Oct_str = "s";
	   }
	elsif ($Str =~ /integer/i)
           {
		$Oct_str = "i";
	   }
        elsif ($Str =~ /Gauge/i)
          {
		$Oct_str = "u";
	  }
        elsif ($Str =~ /Counter/i)
          {
		$Oct_str = "c";
	  }
        elsif ($Str =~ /Hex-STRING/)
          {
		$Oct_str = "x";
	  }
#	print $Oct_str;
	return ($Oct_str);
  }

# sleep(2);

 $currenttimestamp = local_time();
 chomp($currenttimestamp);

 printf STDERR "$currenttimestamp : child %s exiting\n", $$;

}

__END__
