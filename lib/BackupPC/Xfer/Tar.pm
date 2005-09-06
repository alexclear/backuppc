#============================================================= -*-perl-*-
#
# BackupPC::Xfer::Tar package
#
# DESCRIPTION
#
#   This library defines a BackupPC::Xfer::Tar class for managing
#   the tar-based transport of backup data from the client.
#
# AUTHOR
#   Craig Barratt  <cbarratt@users.sourceforge.net>
#
# COPYRIGHT
#   Copyright (C) 2001-2003  Craig Barratt
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#========================================================================
#
# Version 2.1.2, released 5 Sep 2005.
#
# See http://backuppc.sourceforge.net.
#
#========================================================================

package BackupPC::Xfer::Tar;

use strict;

sub new
{
    my($class, $bpc, $args) = @_;

    $args ||= {};
    my $t = bless {
        bpc       => $bpc,
        conf      => { $bpc->Conf },
        host      => "",
        hostIP    => "",
        shareName => "",
        pipeRH    => undef,
        pipeWH    => undef,
        badFiles  => [],
        %$args,
    }, $class;

    return $t;
}

sub args
{
    my($t, $args) = @_;

    foreach my $arg ( keys(%$args) ) {
	$t->{$arg} = $args->{$arg};
    }
}

sub useTar
{
    return 1;
}

sub start
{
    my($t) = @_;
    my $bpc = $t->{bpc};
    my $conf = $t->{conf};
    my(@fileList, $tarClientCmd, $logMsg, $incrDate);
    local(*TAR);

    if ( $t->{type} eq "restore" ) {
	$tarClientCmd = $conf->{TarClientRestoreCmd};
        $logMsg = "restore started below directory $t->{shareName}";
	#
	# restores are considered to work unless we see they fail
	# (opposite to backups...)
	#
	$t->{xferOK} = 1;
    } else {
	#
	# Turn $conf->{BackupFilesOnly} and $conf->{BackupFilesExclude}
	# into a hash of arrays of files, and $conf->{TarShareName}
	# to an array
	#
	$bpc->backupFileConfFix($conf, "TarShareName");

        if ( defined($conf->{BackupFilesExclude}{$t->{shareName}}) ) {
            foreach my $file ( @{$conf->{BackupFilesExclude}{$t->{shareName}}} )
            {
		$file = ".$file" if ( $file =~ /^\// );
                push(@fileList, "--exclude=$file");
            }
        }
        if ( defined($conf->{BackupFilesOnly}{$t->{shareName}}) ) {
            foreach my $file ( @{$conf->{BackupFilesOnly}{$t->{shareName}}} ) {
		$file = ".$file" if ( $file =~ /^\// );
                push(@fileList, $file);
            }
        } else {
	    push(@fileList, ".");
        }
	if ( ref($conf->{TarClientCmd}) eq "ARRAY" ) {
	    $tarClientCmd = $conf->{TarClientCmd};
	} else {
	    $tarClientCmd = [split(/ +/, $conf->{TarClientCmd})];
	}
	my $args;
        if ( $t->{type} eq "full" ) {
	    $args = $conf->{TarFullArgs};
            $logMsg = "full backup started for directory $t->{shareName}";
        } else {
            $incrDate = $bpc->timeStamp($t->{lastFull} - 3600, 1);
	    $args = $conf->{TarIncrArgs};
            $logMsg = "incr backup started back to $incrDate for directory"
                    . " $t->{shareName}";
        }
	push(@$tarClientCmd, split(/ +/, $args));
    }
    #
    # Merge variables into @tarClientCmd
    #
    my $args = {
        host      => $t->{host},
        hostIP    => $t->{hostIP},
        client    => $t->{client},
        incrDate  => $incrDate,
        shareName => $t->{shareName},
	fileList  => \@fileList,
        tarPath   => $conf->{TarClientPath},
        sshPath   => $conf->{SshPath},
    };
    $tarClientCmd = $bpc->cmdVarSubstitute($tarClientCmd, $args);
    if ( !defined($t->{xferPid} = open(TAR, "-|")) ) {
        $t->{_errStr} = "Can't fork to run tar";
        return;
    }
    $t->{pipeTar} = *TAR;
    if ( !$t->{xferPid} ) {
        #
        # This is the tar child.
        #
        setpgrp 0,0;
        if ( $t->{type} eq "restore" ) {
            #
            # For restores, close the write end of the pipe,
            # clone STDIN to RH
            #
            close($t->{pipeWH});
            close(STDERR);
            open(STDERR, ">&STDOUT");
            close(STDIN);
            open(STDIN, "<&$t->{pipeRH}");
        } else {
            #
            # For backups, close the read end of the pipe,
            # clone STDOUT to WH, and STDERR to STDOUT
            #
            close($t->{pipeRH});
            close(STDERR);
            open(STDERR, ">&STDOUT");
            open(STDOUT, ">&$t->{pipeWH}");
        }
        #
        # Run the tar command
        #
	alarm(0);
	$bpc->cmdExecOrEval($tarClientCmd, $args);
        # should not be reached, but just in case...
        $t->{_errStr} = "Can't exec @$tarClientCmd";
        return;
    }
    my $str = "Running: " . $bpc->execCmd2ShellCmd(@$tarClientCmd) . "\n";
    $t->{XferLOG}->write(\"Running: @$tarClientCmd\n");
    alarm($conf->{ClientTimeout});
    $t->{_errStr} = undef;
    return $logMsg;
}

sub readOutput
{
    my($t, $FDreadRef, $rout) = @_;
    my $conf = $t->{conf};

    if ( vec($rout, fileno($t->{pipeTar}), 1) ) {
        my $mesg;
        if ( sysread($t->{pipeTar}, $mesg, 8192) <= 0 ) {
            vec($$FDreadRef, fileno($t->{pipeTar}), 1) = 0;
	    if ( !close($t->{pipeTar}) ) {
		$t->{tarOut} .= "Tar exited with error $? ($!) status\n";
		$t->{xferOK} = 0 if ( !$t->{tarBadExitOk} );
	    }
        } else {
            $t->{tarOut} .= $mesg;
        }
    }
    while ( $t->{tarOut} =~ /(.*?)[\n\r]+(.*)/s ) {
        $_ = $1;
        $t->{tarOut} = $2;
        #
        # refresh our inactivity alarm
        #
        alarm($conf->{ClientTimeout}) if ( !$t->{abort} );
        $t->{lastOutputLine} = $_ if ( !/^$/ );
        if ( /^Total bytes written: / ) {
            $t->{XferLOG}->write(\"$_\n") if ( $t->{logLevel} >= 1 );
            $t->{xferOK} = 1;
        } elsif ( /^\./ ) {
            $t->{XferLOG}->write(\"$_\n") if ( $t->{logLevel} >= 2 );
            $t->{fileCnt}++;
        } else {
            $t->{XferLOG}->write(\"$_\n") if ( $t->{logLevel} >= 0 );
            $t->{xferErrCnt}++;
	    #
	    # If tar encounters a minor error, it will exit with a non-zero
	    # status.  We still consider that ok.  Remember if tar prints
	    # this message indicating a non-fatal error.
	    #
	    $t->{tarBadExitOk} = 1
		    if ( $t->{xferOK} && /Error exit delayed from previous / );
            #
            # Also remember files that had read errors
            #
            if ( /: \.\/(.*): Read error at byte / ) {
                my $badFile = $1;
                push(@{$t->{badFiles}}, {
                        share => $t->{shareName},
                        file  => $badFile
                    });
            }

	}
    }
    return 1;
}

sub abort
{
    my($t, $reason) = @_;
    my @xferPid = $t->xferPid;

    $t->{abort} = 1;
    $t->{abortReason} = $reason;
    if ( @xferPid ) {
	kill($t->{bpc}->sigName2num("INT"), @xferPid);
    }
}

sub setSelectMask
{
    my($t, $FDreadRef) = @_;

    vec($$FDreadRef, fileno($t->{pipeTar}), 1) = 1;
}

sub errStr
{
    my($t) = @_;

    return $t->{_errStr};
}

sub xferPid
{
    my($t) = @_;

    return ($t->{xferPid});
}

sub logMsg
{
    my($t, $msg) = @_;

    push(@{$t->{_logMsg}}, $msg);
}

sub logMsgGet
{
    my($t) = @_;

    return shift(@{$t->{_logMsg}});
}

#
# Returns a hash ref giving various status information about
# the transfer.
#
sub getStats
{
    my($t) = @_;

    return { map { $_ => $t->{$_} }
            qw(byteCnt fileCnt xferErrCnt xferBadShareCnt xferBadFileCnt
               xferOK hostAbort hostError lastOutputLine)
    };
}

sub getBadFiles
{
    my($t) = @_;

    return @{$t->{badFiles}};
}

1;
