#============================================================= -*-perl-*-
#
# BackupPC::Storage package
#
# DESCRIPTION
#
#   This library defines a BackupPC::Storage class for reading/writing
#   data like config, host info, backup and restore info.
#
# AUTHOR
#   Craig Barratt  <cbarratt@users.sourceforge.net>
#
# COPYRIGHT
#   Copyright (C) 2004  Craig Barratt
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

package BackupPC::Storage;

use strict;
use BackupPC::Storage::Text;

sub new
{
    my $class = shift;
    my($paths) = @_;
    my $flds = {
        BackupFields => [qw(
                    num type startTime endTime
                    nFiles size nFilesExist sizeExist nFilesNew sizeNew
                    xferErrs xferBadFile xferBadShare tarErrs
                    compress sizeExistComp sizeNewComp
                    noFill fillFromNum mangle xferMethod level
                )],
        RestoreFields => [qw(
                    num startTime endTime result errorMsg nFiles size
                    tarCreateErrs xferErrs
                )],
        ArchiveFields => [qw(
                    num startTime endTime result errorMsg
                )],
    };

    return BackupPC::Storage::Text->new($flds, $paths, @_);
}

1;
