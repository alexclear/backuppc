#!/bin/perl

#my %lang;

#use strict;

# --------------------------------

$Lang{Start_Full_Backup} = "Start Full Backup";
$Lang{Start_Incr_Backup} = "Start Incr Backup";
$Lang{Stop_Dequeue_Backup} = "Stop/Dequeue Backup";
$Lang{Restore} = "Restore";

# -----

$Lang{H_BackupPC_Server_Status} = "BackupPC Server Status";

$Lang{BackupPC_Server_Status}= <<EOF;
\${h1(qq{$Lang{H_BackupPC_Server_Status}})}

<p>
\${h2(\"General Server Information\")}

<ul>
<li> The servers PID is \$Info{pid},  on host \$Conf{ServerHost},
     version \$Info{Version}, started at \$serverStartTime.
<li> This status was generated at \$now.
<li> PCs will be next queued at \$nextWakeupTime.
<li> Other info:
    <ul>
        <li>\$numBgQueue pending backup requests from last scheduled wakeup,
        <li>\$numUserQueue pending user backup requests,
        <li>\$numCmdQueue pending command requests,
        \$poolInfo
        <li>Pool file system was recently at \$Info{DUlastValue}%
            (\$DUlastTime), today\'s max is \$Info{DUDailyMax}% (\$DUmaxTime)
            and yesterday\'s max was \$Info{DUDailyMaxPrev}%.
    </ul>
</ul>

\${h2("Currently Running Jobs")}
<p>
<table border>
<tr><td> Host </td>
    <td> Type </td>
    <td> User </td>
    <td> Start Time </td>
    <td> Command </td>
    <td align="center"> PID </td>
    <td align="center"> Xfer PID </td>
    </tr>
\$jobStr
</table>
<p>

\${h2("Failures that need attention")}
<p>
<table border>
<tr><td align="center"> Host </td>
    <td align="center"> Type </td>
    <td align="center"> User </td>
    <td align="center"> Last Try </td>
    <td align="center"> Details </td>
    <td align="center"> Error Time </td>
    <td> Last error (other than no ping) </td></tr>
\$statusStr
</table>
EOF

# --------------------------------
$Lang{BackupPC__Server_Summary} = "BackupPC: Server Summary";
$Lang{BackupPC_Summary}=<<EOF;

\${h1(qq{$Lang{BackupPC__Server_Summary}})}
<p>
This status was generated at \$now.
<p>

\${h2("Hosts with good Backups")}
<p>
There are \$hostCntGood hosts that have been backed up, for a total of:
<ul>
<li> \$fullTot full backups of total size \${fullSizeTot}GB
     (prior to pooling and compression),
<li> \$incrTot incr backups of total size \${incrSizeTot}GB
     (prior to pooling and compression).
</ul>
<table border>
<tr><td> Host </td>
    <td align="center"> User </td>
    <td align="center"> #Full </td>
    <td align="center"> Full Age/days </td>
    <td align="center"> Full Size/GB </td>
    <td align="center"> Speed MB/sec </td>
    <td align="center"> #Incr </td>
    <td align="center"> Incr Age/days </td>
    <td align="center"> State </td>
    <td align="center"> Last attempt </td></tr>
\$strGood
</table>
<p>

\${h2("Hosts with no Backups")}
<p>
There are \$hostCntNone hosts with no backups.
<p>
<table border>
<tr><td> Host </td>
    <td align="center"> User </td>
    <td align="center"> #Full </td>
    <td align="center"> Full Age/days </td>
    <td align="center"> Full Size/GB </td>
    <td align="center"> Speed MB/sec </td>
    <td align="center"> #Incr </td>
    <td align="center"> Incr Age/days </td>
    <td align="center"> Current State </td>
    <td align="center"> Last backup attempt </td></tr>
\$strNone
</table>
EOF

# -----------------------------------
$Lang{Pool_Stat} = <<EOF;
        <li>Pool is \${poolSize}GB comprising \$info->{"\${name}FileCnt"} files
            and \$info->{"\${name}DirCnt"} directories (as of \$poolTime),
        <li>Pool hashing gives \$info->{"\${name}FileCntRep"} repeated
            files with longest chain \$info->{"\${name}FileRepMax"},
        <li>Nightly cleanup removed \$info->{"\${name}FileCntRm"} files of
            size \${poolRmSize}GB (around \$poolTime),
EOF

# --------------------------------
$Lang{BackupPC__Backup_Requested_on__host} = "BackupPC: Backup Requested on \$host";
# --------------------------------
$Lang{REPLY_FROM_SERVER} = <<EOF;
\${h1(\$str)}
<p>
Reply from server was: \$reply
<p>
Go back to <a href="\$MyURL?host=\$host">\$host home page</a>.
EOF
# --------------------------------
$Lang{BackupPC__Start_Backup_Confirm_on__host} = "BackupPC: Start Backup Confirm on \$host";
# --------------------------------
$Lang{Are_you_sure_start} = <<EOF;
\${h1("Are you sure?")}
<p>
You are about to start a \$type backup on \$host.

<form action="\$MyURL" method="get">
<input type="hidden" name="host" value="\$host">
<input type="hidden" name="hostIP" value="\$ipAddr">
<input type="hidden" name="doit" value="1">
Do you really want to do this?
<input type="submit" value="\$In{action}" name="action">
<input type="submit" value="No" name="">
</form>
EOF
# --------------------------------
$Lang{BackupPC__Stop_Backup_Confirm_on__host} = "BackupPC: Stop Backup Confirm on \$host";
# --------------------------------
$Lang{Are_you_sure_stop} = <<EOF;

\${h1("Are you sure?")}

<p>
You are about to stop/dequeue backups on \$host;

<form action="\$MyURL" method="get">
<input type="hidden" name="host" value="\$host">
<input type="hidden" name="doit" value="1">
Also, please don\'t start another backup for
<input type="text" name="backoff" size="10" value="\$backoff"> hours.
<p>
Do you really want to do this?
<input type="submit" value="\$In{action}" name="action">
<input type="submit" value="No" name="">
</form>

EOF
# --------------------------------
$Lang{Only_privileged_users_can_view_queues_} = "Only privileged users can view queues.";
# --------------------------------
$Lang{BackupPC__Queue_Summary} = "BackupPC: Queue Summary";
# --------------------------------
$Lang{Backup_Queue_Summary} = <<EOF;
\${h1("Backup Queue Summary")}
<p>
\${h2("User Queue Summary")}
<p>
The following user requests are currently queued:
<table border>
<tr><td> Host </td>
    <td> Req Time </td>
    <td> User </td></tr>
\$strUser
</table>
<p>

\${h2("Background Queue Summary")}
<p>
The following background requests are currently queued:
<table border>
<tr><td> Host </td>
    <td> Req Time </td>
    <td> User </td></tr>
\$strBg
</table>
<p>

\${h2("Command Queue Summary")}
<p>
The following command requests are currently queued:
<table border>
<tr><td> Host </td>
    <td> Req Time </td>
    <td> User </td>
    <td> Command </td></tr>
\$strCmd
</table>
EOF

# --------------------------------
$Lang{Backup_PC__Log_File__file} = "BackupPC: Log File \$file";
$Lang{Log_File__file__comment} = <<EOF;
\${h1("Log File \$file \$comment")}
<p>
EOF
# --------------------------------
$Lang{Contents_of_log_file} = <<EOF;
Contents of log file <tt>\$file</tt>, modified \$mtimeStr \$comment
EOF

# --------------------------------
$Lang{skipped__skipped_lines} = "[ skipped \$skipped lines ]\n";
# --------------------------------
$Lang{_pre___Can_t_open_log_file__file} = "<pre>\nCan\'t open log file \$file\n";

# --------------------------------
$Lang{BackupPC__Log_File_History} = "BackupPC: Log File History";
$Lang{Log_File_History__hdr} = <<EOF;
\${h1("Log File History \$hdr")}
<p>
<table border>
<tr><td align="center"> File </td>
    <td align="center"> Size </td>
    <td align="center"> Modification time </td></tr>
\$str
</table>
EOF

# -------------------------------
$Lang{Recent_Email_Summary} = <<EOF;
\${h1("Recent Email Summary (Reverse time order)")}
<p>
<table border>
<tr><td align="center"> Recipient </td>
    <td align="center"> Host </td>
    <td align="center"> Time </td>
    <td align="center"> Subject </td></tr>
\$str
</table>
EOF
 

# ------------------------------
$Lang{Browse_backup__num_for__host} = "BackupPC: Browse backup \$num for \$host";

# ------------------------------
$Lang{Restore_Options_for__host} = "BackupPC: Restore Options for \$host";
$Lang{Restore_Options_for__host2} = <<EOF;
<p>
You have selected the following files/directories from
share \$share, backup number #\$num:
<ul>
\$fileListStr
</ul>
<p>
You have three choices for restoring these files/directories.
Please select one of the following options.
<p>
\${h2("Option 1: Direct Restore")}
<p>
You can start a restore that will restore these files directly onto
\$host.
<p>
<b>Warning:</b> any existing files that match the ones you have
selected will be overwritten!

<form action="\$MyURL" method="post">
<input type="hidden" name="host" value="\${EscHTML(\$host)}">
<input type="hidden" name="num" value="\$num">
<input type="hidden" name="type" value="3">
\$hiddenStr
<input type="hidden" value="\$In{action}" name="action">
<table border="0">
<tr>
    <td>Restore the files to host</td>
    <td><input type="text" size="40" value="\${EscHTML(\$host)}"
	 name="hostDest"></td>
</tr><tr>
    <td>Restore the files to share</td>
    <td><input type="text" size="40" value="\${EscHTML(\$share)}"
	 name="shareDest"></td>
</tr><tr>
    <td>Restore the files below dir<br>(relative to share)</td>
    <td valign="top"><input type="text" size="40" maxlength="256"
	value="\${EscHTML(\$pathHdr)}" name="pathHdr"></td>
</tr><tr>
    <td><input type="submit" value="Start Restore" name=""></td>
</table>
</form>
EOF

# ------------------------------
$Lang{Option_2__Download_Zip_archive} = <<EOF;

\${h2("Option 2: Download Zip archive")}
<p>
You can download a Zip archive containing all the files/directories you have
selected.  You can then use a local application, such as WinZip,
to view or extract any of the files.
<p>
<b>Warning:</b> depending upon which files/directories you have selected,
this archive might be very very large.  It might take many minutes to
create and transfer the archive, and you will need enough local disk
space to store it.
<p>
<form action="\$MyURL" method="post">
<input type="hidden" name="host" value="\${EscHTML(\$host)}">
<input type="hidden" name="num" value="\$num">
<input type="hidden" name="type" value="2">
\$hiddenStr
<input type="hidden" value="\$In{action}" name="action">
<input type="checkbox" value="1" name="relative" checked> Make archive relative
to \${EscHTML(\$pathHdr eq "" ? "/" : \$pathHdr)}
(otherwise archive will contain full paths).
<br>
Compression (0=off, 1=fast,...,9=best)
<input type="text" size="6" value="5" name="compressLevel">
<br>
<input type="submit" value="Download Zip File" name="">
</form>
EOF

# ------------------------------

$Lang{Option_2__Download_Zip_archive2} = <<EOF;
\${h2("Option 2: Download Zip archive")}
<p>
Archive::Zip is not installed so you will not be able to download a
zip archive.
Please ask your system adminstrator to install Archive::Zip from
<a href="http://www.cpan.org">www.cpan.org</a>.
<p>
EOF


# ------------------------------
$Lang{Option_3__Download_Zip_archive} = <<EOF;
\${h2("Option 3: Download Tar archive")}
<p>
You can download a Tar archive containing all the files/directories you
have selected.  You can then use a local application, such as tar or
WinZip to view or extract any of the files.
<p>
<b>Warning:</b> depending upon which files/directories you have selected,
this archive might be very very large.  It might take many minutes to
create and transfer the archive, and you will need enough local disk
space to store it.
<p>
<form action="\$MyURL" method="post">
<input type="hidden" name="host" value="\${EscHTML(\$host)}">
<input type="hidden" name="num" value="\$num">
<input type="hidden" name="type" value="1">
\$hiddenStr
<input type="hidden" value="\$In{action}" name="action">
<input type="checkbox" value="1" name="relative" checked> Make archive relative
to \${EscHTML(\$pathHdr eq "" ? "/" : \$pathHdr)}
(otherwise archive will contain full paths).
<br>
<input type="submit" value="Download Tar File" name="">
</form>
EOF


# ------------------------------
$Lang{Restore_Confirm_on__host} = "BackupPC: Restore Confirm on \$host";

$Lang{Are_you_sure} = <<EOF;
\${h1("Are you sure?")}
<p>
You are about to start a restore directly to the machine \$In{hostDest}.
The following files will be restored to share \$In{shareDest}, from
backup number \$num:
<p>
<table border>
<tr><td>Original file/dir</td><td>Will be restored to</td></tr>
\$fileListStr
</table>

<form action="\$MyURL" method="post">
<input type="hidden" name="host" value="\${EscHTML(\$host)}">
<input type="hidden" name="hostDest" value="\${EscHTML(\$In{hostDest})}">
<input type="hidden" name="shareDest" value="\${EscHTML(\$In{shareDest})}">
<input type="hidden" name="pathHdr" value="\${EscHTML(\$In{pathHdr})}">
<input type="hidden" name="num" value="\$num">
<input type="hidden" name="type" value="4">
\$hiddenStr
Do you really want to do this?
<input type="submit" value="\$In{action}" name="action">
<input type="submit" value="No" name="">
</form>
EOF


# --------------------------
$Lang{Restore_Requested_on__hostDest} = "BackupPC: Restore Requested on \$hostDest";
$Lang{Reply_from_server_was___reply} = <<EOF;
\${h1(\$str)}
<p>
Reply from server was: \$reply
<p>
Go back to <a href="\$MyURL?host=\$hostDest">\$hostDest home page</a>.
EOF

# -------------------------
$Lang{Host__host_Backup_Summary} = "BackupPC: Host \$host Backup Summary";

$Lang{Host__host_Backup_Summary2} = <<EOF;
\${h1("Host \$host Backup Summary")}
<p>
\$warnStr
<ul>
\$statusStr
</ul>

\${h2("User Actions")}
<p>
<form action="\$MyURL" method="get">
<input type="hidden" name="host" value="\$host">
\$startIncrStr
<input type="submit" value="$Lang{Start_Full_Backup}" name="action">
<input type="submit" value="$Lang{Stop_Dequeue_Backup}" name="action">
</form>

\${h2("Backup Summary")}
<p>
Click on the backup number to browse and restore backup files.
<table border>
<tr><td align="center"> Backup# </td>
    <td align="center"> Type </td>
    <td align="center"> Filled </td>
    <td align="center"> Start Date </td>
    <td align="center"> Duration/mins </td>
    <td align="center"> Age/days </td>
    <td align="center"> Server Backup Path </td>
</tr>
\$str
</table>
<p>

\$restoreStr

\${h2("Xfer Error Summary")}
<p>
<table border>
<tr><td align="center"> Backup# </td>
    <td align="center"> Type </td>
    <td align="center"> View </td>
    <td align="center"> #Xfer errs </td>
    <td align="center"> #bad files </td>
    <td align="center"> #bad share </td>
    <td align="center"> #tar errs </td>
</tr>
\$errStr
</table>
<p>

\${h2("File Size/Count Reuse Summary")}
<p>
Existing files are those already in the pool; new files are those added
to the pool.
Empty files and SMB errors aren\'t counted in the reuse and new counts.
<table border>
<tr><td colspan="2"></td>
    <td align="center" colspan="3"> Totals </td>
    <td align="center" colspan="2"> Existing Files </td>
    <td align="center" colspan="2"> New Files </td>
</tr>
<tr>
    <td align="center"> Backup# </td>
    <td align="center"> Type </td>
    <td align="center"> #Files </td>
    <td align="center"> Size/MB </td>
    <td align="center"> MB/sec </td>
    <td align="center"> #Files </td>
    <td align="center"> Size/MB </td>
    <td align="center"> #Files </td>
    <td align="center"> Size/MB </td>
</tr>
\$sizeStr
</table>
<p>

\${h2("Compression Summary")}
<p>
Compression performance for files already in the pool and newly
compressed files.
<table border>
<tr><td colspan="3"></td>
    <td align="center" colspan="3"> Existing Files </td>
    <td align="center" colspan="3"> New Files </td>
</tr>
<tr><td align="center"> Backup# </td>
    <td align="center"> Type </td>
    <td align="center"> Comp Level </td>
    <td align="center"> Size/MB </td>
    <td align="center"> Comp/MB </td>
    <td align="center"> Comp </td>
    <td align="center"> Size/MB </td>
    <td align="center"> Comp/MB </td>
    <td align="center"> Comp </td>
</tr>
\$compStr
</table>
<p>
EOF

# -------------------------
$Lang{Error} = "BackupPC: Error";
$Lang{Error____head} = <<EOF;
\${h1("Error: \$head")}
<p>\$mesg</p>
EOF

# -------------------------
$Lang{NavSectionTitle_} = "Server";

# -------------------------
$Lang{Backup_browse_for__host} = <<EOF;
\${h1("Backup browse for \$host")}

<script language="javascript" type="text/javascript">
<!--

    function checkAll(location)
    {
      for (var i=0;i<document.form1.elements.length;i++)
      {
        var e = document.form1.elements[i];
        if ((e.checked || !e.checked) && e.name != \'all\') {
            if (eval("document.form1."+location+".checked")) {
            	e.checked = true;
            } else {
            	e.checked = false;
            }
        }
      }
    }
    
    function toggleThis(checkbox)
    {
       var cb = eval("document.form1."+checkbox);
       cb.checked = !cb.checked;	
    }

//-->
</script>

<ul>
<li> You are browsing backup #\$num, which started around \$backupTime
        (\$backupAge days ago),
\$filledBackup
<li> Click on a directory below to navigate into that directory,
<li> Click on a file below to restore that file.
</ul>

\${h2("Contents of \${EscHTML(\$dirDisplay)}")}
<form name="form1" method="post" action="\$MyURL">
<input type="hidden" name="num" value="\$num">
<input type="hidden" name="host" value="\$host">
<input type="hidden" name="share" value="\${EscHTML(\$share)}">
<input type="hidden" name="fcbMax" value="\$checkBoxCnt">
<input type="hidden" name="action" value="$Lang{Restore}">
<br>
<table>
<tr><td valign="top">
    <!--Navigate here:-->
    <br><table align="center" border="0" cellpadding="0" cellspacing="0" bgcolor="#ffffff">
    \$dirStr
    </table>
</td><td width="3%">
</td><td valign="top">
    <!--Restore files here:-->
    <br>
    <table cellpadding="0" cellspacing="0" bgcolor="#333333"><tr><td>
        <table border="0" width="100%" align="left" cellpadding="2" cellspacing="1">
        \$fileHeader
        \$topCheckAll
        \$fileStr
        \$checkAll
        </table>
    </td></tr></table>
<br>
<!--
This is now in the checkAll row
<input type="submit" name="Submit" value="Restore selected files">
-->
</td></tr></table>
</form>
EOF

# ------------------------------
$Lang{Restore___num_details_for__host} = "BackupPC: Restore #\$num details for \$host";

$Lang{Restore___num_details_for__host2 } = <<EOF;
\${h1("Restore #\$num Details for \$host")}
<p>
<table border>
<tr><td> Number </td><td> \$Restores[\$i]{num} </td></tr>
<tr><td> Requested by </td><td> \$RestoreReq{user} </td></tr>
<tr><td> Request time </td><td> \$reqTime </td></tr>
<tr><td> Result </td><td> \$Restores[\$i]{result} </td></tr>
<tr><td> Error Message </td><td> \$Restores[\$i]{errorMsg} </td></tr>
<tr><td> Source host </td><td> \$RestoreReq{hostSrc} </td></tr>
<tr><td> Source backup num </td><td> \$RestoreReq{num} </td></tr>
<tr><td> Source share </td><td> \$RestoreReq{shareSrc} </td></tr>
<tr><td> Destination host </td><td> \$RestoreReq{hostDest} </td></tr>
<tr><td> Destination share </td><td> \$RestoreReq{shareDest} </td></tr>
<tr><td> Start time </td><td> \$startTime </td></tr>
<tr><td> Duration </td><td> \$duration min </td></tr>
<tr><td> Number of files </td><td> \$Restores[\$i]{nFiles} </td></tr>
<tr><td> Total size </td><td> \${MB} MB </td></tr>
<tr><td> Transfer rate </td><td> \$MBperSec MB/sec </td></tr>
<tr><td> TarCreate errors </td><td> \$Restores[\$i]{tarCreateErrs} </td></tr>
<tr><td> Xfer errors </td><td> \$Restores[\$i]{xferErrs} </td></tr>
<tr><td> Xfer log file </td><td>
<a href="\$MyURL?action=view&type=RestoreLOG&num=\$Restores[\$i]{num}&host=\$host">View</a>,
<a href="\$MyURL?action=view&type=RestoreErr&num=\$Restores[\$i]{num}&host=\$host">Errors</a>
</tr></tr>
</table>
<p>
\${h1("File/Directory list")}
<p>
<table border>
<tr><td>Original file/dir</td><td>Restored to</td></tr>
\$fileListStr
</table>
EOF

# -----------------------------------
$Lang{Email_Summary} = "BackupPC: Email Summary";

# -----------------------------------
#  !! ERROR messages !!
# -----------------------------------
$Lang{BackupPC__Lib__new_failed__check_apache_error_log} = "BackupPC::Lib->new failed: check apache error_log\n";
$Lang{Wrong_user__my_userid_is___} =  
              "Wrong user: my userid is \$>, instead of \$uid"
            . "(\$Conf{BackupPCUser})\n";
$Lang{Only_privileged_users_can_view_PC_summaries} = "Only privileged users can view PC summaries.";
$Lang{Only_privileged_users_can_stop_or_start_backups} = 
                  "Only privileged users can stop or start backups on"
		. " \${EscHTML(\$host)}.";
$Lang{Invalid_number__num} = "Invalid number \$num";
$Lang{Unable_to_open__file__configuration_problem} = "Unable to open \$file: configuration problem?";
$Lang{Only_privileged_users_can_view_log_or_config_files} = "Only privileged users can view log or config files.";
$Lang{Only_privileged_users_can_view_log_files} = "Only privileged users can view log files.";
$Lang{Only_privileged_users_can_view_email_summaries} = "Only privileged users can view email summaries.";
$Lang{Only_privileged_users_can_browse_backup_files} = "Only privileged users can browse backup files"
                . " for host \${EscHTML(\$In{host})}.";
$Lang{Empty_host_name} = "Empty host name.";
$Lang{Directory___EscHTML} = "Directory \${EscHTML(\"\$TopDir/pc/\$host/\$num\")}"
		    . " is empty";
$Lang{Can_t_browse_bad_directory_name2} = "Can\'t browse bad directory name"
	            . " \${EscHTML(\$relDir)}";
$Lang{Only_privileged_users_can_restore_backup_files} = "Only privileged users can restore backup files"
                . " for host \${EscHTML(\$In{host})}.";
$Lang{Bad_host_name} = "Bad host name \${EscHTML(\$host)}";
$Lang{You_haven_t_selected_any_files__please_go_Back_to} = "You haven\'t selected any files; please go Back to"
                . " select some files.";
$Lang{Nice_try__but_you_can_t_put} = "Nice try, but you can\'t put \'..\' in any of the file names";
$Lang{Host__doesn_t_exist} = "Host \${EscHTML(\$In{hostDest})} doesn\'t exist";
$Lang{You_don_t_have_permission_to_restore_onto_host} = "You don\'t have permission to restore onto host"
		    . " \${EscHTML(\$In{hostDest})}";
$Lang{Can_t_open_create} = "Can\'t open/create "
                    . "\${EscHTML(\"\$TopDir/pc/\$hostDest/\$reqFileName\")}";
$Lang{Only_privileged_users_can_restore_backup_files2} = "Only privileged users can restore backup files"
                . " for host \${EscHTML(\$host)}.";
$Lang{Empty_host_name} = "Empty host name";
$Lang{Unknown_host_or_user} = "Unknown host or user \${EscHTML(\$host)}";
$Lang{Only_privileged_users_can_view_information_about} = "Only privileged users can view information about"
                . " host \${EscHTML(\$host)}." ;
$Lang{Only_privileged_users_can_view_restore_information} = "Only privileged users can view restore information.";
$Lang{Restore_number__num_for_host__does_not_exist} = "Restore number \$num for host \${EscHTML(\$host)} does"
	        . " not exist.";

$Lang{Unable_to_connect_to_BackupPC_server} = "Unable to connect to BackupPC server",
            "This CGI script (\$MyURL) is unable to connect to the BackupPC"
          . " server on \$Conf{ServerHost} port \$Conf{ServerPort}.  The error"
          . " was: \$err.",
            "Perhaps the BackupPC server is not running or there is a "
          . " configuration error.  Please report this to your Sys Admin.";

$Lang{Can_t_find_IP_address_for} = "Can\'t find IP address for \${EscHTML(\$host)}";
$Lang{host_is_a_DHCP_host} = <<EOF;
\$host is a DHCP host, and I don\'t know its IP address.  I checked the
netbios name of \$ENV{REMOTE_ADDR}\$tryIP, and found that that machine
is not \$host.
<p>
Until I see \$host at a particular DHCP address, you can only
start this request from the client machine itself.
EOF

########################
# ok you can do it then
########################

$Lang{Backup_requested_on_DHCP__host} = "Backup requested on DHCP \$host (\$In{hostIP}) by"
		                      . " \$User from \$ENV{REMOTE_ADDR}";

$Lang{Backup_requested_on__host_by__User} = "Backup requested on \$host by \$User";
$Lang{Backup_stopped_dequeued_on__host_by__User} = "Backup stopped/dequeued on \$host by \$User";

$Lang{Restore_requested_to_host__hostDest__backup___num} = "Restore requested to host \$hostDest, backup #\$num,"
	     . " by \$User from \$ENV{REMOTE_ADDR}";

# -------------------------------------------------
# ------- Stuff that was forgotten ----------------
# -------------------------------------------------

$Lang{Status} = "Status";
$Lang{PC_Summary} = "PC Summary";
$Lang{LOG_file} = "LOG file";
$Lang{Old_LOGs} = "Old LOGs";
$Lang{Email_summary} = "Email summary";
$Lang{Config_file} = "Config file";
$Lang{Hosts_file} = "Hosts file";
$Lang{Current_queues} = "Current queues";
$Lang{Documentation} = "Documentation";

$Lang{Host_or_User_name} = "<small>Host or User name:</small>";
$Lang{Go} = "Go";
$Lang{Hosts} = "Hosts";

$Lang{This_PC_has_never_been_backed_up} = "<h2> This PC has never been backed up!! </h2>\n";
$Lang{This_PC_is_used_by} = "<li>This PC is used by \${UserLink(\$user)}";

$Lang{Extracting_only_Errors} = "(Extracting only Errors)";
$Lang{XferLOG} = "XferLOG";
$Lang{Errors}  = "Errors";

# ------------
$Lang{Last_email_sent_to__was_at___subject} = <<EOF;
<li>Last email sent to \${UserLink(\$user)} was at \$mailTime, subject "\$subj".
EOF
# ------------
$Lang{The_command_cmd_is_currently_running_for_started} = <<EOF;
<li>The command \$cmd is currently running for \$host, started \$startTime.
EOF

# -----------
$Lang{Host_host_is_queued_on_the_background_queue_will_be_backed_up_soon} = <<EOF;
<li>Host \$host is queued on the background queue (will be backed up soon).
EOF

# ----------
$Lang{Host_host_is_queued_on_the_user_queue__will_be_backed_up_soon} = <<EOF;
<li>Host \$host is queued on the user queue (will be backed up soon).
EOF

# ---------
$Lang{A_command_for_host_is_on_the_command_queue_will_run_soon} = <<EOF;
<li>A command for \$host is on the command queue (will run soon).
EOF

# --------
$Lang{Last_status_is_state_StatusHost_state_reason_as_of_startTime} = <<EOF;
<li>Last status is state \"\$Lang->{\$StatusHost{state}}\"\$reason as of \$startTime.
EOF

# --------
$Lang{Last_error_is____EscHTML_StatusHost_error} = <<EOF;
<li>Last error is \"\${EscHTML(\$StatusHost{error})}\".
EOF

# ------
$Lang{Pings_to_host_have_failed_StatusHost_deadCnt__consecutive_times} = <<EOF;
<li>Pings to \$host have failed \$StatusHost{deadCnt} consecutive times.
EOF

# -----
$Lang{Prior_to_that__pings} = "Prior to that, pings";

# -----
$Lang{priorStr_to_host_have_succeeded_StatusHostaliveCnt_consecutive_times} = <<EOF;
<li>\$priorStr to \$host have succeeded \$StatusHost{aliveCnt}
        consecutive times.
EOF

$Lang{Because__host_has_been_on_the_network_at_least__Conf_BlackoutGoodCnt_consecutive_times___} = <<EOF;
<li>Because \$host has been on the network at least \$Conf{BlackoutGoodCnt}
consecutive times, it will not be backed up from \$t0 to \$t1 on \$days.
EOF

$Lang{Backups_are_deferred_for_hours_hours_change_this_number} = <<EOF;
<li>Backups are deferred for \$hours hours
(<a href=\"\$MyURL?action=Stop/Dequeue%20Backup&host=\$host\">change this number</a>).
EOF

$Lang{tryIP} = " and \$StatusHost{dhcpHostIP}";

$Lang{Host_Inhost} = "Host \$In{host}";

$Lang{checkAll} = <<EOF;
<tr bgcolor="#ffffcc"><td>
<input type="checkbox" name="allFiles" onClick="return checkAll('allFiles');">&nbsp;Select all
</td><td colspan="5" align="center">
<input type="submit" name="Submit" value="Restore selected files">
</td></tr>
EOF

$Lang{fileHeader} = <<EOF;
    <tr bgcolor="\$Conf{CgiHeaderBgColor}"><td align=center> Name</td>
       <td align="center"> Type</td>
       <td align="center"> Mode</td>
       <td align="center"> #</td>
       <td align="center"> Size</td>
       <td align="center"> Mod time</td>
    </tr>
EOF

$Lang{Home} = "Home";
$Lang{Last_bad_XferLOG} = "Last bad XferLOG";
$Lang{Last_bad_XferLOG_errors_only} = "Last bad XferLOG (errors&nbsp;only)";

$Lang{This_display_is_merged_with_backup} = <<EOF;
<li> This display is merged with backup #\$numF.
EOF

$Lang{Visit_this_directory_in_backup} = <<EOF;
<li> Visit this directory in backup #\$otherDirs.
EOF

$Lang{Restore_Summary} = <<EOF;
\${h2("Restore Summary")}
<p>
Click on the restore number for more details.
<table border>
<tr><td align="center"> Restore# </td>
    <td align="center"> Result </td>
    <td align="right"> Start Date</td>
    <td align="right"> Dur/mins</td>
    <td align="right"> #files </td>
    <td align="right"> MB </td>
    <td align="right"> #tar errs </td>
    <td align="right"> #xferErrs </td>
</tr>
\$restoreStr
</table>
<p>
EOF

$Lang{BackupPC__Documentation} = "BackupPC: Documentation";

$Lang{No} = "no";
$Lang{Yes} = "yes";

$Lang{The_directory_is_empty} = <<EOF;
<tr><td bgcolor="#ffffff">The directory \${EscHTML(\$dirDisplay)} is empty
</td></tr>
EOF

#$Lang{on} = "on";
$Lang{off} = "off";

$Lang{full} = "full";
$Lang{incremental} = "incr";

$Lang{failed} = "failed";
$Lang{success} = "success";
$Lang{and} = "and";

# ------
# Hosts states and reasons
$Lang{Status_idle} = "idle";
$Lang{Status_backup_starting} = "backup starting";
$Lang{Status_backup_in_progress} = "backup in progress";
$Lang{Status_restore_starting} = "restore starting";
$Lang{Status_restore_in_progress} = "restore in progress";
$Lang{Status_link_pending} = "link pending";
$Lang{Status_link_running} = "link running";

$Lang{Reason_backup_done} = "backup done";
$Lang{Reason_restore_done} = "restore done";
$Lang{Reason_nothing_to_do} = "nothing to do";
$Lang{Reason_backup_failed} = "backup failed";
$Lang{Reason_restore_failed} = "restore failed";
$Lang{Reason_no_ping} = "no ping";
$Lang{Reason_backup_canceled_by_user} = "backup canceled by user";
$Lang{Reason_restore_canceled_by_user} = "restore canceled by user";

# ---------
# Email messages

# No backup ever
$Lang{EMailNoBackupEverSubj} = "BackupPC: no backups of \$host have succeeded";
$Lang{EMailNoBackupEverMesg} = <<'EOF';
To: $user$domain
cc:
Subject: $subj

Dear $userName,

Your PC ($host) has never been successfully backed up by our
PC backup software.  PC backups should occur automatically
when your PC is connected to the network.  You should contact
computer support if:

  - Your PC has been regularly connected to the network, meaning
    there is some configuration or setup problem preventing
    backups from occurring.

  - You don't want your PC backed up and you want these email
    messages to stop.

Otherwise, please make sure your PC is connected to the network
next time you are in the office.

Regards,
BackupPC Genie
http://backuppc.sourceforge.net
EOF

# No recent backup
$Lang{EMailNoBackupRecentSubj} = "BackupPC: no recent backups on \$host";
$Lang{EMailNoBackupRecentMesg} = <<'EOF';
To: $user$domain
cc:
Subject: $subj

Dear $userName,

Your PC ($host) has not been successfully backed up for $days days.
Your PC has been correctly backed up $numBackups times from $firstTime to $days
ago.  PC backups should occur automatically when your PC is connected
to the network.

If your PC has been connected for more than a few hours to the
network during the last $days days you should contact IS to find
out why backups are not working.

Otherwise, if you are out of the office, there's not much you can
do, other than manually copying especially critical files to other
media.  You should be aware that any files you have created or
changed in the last $days days (including all new email and
attachments) cannot be restored if your PC disk crashes.

Regards,
BackupPC Genie
http://backuppc.sourceforge.net
EOF

# Old Outlook files
$Lang{EMailOutlookBackupSubj} = "BackupPC: Outlook files on \$host need to be backed up";
$Lang{EMailOutlookBackupMesg} = <<'EOF';
To: $user$domain
cc:
Subject: $subj

Dear $userName,

The Outlook files on your PC have $howLong.
These files contain all your email, attachments, contact and calendar           
information.  Your PC has been correctly backed up $numBackups times from
$firstTime to $lastTime days ago.  However, Outlook locks all its files when
it is running, preventing these files from being backed up.

It is recommended you backup the Outlook files when you are connected
to the network by exiting Outlook and all other applications, and,
using just your browser, go to this link:

    $CgiURL?host=$host               

Select "Start Incr Backup" twice to start a new incremental backup.
You can select "Return to $host page" and then hit "reload" to check
the status of the backup.  It should take just a few minutes to
complete.

Regards,
BackupPC Genie
http://backuppc.sourceforge.net
EOF

$Lang{howLong_not_been_backed_up} = "not been backed up successfully";
$Lang{howLong_not_been_backed_up_for_days_days} = "not been backed up for \$days days";

#end of lang_en.pm
