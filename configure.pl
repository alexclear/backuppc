#!/bin/perl
#============================================================= -*-perl-*-
#
# configure.pl: Configuration and installation program for BackupPC
#
# DESCRIPTION
#
#   This script should be run as root:
#
#        perl configure.pl
#
#   The installation steps are described as the script runs.
#
# AUTHOR
#   Craig Barratt <cbarratt@users.sourceforge.net>
#
# COPYRIGHT
#   Copyright (C) 2001-2004  Craig Barratt
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
# Version 2.1.0beta1, released 9 Apr 2004.
#
# See http://backuppc.sourceforge.net.
#
#========================================================================

use strict;
no  utf8;
use vars qw(%Conf %OrigConf);
use lib "./lib";

my @Packages = qw(File::Path File::Spec File::Copy DirHandle Digest::MD5
                  Data::Dumper Getopt::Std Getopt::Long Pod::Usage
                  BackupPC::Lib BackupPC::FileZIO);

foreach my $pkg ( @Packages ) {
    eval "use $pkg";
    next if ( !$@ );
    if ( $pkg =~ /BackupPC/ ) {
        die <<EOF;

BackupPC cannot find the package $pkg, which is included in the
BackupPC distribution.  This probably means you did not cd to the
unpacked BackupPC distribution before running configure.pl, eg:

    cd BackupPC-__VERSION__
    ./configure.pl

Please try again.

EOF
    }
    die <<EOF;

BackupPC needs the package $pkg.  Please install $pkg
before installing BackupPC.

EOF
}

my %opts;
if ( !GetOptions(
            \%opts,
            "batch",
            "bin-path=s%",
            "config-path=s",
            "cgi-dir=s",
            "data-dir=s",
            "dest-dir=s",
            "help|?",
            "hostname=s",
            "html-dir=s",
            "html-dir-url=s",
            "install-dir=s",
            "man",
            "uid-ignore",
        ) || @ARGV ) {
    pod2usage(2);
}
pod2usage(1) if ( $opts{help} );
pod2usage(-exitstatus => 0, -verbose => 2) if $opts{man};

my $DestDir = $opts{"dest-dir"};

if ( $< != 0 ) {
    print <<EOF;

This configure script should be run as root, rather than uid $<.
Provided uid $< has sufficient permissions to create the data and
install directories, then it should be ok to proceed.  Otherwise,
please quit and restart as root.

EOF
    exit(1) if ( prompt("--> Do you want to continue?",
                       "y") !~ /y/i );
    exit(1) if ( $opts{batch} && !$opts{"uid-ignore"} );
}

print <<EOF;

Is this a new installation or upgrade for BackupPC?  If this is
an upgrade please tell me the full path of the existing BackupPC
configuration file (eg: /xxxx/conf/config.pl).  Otherwise, just
hit return.

EOF

#
# Check if this is an upgrade, in which case read the existing
# config file to get all the defaults.
#
my $ConfigPath = "";
while ( 1 ) {
    $ConfigPath = prompt("--> Full path to existing conf/config.pl",
                         $ConfigPath,
                         "config-path");
    last if ( $ConfigPath eq ""
            || ($ConfigPath =~ /^\// && -r $ConfigPath && -w $ConfigPath) );
    my $problem = "is not an absolute path";
    $problem = "is not writable" if ( !-w $ConfigPath );
    $problem = "is not readable" if ( !-r $ConfigPath );
    $problem = "doesn't exist"   if ( !-f $ConfigPath );
    print("The file '$ConfigPath' $problem.\n");
    if ( $opts{batch} ) {
        print("Need to specify a valid --config-path for upgrade\n");
        exit(1);
    }
}
my $bpc;
if ( $ConfigPath ne "" && -r $ConfigPath ) {
    (my $topDir = $ConfigPath) =~ s{/[^/]+/[^/]+$}{};
    die("BackupPC::Lib->new failed\n")
            if ( !($bpc = BackupPC::Lib->new($topDir, ".", 1)) );
    %Conf = $bpc->Conf();
    %OrigConf = %Conf;
    $Conf{TopDir} = $topDir;
    my $err = $bpc->ServerConnect($Conf{ServerHost}, $Conf{ServerPort}, 1);
    if ( $err eq "" ) {
        print <<EOF;

BackupPC is running on $Conf{ServerHost}.  You need to stop BackupPC
before you can upgrade the code.  Depending upon your installation,
you could run "/etc/init.d/backuppc stop".

EOF
        exit(1);
    }
}

#
# These are the programs whose paths we need to find
#
my %Programs = (
    perl           => "PerlPath",
    'gtar/tar'     => "TarClientPath",
    smbclient      => "SmbClientPath",
    nmblookup      => "NmbLookupPath",
    rsync          => "RsyncClientPath",
    ping           => "PingPath",
    df             => "DfPath",
    'ssh/ssh2'     => "SshPath",
    sendmail       => "SendmailPath",
    hostname       => "HostnamePath",
    split          => "SplitPath",
    par2           => "ParPath",
    cat            => "CatPath",
    gzip           => "GzipPath",
    bzip2          => "Bzip2Path",
);

foreach my $prog ( sort(keys(%Programs)) ) {
    my $path;
    foreach my $subProg ( split(/\//, $prog) ) {
        $path = FindProgram("$ENV{PATH}:/bin:/usr/bin:/sbin:/usr/sbin",
                            $subProg) if ( !length($path) );
    }
    $Conf{$Programs{$prog}} = $path if ( !length($Conf{$Programs{$prog}}) );
}

while ( 1 ) {
    print <<EOF;

I found the following locations for these programs:

EOF
    foreach my $prog ( sort(keys(%Programs)) ) {
        printf("    %-12s => %s\n", $prog, $Conf{$Programs{$prog}});
    }
    print "\n";
    last if (prompt('--> Are these paths correct?', 'y') =~ /^y/i);
    foreach my $prog ( sort(keys(%Programs)) ) {
        $Conf{$Programs{$prog}} = prompt("--> $prog path",
                                         $Conf{$Programs{$prog}});
    }
}

my $Perl56 = system($Conf{PerlPath}
                        . q{ -e 'exit($^V && $^V ge v5.6.0 ? 1 : 0);'});

if ( !$Perl56 ) {
    print <<EOF;

BackupPC needs perl version 5.6.0 or later.  $Conf{PerlPath} appears
to be an older version.  Please upgrade to a newer version of perl
and re-run this configure script.

EOF
    exit(1);
}

print <<EOF;

Please tell me the hostname of the machine that BackupPC will run on.

EOF
chomp($Conf{ServerHost} = `$Conf{HostnamePath}`)
        if ( defined($Conf{HostnamePath}) && !defined($Conf{ServerHost}) );
$Conf{ServerHost} = prompt("--> BackupPC will run on host",
                           $Conf{ServerHost},
                           "hostname");

print <<EOF;

BackupPC should run as a dedicated user with limited privileges.  You
need to create a user.  This user will need read/write permission on
the main data directory and read/execute permission on the install
directory (these directories will be setup shortly).

The primary group for this user should also be chosen carefully.
By default the install directories will have group write permission.
The data directories and files will have group read permission but
no other permission.

EOF
my($name, $passwd, $Uid, $Gid);
while ( 1 ) {
    $Conf{BackupPCUser} = prompt("--> BackupPC should run as user",
                                 $Conf{BackupPCUser} || "backuppc",
                                 "username");
    ($name, $passwd, $Uid, $Gid) = getpwnam($Conf{BackupPCUser});
    last if ( $name ne "" );
    print <<EOF;

getpwnam() says that user $Conf{BackupPCUser} doesn't exist.  Please check the
name and verify that this user is in the passwd file.

EOF
    exit(1) if ( $opts{batch} );
}

print <<EOF;

Please specify an install directory for BackupPC.  This is where the
BackupPC scripts, library and documentation will be installed.

EOF

while ( 1 ) {
    $Conf{InstallDir} = prompt("--> Install directory (full path)",
                               $Conf{InstallDir},
                               "install-dir");
    last if ( $Conf{InstallDir} =~ /^\// );
    if ( $opts{batch} ) {
        print("Need to specify --install-dir for new installation\n");
        exit(1);
    }
}

print <<EOF;

Please specify a data directory for BackupPC.  This is where the
configuration files, LOG files and all the PC backups are stored.
This file system needs to be big enough to accommodate all the
PCs you expect to backup (eg: at least 1-2GB per machine).

EOF

while ( 1 ) {
    $Conf{TopDir} = prompt("--> Data directory (full path)",
                           $Conf{TopDir},
                           "data-dir");
    last if ( $Conf{TopDir} =~ /^\// );
    if ( $opts{batch} ) {
        print("Need to specify --data-dir for new installation\n");
        exit(1);
    }
}

if ( !defined($Conf{CompressLevel}) ) {
    $Conf{CompressLevel} = BackupPC::FileZIO->compOk ? 3 : 0;
    if ( $ConfigPath eq "" && $Conf{CompressLevel} ) {
        print <<EOF;

BackupPC can compress pool files, providing around a 40% reduction in pool
size (your mileage may vary). Specify the compression level (0 turns
off compression, and 1 to 9 represent good/fastest to best/slowest).
The recommended values are 0 (off) or 3 (reasonable compression and speed).
Increasing the compression level to 5 will use around 20% more cpu time
and give perhaps 2-3% more compression.

EOF
    } elsif ( $ConfigPath eq "" ) {
        print <<EOF;

BackupPC can compress pool files, but it needs the Compress::Zlib
package installed (see www.cpan.org). Compression will provide around a
40% reduction in pool size, at the expense of cpu time.  You can leave
compression off and run BackupPC without compression, in which case you
should leave the compression level at 0 (which means off).  You could
install Compress::Zlib and turn compression on later, but read the
documentation first about how to do this.  Or the better choice is
to quit, install Compress::Zlib, and re-run configure.pl.

EOF
    } elsif ( $Conf{CompressLevel} ) {
        $Conf{CompressLevel} = 0;
        print <<EOF;

BackupPC now supports pool file compression.  Since you are upgrading
BackupPC you probably have existing uncompressed backups.  You have
several choices if you want to turn on compression.  You can run
the script BackupPC_compressPool to convert everything to compressed
form.  Or you can simply turn on compression, so that new backups
will be compressed.  This will increase the pool storage requirement,
since both uncompressed and compressed copies of files will be stored.
But eventually the old uncompressed backups will expire, recovering
the pool storage.  Please see the documentation for more details.

If you are not sure what to do, leave the Compression Level at 0,
which disables compression.  You can always read the documentation
and turn it on later.

EOF
    } else {
        $Conf{CompressLevel} = 0;
        print <<EOF;

BackupPC now supports pool file compression, but it needs the
Compress::Zlib module (see www.cpan.org).  For now, leave
the compression level set at 0 to disable compression.  If you
want you can install Compress::Zlib and turn compression on.
Please see the documentation for more details about converting
old backups to compressed form.

EOF
    }
    while ( 1 ) {
        $Conf{CompressLevel}
                    = prompt("--> Compression level", $Conf{CompressLevel});
        last if ( $Conf{CompressLevel} =~ /^\d+$/ );
    }
}

print <<EOF;

BackupPC has a powerful CGI perl interface that runs under Apache.
A single executable needs to be installed in a cgi-bin directory.
This executable needs to run as set-uid $Conf{BackupPCUser}, or
it can be run under mod_perl with Apache running as user $Conf{BackupPCUser}.

Leave this path empty if you don't want to install the CGI interface.

EOF

while ( 1 ) {
    $Conf{CgiDir} = prompt("--> CGI bin directory (full path)",
                           $Conf{CgiDir},
                           "cgi-dir");
    last if ( $Conf{CgiDir} =~ /^\// || $Conf{CgiDir} eq "" );
    if ( $opts{batch} ) {
        print("Need to specify --cgi-dir for new installation\n");
        exit(1);
    }
}

if ( $Conf{CgiDir} ne "" ) {

    print <<EOF;

BackupPC's CGI script needs to display various GIF images that
should be stored where Apache can serve them.  They should be
placed somewher under Apache's DocumentRoot.  BackupPC also
needs to know the URL to access these images.  Example:

    Apache image directory:  /usr/local/apache/htdocs/BackupPC
    URL for image directory: /BackupPC

The URL for the image directory should start with a slash.

EOF
    while ( 1 ) {
	$Conf{CgiImageDir} = prompt("--> Apache image directory (full path)",
                                    $Conf{CgiImageDir},
                                    "html-dir");
	last if ( $Conf{CgiImageDir} =~ /^\// );
        if ( $opts{batch} ) {
            print("Need to specify --html-dir for new installation\n");
            exit(1);
        }
    }
    while ( 1 ) {
	$Conf{CgiImageDirURL} = prompt("--> URL for image directory (omit http://host; starts with '/')",
					$Conf{CgiImageDirURL},
                                        "html-dir-url");
	last if ( $Conf{CgiImageDirURL} =~ /^\// );
        if ( $opts{batch} ) {
            print("Need to specify --html-dir-url for new installation\n");
            exit(1);
        }
    }
}

print <<EOF;

Ok, we're about to:

  - install the binaries, lib and docs in $Conf{InstallDir},
  - create the data directory $Conf{TopDir},
  - create/update the config.pl file $Conf{TopDir}/conf,
  - optionally install the cgi-bin interface.

EOF

exit unless prompt("--> Do you want to continue?", "y") =~ /y/i;

#
# Create install directories
#
foreach my $dir ( qw(bin doc
		     lib/BackupPC/CGI
		     lib/BackupPC/Lang
		     lib/BackupPC/Xfer
		     lib/BackupPC/Zip
		 ) ) {
    next if ( -d "$DestDir$Conf{InstallDir}/$dir" );
    mkpath("$DestDir$Conf{InstallDir}/$dir", 0, 0775);
    if ( !-d "$DestDir$Conf{InstallDir}/$dir"
            || !chown($Uid, $Gid, "$DestDir$Conf{InstallDir}/$dir") ) {
        die("Failed to create or chown $DestDir$Conf{InstallDir}/$dir\n");
    } else {
        print("Created $DestDir$Conf{InstallDir}/$dir\n");
    }
}

#
# Create CGI image directory
#
foreach my $dir ( ($Conf{CgiImageDir}) ) {
    next if ( $dir eq "" || -d "$DestDir$dir" );
    mkpath("$DestDir$dir", 0, 0775);
    if ( !-d "$DestDir$dir" || !chown($Uid, $Gid, "$DestDir$dir") ) {
        die("Failed to create or chown $DestDir$dir");
    } else {
        print("Created $DestDir$dir\n");
    }
}

#
# Create $TopDir's top-level directories
#
foreach my $dir ( qw(. conf pool cpool pc trash log) ) {
    mkpath("$DestDir$Conf{TopDir}/$dir", 0, 0750) if ( !-d "$DestDir$Conf{TopDir}/$dir" );
    if ( !-d "$DestDir$Conf{TopDir}/$dir"
            || !chown($Uid, $Gid, "$DestDir$Conf{TopDir}/$dir") ) {
        die("Failed to create or chown $DestDir$Conf{TopDir}/$dir\n");
    } else {
        print("Created $DestDir$Conf{TopDir}/$dir\n");
    }
}

printf("Installing binaries in $DestDir$Conf{InstallDir}/bin\n");
foreach my $prog ( qw(BackupPC BackupPC_dump BackupPC_link BackupPC_nightly
        BackupPC_sendEmail BackupPC_tarCreate BackupPC_trashClean
        BackupPC_tarExtract BackupPC_compressPool BackupPC_zcat
        BackupPC_archive BackupPC_archiveHost
        BackupPC_restore BackupPC_serverMesg BackupPC_zipCreate ) ) {
    InstallFile("bin/$prog", "$DestDir$Conf{InstallDir}/bin/$prog", 0555);
}

printf("Installing library in $DestDir$Conf{InstallDir}/lib\n");
foreach my $lib ( qw(
	BackupPC/Lib.pm
	BackupPC/FileZIO.pm
	BackupPC/Attrib.pm
        BackupPC/PoolWrite.pm
	BackupPC/View.pm
	BackupPC/Xfer/Archive.pm
	BackupPC/Xfer/Tar.pm
        BackupPC/Xfer/Smb.pm
	BackupPC/Xfer/Rsync.pm
	BackupPC/Xfer/RsyncDigest.pm
        BackupPC/Xfer/RsyncFileIO.pm
	BackupPC/Zip/FileMember.pm
        BackupPC/Lang/en.pm
	BackupPC/Lang/fr.pm
	BackupPC/Lang/es.pm
        BackupPC/Lang/de.pm
        BackupPC/Lang/it.pm
        BackupPC/Lang/nl.pm
        BackupPC/CGI/AdminOptions.pm
	BackupPC/CGI/Archive.pm
	BackupPC/CGI/ArchiveInfo.pm
	BackupPC/CGI/Browse.pm
	BackupPC/CGI/DirHistory.pm
	BackupPC/CGI/EmailSummary.pm
	BackupPC/CGI/GeneralInfo.pm
	BackupPC/CGI/HostInfo.pm
	BackupPC/CGI/Lib.pm
	BackupPC/CGI/LOGlist.pm
	BackupPC/CGI/Queue.pm
        BackupPC/CGI/ReloadServer.pm
	BackupPC/CGI/RestoreFile.pm
	BackupPC/CGI/RestoreInfo.pm
	BackupPC/CGI/Restore.pm
        BackupPC/CGI/StartServer.pm
	BackupPC/CGI/StartStopBackup.pm
        BackupPC/CGI/StopServer.pm
	BackupPC/CGI/Summary.pm
	BackupPC/CGI/View.pm
    ) ) {
    InstallFile("lib/$lib", "$DestDir$Conf{InstallDir}/lib/$lib", 0444);
}

if ( $Conf{CgiImageDir} ne "" ) {
    printf("Installing images in $DestDir$Conf{CgiImageDir}\n");
    foreach my $img ( <images/*> ) {
	(my $destImg = $img) =~ s{^images/}{};
	InstallFile($img, "$DestDir$Conf{CgiImageDir}/$destImg", 0444, 1);
    }

    #
    # Install new CSS file, making a backup copy if necessary
    #
    my $cssBackup = "$DestDir$Conf{CgiImageDir}/BackupPC_stnd.css.pre-__VERSION__";
    if ( -f "$DestDir$Conf{CgiImageDir}/BackupPC_stnd.css" && !-f $cssBackup ) {
	rename("$DestDir$Conf{CgiImageDir}/BackupPC_stnd.css", $cssBackup);
    }
    InstallFile("conf/BackupPC_stnd.css",
	        "$DestDir$Conf{CgiImageDir}/BackupPC_stnd.css", 0444, 0);
}

printf("Making init.d scripts\n");
foreach my $init ( qw(gentoo-backuppc gentoo-backuppc.conf linux-backuppc
		      solaris-backuppc debian-backuppc suse-backuppc) ) {
    InstallFile("init.d/src/$init", "init.d/$init", 0444);
}

printf("Installing docs in $DestDir$Conf{InstallDir}/doc\n");
foreach my $doc ( qw(BackupPC.pod BackupPC.html) ) {
    InstallFile("doc/$doc", "$DestDir$Conf{InstallDir}/doc/$doc", 0444);
}

printf("Installing config.pl and hosts in $DestDir$Conf{TopDir}/conf\n");
InstallFile("conf/hosts", "$DestDir$Conf{TopDir}/conf/hosts", 0644)
                    if ( !-f "$DestDir$Conf{TopDir}/conf/hosts" );

#
# Now do the config file.  If there is an existing config file we
# merge in the new config file, adding any new configuration
# parameters and deleting ones that are no longer needed.
#
my $dest = "$DestDir$Conf{TopDir}/conf/config.pl";
my ($newConf, $newVars) = ConfigParse("conf/config.pl");
my ($oldConf, $oldVars);
if ( -f $dest ) {
    ($oldConf, $oldVars) = ConfigParse($dest);
    $newConf = ConfigMerge($oldConf, $oldVars, $newConf, $newVars);
}
$Conf{EMailFromUserName}  ||= $Conf{BackupPCUser};
$Conf{EMailAdminUserName} ||= $Conf{BackupPCUser};

#
# Update various config parameters
#

#
# Guess $Conf{CgiURL}
#
if ( !defined($Conf{CgiURL}) ) {
    if ( $Conf{CgiDir} =~ m{cgi-bin(/.*)} ) {
	$Conf{CgiURL} = "'http://$Conf{ServerHost}/cgi-bin$1/BackupPC_Admin'";
    } else {
	$Conf{CgiURL} = "'http://$Conf{ServerHost}/cgi-bin/BackupPC_Admin'";
    }
}

#
# The smbclient commands have moved from hard-coded to the config file.
# $Conf{SmbClientArgs} no longer exists, so merge it into the new
# commands if it still exists.
#
if ( defined($Conf{SmbClientArgs}) ) {
    if ( $Conf{SmbClientArgs} ne "" ) {
        foreach my $param ( qw(SmbClientRestoreCmd SmbClientFullCmd
                                SmbClientIncrCmd) ) {
            $newConf->[$newVars->{$param}]{text}
                            =~ s/(-E\s+-N)/$1 $Conf{SmbClientArgs}/;
        }
    }
    delete($Conf{SmbClientArgs});
}

#
# CSS is now stored in a file rather than a big config variable.
#
delete($Conf{CSSstylesheet});

#
# The blackout timing settings are now stored in a list of hashes, rather
# than three scalar parameters.
#
if ( defined($Conf{BlackoutHourBegin}) ) {
    $Conf{BlackoutPeriods} = [
	 {
	     hourBegin => $Conf{BlackoutHourBegin},
	     hourEnd   => $Conf{BlackoutHourEnd},
	     weekDays  => $Conf{BlackoutWeekDays},
	 } 
    ];
    delete($Conf{BlackoutHourBegin});
    delete($Conf{BlackoutHourEnd});
    delete($Conf{BlackoutWeekDays});
}

#
# $Conf{RsyncLogLevel} has been replaced by $Conf{XferLogLevel}
#
if ( defined($Conf{RsyncLogLevel}) ) {
    $Conf{XferLogLevel} = $Conf{RsyncLogLevel};
    delete($Conf{RsyncLogLevel});
}

#
# In 2.1.0 the default for $Conf{CgiNavBarAdminAllHosts} is now 1
#
$Conf{CgiNavBarAdminAllHosts} = 1;

#
# IncrFill should now be off
#
$Conf{IncrFill} = 0;

#
# Figure out sensible arguments for the ping command
#
if ( defined($Conf{PingArgs}) ) {
    $Conf{PingCmd} = '$pingPath ' . $Conf{PingArgs};
} elsif ( !defined($Conf{PingCmd}) ) {
    if ( $^O eq "solaris" || $^O eq "sunos" ) {
	$Conf{PingCmd} = '$pingPath -s $host 56 1';
    } elsif ( ($^O eq "linux" || $^O eq "openbsd" || $^O eq "netbsd")
	    && !system("$Conf{PingPath} -c 1 -w 3 localhost") ) {
	$Conf{PingCmd} = '$pingPath -c 1 -w 3 $host';
    } else {
	$Conf{PingCmd} = '$pingPath -c 1 $host';
    }
    delete($Conf{PingArgs});
}

#
# Figure out sensible arguments for the df command
#
if ( !defined($Conf{DfCmd}) ) {
    if ( $^O eq "solaris" || $^O eq "sunos" ) {
	$Conf{DfCmd} = '$dfPath -k $topDir';
    }
}

#
# $Conf{SmbClientTimeout} is now $Conf{ClientTimeout}
#
if ( defined($Conf{SmbClientTimeout}) ) {
    $Conf{ClientTimeout} = $Conf{SmbClientTimeout};
    delete($Conf{SmbClientTimeout});
}

my $confCopy = "$dest.pre-__VERSION__";
if ( -f $dest && !-f $confCopy ) {
    #
    # Make copy of config file, preserving ownership and modes
    #
    printf("Making backup copy of $dest -> $confCopy\n");
    my @stat = stat($dest);
    my $mode = $stat[2];
    my $uid  = $stat[4];
    my $gid  = $stat[5];
    die("can't copy($dest, $confCopy)\n")  unless copy($dest, $confCopy);
    die("can't chown $uid, $gid $confCopy\n")
                                           unless chown($uid, $gid, $confCopy);
    die("can't chmod $mode $confCopy\n")   unless chmod($mode, $confCopy);
}
open(OUT, ">", $dest) || die("can't open $dest for writing\n");
binmode(OUT);
my $blockComment;
foreach my $var ( @$newConf ) {
    if ( length($blockComment)
          && substr($var->{text}, 0, length($blockComment)) eq $blockComment ) {
        $var->{text} = substr($var->{text}, length($blockComment));
        $blockComment = undef;
    }
    $blockComment = $1 if ( $var->{text} =~ /^([\s\n]*#{70}.*#{70}[\s\n]+)/s );
    $var->{text} =~ s/^\s*\$Conf\{(.*?)\}(\s*=\s*['"]?)(.*?)(['"]?\s*;)/
                defined($Conf{$1}) && ref($Conf{$1}) eq ""
                                   && $Conf{$1} ne $OrigConf{$1}
                                   ? "\$Conf{$1}$2$Conf{$1}$4"
                                   : "\$Conf{$1}$2$3$4"/emg;
    print OUT $var->{text};
}
close(OUT);
if ( !defined($oldConf) ) {
    die("can't chmod 0640 mode $dest\n")  unless chmod(0640, $dest);
    die("can't chown $Uid, $Gid $dest\n") unless chown($Uid, $Gid, $dest);
}

if ( $Conf{CgiDir} ne "" ) {
    printf("Installing cgi script BackupPC_Admin in $DestDir$Conf{CgiDir}\n");
    mkpath("$DestDir$Conf{CgiDir}", 0, 0755);
    InstallFile("cgi-bin/BackupPC_Admin", "$DestDir$Conf{CgiDir}/BackupPC_Admin",
                04554);
}

print <<EOF;

Ok, it looks like we are finished.  There are several more things you
will need to do:

  - Browse through the config file, $Conf{TopDir}/conf/config.pl,
    and make sure all the settings are correct.  In particular, you
    will need to set the smb share password and user name, backup
    policies and check the email message headers and bodies.

  - Edit the list of hosts to backup in $Conf{TopDir}/conf/hosts.

  - Read the documentation in $Conf{InstallDir}/doc/BackupPC.html.
    Please pay special attention to the security section.

  - Verify that the CGI script BackupPC_Admin runs correctly.  You might
    need to change the permissions or group ownership of BackupPC_Admin.

  - BackupPC should be ready to start.  Don't forget to run it
    as user $Conf{BackupPCUser}!  The installation also contains an
    init.d/backuppc script that can be copied to /etc/init.d
    so that BackupPC can auto-start on boot.  This will also enable
    administrative users to start the server from the CGI interface.
    See init.d/README.

Enjoy!
EOF

if ( `$Conf{PerlPath} -V` =~ /uselargefiles=undef/ ) {
    print <<EOF;

Warning: your perl, $Conf{PerlPath}, does not support large files.
This means BackupPC won't be able to backup files larger than 2GB.
To solve this problem you should build/install a new version of perl
with large file support enabled.  Use

    $Conf{PerlPath} -V | egrep uselargefiles

to check if perl has large file support (undef means no support).
EOF
}

eval "use File::RsyncP;";
if ( !$@ && $File::RsyncP::VERSION < 0.51 ) {
    print("\nWarning: you need to upgrade File::RsyncP;"
        . " I found $File::RsyncP::VERSION and BackupPC needs 0.51\n");
}

exit(0);

###########################################################################
# Subroutines
###########################################################################

sub InstallFile
{
    my($prog, $dest, $mode, $binary) = @_;
    my $first = 1;
    my($uid, $gid) = ($Uid, $Gid);

    if ( -f $dest ) {
        #
        # preserve ownership and modes of files that already exist
        #
        my @stat = stat($dest);
        $mode = $stat[2];
        $uid  = $stat[4];
        $gid  = $stat[5];
    }
    unlink($dest) if ( -f $dest );
    if ( $binary ) {
	die("can't copy($prog, $dest)\n") unless copy($prog, $dest);
    } else {
	open(PROG, $prog)     || die("can't open $prog for reading\n");
	open(OUT, ">", $dest) || die("can't open $dest for writing\n");
	binmode(PROG);
	binmode(OUT);
	while ( <PROG> ) {
	    s/__INSTALLDIR__/$Conf{InstallDir}/g;
	    s/__TOPDIR__/$Conf{TopDir}/g;
	    s/__BACKUPPCUSER__/$Conf{BackupPCUser}/g;
	    s/__CGIDIR__/$Conf{CgiDir}/g;
	    if ( $first && /^#.*bin\/perl/ ) {
		#
		# Fill in correct path to perl (no taint for >= 2.0.1).
		#
		print OUT "#!$Conf{PerlPath}\n";
	    } else {
		print OUT;
	    }
	    $first = 0;
	}
	close(PROG);
	close(OUT);
    }
    die("can't chown $uid, $gid $dest") unless chown($uid, $gid, $dest);
    die("can't chmod $mode $dest")      unless chmod($mode, $dest);
}

sub FindProgram
{
    my($path, $prog) = @_;

    if ( defined($opts{"bin-path"}{$prog}) ) {
        return $opts{"bin-path"}{$prog};
    }
    foreach my $dir ( split(/:/, $path) ) {
        my $file = File::Spec->catfile($dir, $prog);
        return $file if ( -x $file );
    }
    return;
}

sub ConfigParse
{
    my($file) = @_;
    open(C, $file) || die("can't open $file");
    binmode(C);
    my($out, @conf, $var);
    my $comment = 1;
    my $allVars = {};
    my $endLine = undef;
    while ( <C> ) {
        if ( /^#/ && !defined($endLine) ) {
            if ( $comment ) {
                $out .= $_;
            } else {
                if ( $out ne "" ) {
                    $allVars->{$var} = @conf if ( defined($var) );
                    push(@conf, {
                        text => $out,
                        var => $var,
                    });
                }
                $var = undef;
                $comment = 1;
                $out = $_;
            }
        } elsif ( /^\s*\$Conf\{([^}]*)/ ) {
            $comment = 0;
            if ( defined($var) ) {
                $allVars->{$var} = @conf if ( defined($var) );
                push(@conf, {
                    text => $out,
                    var => $var,
                });
                $out = $_;
            } else {
                $out .= $_;
            }
            $var = $1;
	    $endLine = $1 if ( /^\s*\$Conf\{[^}]*} *= *<<(.*);/ );
	    $endLine = $1 if ( /^\s*\$Conf\{[^}]*} *= *<<'(.*)';/ );
        } else {
	    $endLine = undef if ( defined($endLine) && /^\Q$endLine[\n\r]*$/ );
            $out .= $_;
        }
    }
    if ( $out ne "" ) {
        $allVars->{$var} = @conf if ( defined($var) );
        push(@conf, {
            text => $out,
            var  => $var,
        });
    }
    close(C);
    return (\@conf, $allVars);
}

sub ConfigMerge
{
    my($old, $oldVars, $new, $newVars) = @_;
    my $posn = 0;
    my $res;

    #
    # Find which config parameters are not needed any longer
    #
    foreach my $var ( @$old ) {
        next if ( !defined($var->{var}) || defined($newVars->{$var->{var}}) );
        #print(STDERR "Deleting old config parameter $var->{var}\n");
        $var->{delete} = 1;
    }
    #
    # Find which config parameters are new
    #
    foreach my $var ( @$new ) {
        next if ( !defined($var->{var}) );
        if ( defined($oldVars->{$var->{var}}) ) {
            $posn = $oldVars->{$var->{var}};
        } else {
            #print(STDERR "New config parameter $var->{var}: $var->{text}\n");
            push(@{$old->[$posn]{new}}, $var);
        }
    }
    #
    # Create merged config file
    #
    foreach my $var ( @$old ) {
        next if ( $var->{delete} );
        push(@$res, $var);
        foreach my $new ( @{$var->{new}} ) {
            push(@$res, $new);
        }
    }
    return $res;
}

sub prompt
{
    my($question, $default, $option) = @_;

    $default = $opts{$option} if ( defined($opts{$option}) );
    if ( $opts{batch} ) {
        print("$question [$default]\n");
        return $default;
    }
    print("$question [$default]? ");
    my $reply = <STDIN>;
    $reply =~ s/[\n\r]*//g;
    return $reply if ( $reply !~ /^$/ );
    return $default;
}

__END__

=head1 SYNOPSIS

configure.pl [options]

=head1 DESCRIPTION

configure.pl is a script that is used to install or upgrade a BackupPC
installation.  It is usually run interactively without arguments.  It
also supports a batch mode where all the options can be specified
via the command-line.

For upgrading BackupPC you need to make sure that BackupPC is not
running prior to running BackupPC.

Typically configure.pl needs to run as the super user (root).

=head1 OPTIONS

=over 8

=item B<--batch>

Run configure.pl in batch mode.  configure.pl will run without
prompting the user.  The other command-line options are used
to specify the settings that the user is usually prompted for.

=item B<--bin-path PROG=PATH>

Specify the path for various external programs that BackupPC
uses.  Several --bin-path options may be specified.  configure.pl
usually finds sensible defaults based on searching the PATH.
The format is:

    --bin-path PROG=PATH

where PROG is one of perl, tar, smbclient, nmblookup, rsync, ping,
df, ssh, sendmail, hostname, split, par2, cat, gzip, bzip2 and
PATH is that full path to that program.

Examples

    --bin-path cat=/bin/cat --bin-path bzip2=/home/user/bzip2

=item B<--config-path CONFIG_PATH>

Path to the existing config.pl configuration file for BackupPC.
This option should be specified for batch upgrades to an
existing installation.  The option should be omitted when
doing a batch new install.

=item B<--cgi-dir CGI_DIR>

Path to Apache's cgi-bin directory where the BackupPC_Admin
script will be installed.  This option only needs to be
specified for a batch new install.

=item B<--data-dir DATA_DIR>

Path to the BackupPC data directory.  This is where all the backup
data is stored, and it should be on a large file system. This option
only needs to be specified for a batch new install.

Example:

    --data-dir /data/BackupPC

=item B<--dest-dir DEST_DIR>

An optional prefix to apply to all installation directories.
Usually this is not needed, but certain auto-installers like
to stage an install in a temporary directory, and then copy
the files to their real destination.  This option can be used
to specify the temporary directory prefix.  Note that if you
specify this option, BackupPC won't run correctly if you try
to run it from below the --dest-dir directory, since all the
paths are set assuming BackupPC is installed in the intended
final locations.

=item B<--help|?>

Print a brief help message and exits.

=item B<--hostname HOSTNAME>

Host name (this machine's name) on which BackupPC is being installed.
This option only needs to be specified for a batch new install.

=item B<--html-dir HTML_DIR>

Path to an Apache html directory where various BackupPC image files
and the CSS files will be installed.  This is typically a directory
below Apache's DocumentRoot directory.  This option only needs to be
specified for a batch new install.

Example:

    --html-dir /usr/local/apache/htdocs/BackupPC

=item B<--html-dir-url URL>

The URL (without http://hostname) required to access the BackupPC html
directory specified with the --html-dir option.  This option only needs
to be specified for a batch new install.

Example:

    --html-dir-url /BackupPC

=item B<--install-dir INSTALL_DIR>

Installation directory for BackupPC scripts, libraries, and
documentation.  This option only needs to be specified for a
batch new install.

Example:

    --install-dir /usr/local/BackupPC

=item B<--man>

Prints the manual page and exits.

=item B<--uid-ignore>

configure.pl verifies that the script is being run as the super user
(root).  Without the --uid-ignore option, in batch mode the script will
exit with an error if not run as the super user, and in interactive mode
the user will be prompted.  Specifying this option will cause the script
to continue even if the user id is not root.

=head1 EXAMPLES

For a standard interactive install, run without arguments:

    configure.pl

For a batch new install you need to specify answers to all the
questions that are normally prompted:

    configure.pl                                   \
        --batch                                    \
        --cgi-dir /var/www/cgi-bin/BackupPC        \
        --data-dir /data/BackupPC                  \
        --hostname myHost                          \
        --html-dir /var/www/html/BackupPC          \
        --html-dir-url /BackupPC                   \
        --install-dir /usr/local/BackupPC

For a batch upgrade, you only need to specify the path to the
configuration file:
        
    configure.pl --batch --config-path /data/BackupPC/conf/config.pl

=head1 AUTHOR

Craig Barratt <cbarratt@users.sourceforge.net>

=head1 COPYRIGHT

Copyright (C) 2001-2004  Craig Barratt.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut
