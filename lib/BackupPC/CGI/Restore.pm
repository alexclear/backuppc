#============================================================= -*-perl-*-
#
# BackupPC::CGI::Restore package
#
# DESCRIPTION
#
#   This module implements the Restore action for the CGI interface.
#
# AUTHOR
#   Craig Barratt  <cbarratt@users.sourceforge.net>
#
# COPYRIGHT
#   Copyright (C) 2003  Craig Barratt
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
# Version 2.1.0, released 20 Jun 2004.
#
# See http://backuppc.sourceforge.net.
#
#========================================================================

package BackupPC::CGI::Restore;

use strict;
use BackupPC::CGI::Lib qw(:all);
use Data::Dumper;
use File::Path;

sub action
{
    my($str, $reply, $content);
    my $Privileged = CheckPermission($In{host});
    if ( !$Privileged ) {
        ErrorExit(eval("qq{$Lang->{Only_privileged_users_can_restore_backup_files}}"));
    }
    my $host  = $In{host};
    my $num   = $In{num};
    my $share = $In{share};
    my(@fileList, $fileListStr, $hiddenStr, $pathHdr, $badFileCnt);
    my @Backups = $bpc->BackupInfoRead($host);

    ServerConnect();
    if ( !defined($Hosts->{$host}) ) {
        ErrorExit(eval("qq{$Lang->{Bad_host_name}}"));
    }
    for ( my $i = 0 ; $i < $In{fcbMax} ; $i++ ) {
        next if ( !defined($In{"fcb$i"}) );
        (my $name = $In{"fcb$i"}) =~ s/%([0-9A-F]{2})/chr(hex($1))/eg;
        $badFileCnt++ if ( $name =~ m{(^|/)\.\.(/|$)} );
	if ( @fileList == 0 ) {
	    $pathHdr = substr($name, 0, rindex($name, "/"));
	} else {
	    while ( substr($name, 0, length($pathHdr)) ne $pathHdr ) {
		$pathHdr = substr($pathHdr, 0, rindex($pathHdr, "/"));
	    }
	}
        push(@fileList, $name);
        $hiddenStr .= <<EOF;
<input type="hidden" name="fcb$i" value="$In{'fcb' . $i}">
EOF
        $fileListStr .= <<EOF;
<li> ${EscHTML($name)}
EOF
    }
    $hiddenStr .= "<input type=\"hidden\" name=\"fcbMax\" value=\"$In{fcbMax}\">\n";
    $hiddenStr .= "<input type=\"hidden\" name=\"share\" value=\"${EscHTML($share)}\">\n";
    $badFileCnt++ if ( $In{pathHdr} =~ m{(^|/)\.\.(/|$)} );
    $badFileCnt++ if ( $In{num} =~ m{(^|/)\.\.(/|$)} );
    if ( @fileList == 0 ) {
        ErrorExit($Lang->{You_haven_t_selected_any_files__please_go_Back_to});
    }
    if ( $badFileCnt ) {
        ErrorExit($Lang->{Nice_try__but_you_can_t_put});
    }
    $pathHdr = "/" if ( $pathHdr eq "" );
    if ( $In{type} != 0 && @fileList == $In{fcbMax} ) {
	#
	# All the files in the list were selected, so just restore the
	# entire parent directory
	#
	@fileList = ( $pathHdr );
    }
    if ( $In{type} == 0 ) {
	#
	# Build list of hosts
	#
	my $hostDestSel;
        my @hosts;
	foreach my $h ( GetUserHosts(1) ) {
	    my $sel = " selected" if ( $h eq $In{host} );
	    $hostDestSel .= "<option value=\"$h\"$sel>${EscHTML($h)}</option>";
            push(@hosts, $h);
	}

        #
        # Tell the user what options they have
        #
	$content .= eval("qq{$Lang->{Restore_Options_for__host2}}");

        #
        # If there is a single host, make sure direct restore is enabled
        #
        if ( @hosts == 1 ) {
            #
            # Pick up the host's config file
            #
            $bpc->ConfigRead($hosts[0]);
            %Conf = $bpc->Conf();

            #
            # Decide if option 1 (direct restore) is available based
            # on whether the restore command is set.
            #
            my $cmd = $Conf{XferMethod} eq "smb" ? $Conf{SmbClientRestoreCmd}
                    : $Conf{XferMethod} eq "tar" ? $Conf{TarClientRestoreCmd}
                    : $Conf{XferMethod} eq "archive" ? undef
                    : $Conf{RsyncRestoreArgs};
            if ( defined($cmd) ) {
                $content .= eval(
                    "qq{$Lang->{Restore_Options_for__host_Option1}}");
            } else {
                my $hostDest = $hosts[0];
                $content .= eval(
                    "qq{$Lang->{Restore_Options_for__host_Option1_disabled}}");
            }
        } else {
            $content .= eval("qq{$Lang->{Restore_Options_for__host_Option1}}");
        }

	#
	# Verify that Archive::Zip is available before showing the
	# zip restore option
	#
	if ( eval { require Archive::Zip } ) {
	    $content .= eval("qq{$Lang->{Option_2__Download_Zip_archive}}");
	} else {
	    $content .= eval("qq{$Lang->{Option_2__Download_Zip_archive2}}");
	}
	$content .= eval("qq{$Lang->{Option_3__Download_Zip_archive}}");
	Header(eval("qq{$Lang->{Restore_Options_for__host}}"), $content);
        Trailer();
    } elsif ( $In{type} == 1 ) {
        #
        # Provide the selected files via a tar archive.
	#
	my @fileListTrim = @fileList;
	if ( @fileListTrim > 10 ) {
	    @fileListTrim = (@fileListTrim[0..9], '...');
	}
	$bpc->ServerMesg("log User $User downloaded tar archive for $host,"
		       . " backup $num; files were: "
		       . join(", ", @fileListTrim));

        my @pathOpts;
        if ( $In{relative} ) {
            @pathOpts = ("-r", $pathHdr, "-p", "");
        }
	print(STDOUT <<EOF);
Content-Type: application/x-gtar
Content-Transfer-Encoding: binary
Content-Disposition: attachment; filename=\"restore.tar\"

EOF
	#
	# Fork the child off and manually copy the output to our stdout.
	# This is necessary to ensure the output gets to the correct place
	# under mod_perl.
	#
	$bpc->cmdSystemOrEvalLong(["$BinDir/BackupPC_tarCreate",
		 "-h", $host,
		 "-n", $num,
		 "-s", $share,
		 @pathOpts,
		 @fileList
	    ],
	    sub { print(@_); },
	    1,			# ignore stderr
	);
    } elsif ( $In{type} == 2 ) {
        #
        # Provide the selected files via a zip archive.
	#
	my @fileListTrim = @fileList;
	if ( @fileListTrim > 10 ) {
	    @fileListTrim = (@fileListTrim[0..9], '...');
	}
	$bpc->ServerMesg("log User $User downloaded zip archive for $host,"
		       . " backup $num; files were: "
		       . join(", ", @fileListTrim));

        my @pathOpts;
        if ( $In{relative} ) {
            @pathOpts = ("-r", $pathHdr, "-p", "");
        }
	print(STDOUT <<EOF);
Content-Type: application/zip
Content-Transfer-Encoding: binary
Content-Disposition: attachment; filename=\"restore.zip\"

EOF
	$In{compressLevel} = 5 if ( $In{compressLevel} !~ /^\d+$/ );
	#
	# Fork the child off and manually copy the output to our stdout.
	# This is necessary to ensure the output gets to the correct place
	# under mod_perl.
	#
	$bpc->cmdSystemOrEvalLong(["$BinDir/BackupPC_zipCreate",
		 "-h", $host,
		 "-n", $num,
		 "-c", $In{compressLevel},
		 "-s", $share,
		 @pathOpts,
		 @fileList
	    ],
	    sub { print(@_); },
	    1,			# ignore stderr
	);
    } elsif ( $In{type} == 3 ) {
        #
        # Do restore directly onto host
        #
	if ( !defined($Hosts->{$In{hostDest}}) ) {
	    ErrorExit(eval("qq{$Lang->{Host__doesn_t_exist}}"));
	}
	if ( !CheckPermission($In{hostDest}) ) {
	    ErrorExit(eval("qq{$Lang->{You_don_t_have_permission_to_restore_onto_host}}"));
	}
        #
        # Pick up the destination host's config file
        #
        my $hostDest = $1 if ( $In{hostDest} =~ /(.*)/ );
        $bpc->ConfigRead($hostDest);
        %Conf = $bpc->Conf();

        #
        # Decide if option 1 (direct restore) is available based
        # on whether the restore command is set.
        #
        my $cmd = $Conf{XferMethod} eq "smb" ? $Conf{SmbClientRestoreCmd}
                : $Conf{XferMethod} eq "tar" ? $Conf{TarClientRestoreCmd}
                : $Conf{XferMethod} eq "archive" ? undef
                : $Conf{RsyncRestoreArgs};
        if ( !defined($cmd) ) {
	    ErrorExit(eval("qq{$Lang->{Restore_Options_for__host_Option1_disabled}}"));
        }

        $fileListStr = "";
        foreach my $f ( @fileList ) {
            my $targetFile = $f;
	    (my $strippedShare = $share) =~ s/^\///;
	    (my $strippedShareDest = $In{shareDest}) =~ s/^\///;
            substr($targetFile, 0, length($pathHdr)) = "/$In{pathHdr}/";
	    $targetFile =~ s{//+}{/}g;
            $fileListStr .= <<EOF;
<tr><td>$host:/$strippedShare$f</td><td>$In{hostDest}:/$strippedShareDest$targetFile</td></tr>
EOF
        }
        my $content = eval("qq{$Lang->{Are_you_sure}}");
        Header(eval("qq{$Lang->{Restore_Confirm_on__host}}"), $content);
        Trailer();
    } elsif ( $In{type} == 4 ) {
	if ( !defined($Hosts->{$In{hostDest}}) ) {
	    ErrorExit(eval("qq{$Lang->{Host__doesn_t_exist}}"));
	}
	if ( !CheckPermission($In{hostDest}) ) {
	    ErrorExit(eval("qq{$Lang->{You_don_t_have_permission_to_restore_onto_host}}"));
	}
	my $hostDest = $1 if ( $In{hostDest} =~ /(.+)/ );
	my $ipAddr = ConfirmIPAddress($hostDest);
        #
        # Prepare and send the restore request.  We write the request
        # information using Data::Dumper to a unique file,
        # $TopDir/pc/$hostDest/restoreReq.$$.n.  We use a file
        # in case the list of files to restore is very long.
        #
        my $reqFileName;
        for ( my $i = 0 ; ; $i++ ) {
            $reqFileName = "restoreReq.$$.$i";
            last if ( !-f "$TopDir/pc/$hostDest/$reqFileName" );
        }
	my $inPathHdr = $In{pathHdr};
	$inPathHdr = "/$inPathHdr" if ( $inPathHdr !~ m{^/} );
	$inPathHdr = "$inPathHdr/" if ( $inPathHdr !~ m{/$} );
        my %restoreReq = (
	    # source of restore is hostSrc, #num, path shareSrc/pathHdrSrc
            num         => $In{num},
            hostSrc     => $host,
            shareSrc    => $share,
            pathHdrSrc  => $pathHdr,

	    # destination of restore is hostDest:shareDest/pathHdrDest
            hostDest    => $hostDest,
            shareDest   => $In{shareDest},
            pathHdrDest => $inPathHdr,

	    # list of files to restore
            fileList    => \@fileList,

	    # other info
            user        => $User,
            reqTime     => time,
        );
        my($dump) = Data::Dumper->new(
                         [  \%restoreReq],
                         [qw(*RestoreReq)]);
        $dump->Indent(1);
        mkpath("$TopDir/pc/$hostDest", 0, 0777)
                                    if ( !-d "$TopDir/pc/$hostDest" );
	my $openPath = "$TopDir/pc/$hostDest/$reqFileName";
        if ( open(REQ, ">", $openPath) ) {
	    binmode(REQ);
            print(REQ $dump->Dump);
            close(REQ);
        } else {
            ErrorExit(eval("qq{$Lang->{Can_t_open_create__openPath}}"));
        }
	$reply = $bpc->ServerMesg("restore ${EscURI($ipAddr)}"
			. " ${EscURI($hostDest)} $User $reqFileName");
	$str = eval("qq{$Lang->{Restore_requested_to_host__hostDest__backup___num}}");
	my $content = eval("qq{$Lang->{Reply_from_server_was___reply}}");
        Header(eval("qq{$Lang->{Restore_Requested_on__hostDest}}"), $content);
        Trailer();
    }
}

1;
