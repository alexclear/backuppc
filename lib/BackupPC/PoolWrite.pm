#============================================================= -*-perl-*-
#
# BackupPC::PoolWrite package
#
# DESCRIPTION
#
#   This library defines a BackupPC::PoolWrite class for writing
#   files to disk that are candidates for pooling.  One instance
#   of this class is used to write each file.  The following steps
#   are executed:
#
#     - As the incoming data arrives, the first 1MB is buffered
#       in memory so the MD5 digest can be computed.
#
#     - A running comparison against all the candidate pool files
#       (ie: those with the same MD5 digest, usually at most a single
#       file) is done as new incoming data arrives.  Up to $MaxFiles
#       simultaneous files can be compared in parallel.  This
#       involves reading and uncompressing one or more pool files.
#
#     - When a pool file no longer matches it is discarded from
#       the search.  If there are more than $MaxFiles candidates, one of
#       the new candidates is added to the search, first checking
#       that it matches up to the current point (this requires
#       re-reading one of the other pool files).
#
#     - When or if no pool files match then the new file is written
#       to disk.  This could occur many MB into the file.  We don't
#       need to buffer all this data in memory since we can copy it
#       from the last matching pool file, up to the point where it
#       fully matched.
#
#     - When all the new data is complete, if a pool file exactly
#       matches then the file is simply created as a hardlink to
#       the pool file.
#
# AUTHOR
#   Craig Barratt  <cbarratt@users.sourceforge.net>
#
# COPYRIGHT
#   Copyright (C) 2001  Craig Barratt
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
# Version 1.5.0, released 2 Aug 2002.
#
# See http://backuppc.sourceforge.net.
#
#========================================================================

package BackupPC::PoolWrite;

use strict;

use File::Path;
use Digest::MD5;
use BackupPC::FileZIO;

sub new
{
    my($class, $bpc, $fileName, $fileSize, $compress) = @_;

    my $self = bless {
        fileName => $fileName,
        fileSize => $fileSize,
        bpc      => $bpc,
        compress => $compress,
        nWrite   => 0,
        digest   => undef,
        files    => [],
        fileCnt  => -1,
        fhOut    => undef,
        errors   => [],
        data     => "",
        eof      => undef,
    }, $class;

    #
    # Always unlink any current file in case it is already linked
    #
    unlink($fileName) if ( -f $fileName );
    return $self;
}

my $BufSize  = 1048576;     # 1MB or 2^20
my $MaxFiles = 20;

sub write
{
    my($a, $dataRef) = @_;

    return if ( $a->{eof} );
    $a->{data} .= $$dataRef if ( defined($dataRef) );
    return if ( length($a->{data}) < $BufSize && defined($dataRef) );
    if ( !defined($a->{digest}) && $a->{fileSize} > 0 ) {
        #
        # build a list of all the candidate matching files
        #
        my $md5 = Digest::MD5->new;
        $a->{digest} = $a->{bpc}->Buffer2MD5($md5, $a->{fileSize}, \$a->{data});
        if ( !defined($a->{base} = $a->{bpc}->MD52Path($a->{digest},
                                                       $a->{compress})) ) {
            push(@{$a->{errors}}, "Unable to get path from '$a->{digest}'"
                                . " for $a->{fileName}\n");
        } else {
            while ( @{$a->{files}} < $MaxFiles ) {
                my $fh;
                my $fileName = $a->{fileCnt} < 0 ? $a->{base}
                                        : "$a->{base}_$a->{fileCnt}";
                last if ( !-f $fileName );
                if ( !defined($fh = BackupPC::FileZIO->open($fileName, 0,
                                                     $a->{compress})) ) {
                    $a->{fileCnt}++;
                    next;
                }
                push(@{$a->{files}}, {
                        name => $fileName,
                        fh   => $fh,
                     });
                $a->{fileCnt}++;
            }
        }
        #
        # if there are no candidate files then we must write
        # the new file to disk
        #
        if ( !@{$a->{files}} ) {
            $a->{fhOut} = BackupPC::FileZIO->open($a->{fileName},
                                              1, $a->{compress});
            if ( !defined($a->{fhOut}) ) {
                push(@{$a->{errors}}, "Unable to open $a->{fileName}"
                                    . " for writing\n");
            }
        }
    }
    my $dataLen = length($a->{data});
    if ( !defined($a->{fhOut}) && $a->{fileSize} > 0 ) {
        #
        # See if the new chunk of data continues to match the
        # candidate files.
        #
        for ( my $i = 0 ; $i < @{$a->{files}} ; $i++ ) {
            my($d, $match);
            my $fileName = $a->{fileCnt} < 0 ? $a->{base}
                                             : "$a->{base}_$a->{fileCnt}";
            if ( $dataLen > 0 ) {
                # verify next $dataLen bytes from candidate file
                my $n = $a->{files}[$i]->{fh}->read(\$d, $dataLen);
                next if ( $n == $dataLen && $d eq $a->{data} );
            } else {
                # verify candidate file is at EOF
                my $n = $a->{files}[$i]->{fh}->read(\$d, 100);
                next if ( $n == 0 );
            }
            #print("   File $a->{files}[$i]->{name} doesn't match\n");
            #
            # this candidate file didn't match.  Replace it
            # with a new candidate file.  We have to qualify
            # any new candidate file by making sure that its
            # first $a->{nWrite} bytes match, plus the next $dataLen
            # bytes match $a->{data}.
            #
            while ( -f $fileName ) {
                my $fh;
                if ( !defined($fh = BackupPC::FileZIO->open($fileName, 0,
                                                     $a->{compress})) ) {
                    $a->{fileCnt}++;
                    #print("   Discarding $fileName (open failed)\n");
                    $fileName = "$a->{base}_$a->{fileCnt}";
                    next;
                }
                if ( !$a->{files}[$i]->{fh}->rewind() ) {
                    push(@{$a->{errors}},
                            "Unable to rewind $a->{files}[$i]->{name}"
                          . " for compare\n");
                }
                $match = $a->filePartialCompare($a->{files}[$i]->{fh}, $fh,
                                          $a->{nWrite}, $dataLen, \$a->{data});
                if ( $match ) {
                    $a->{files}[$i]->{fh}->close();
                    $a->{files}[$i]->{fh} = $fh,
                    $a->{files}[$i]->{name} = $fileName;
                    #print("   Found new candidate $fileName\n");
                    $a->{fileCnt}++;
                    last;
                } else {
                    #print("   Discarding $fileName (no match)\n");
                }
                $fh->close();
                $a->{fileCnt}++;
                $fileName = "$a->{base}_$a->{fileCnt}";
            }
            if ( !$match ) {
                #
                # We couldn't find another candidate file
                #
                if ( @{$a->{files}} == 1 ) {
                    #print("   Exhausted matches, now writing\n");
                    $a->{fhOut} = BackupPC::FileZIO->open($a->{fileName},
                                                    1, $a->{compress});
                    if ( !defined($a->{fhOut}) ) {
                        push(@{$a->{errors}},
                                "Unable to open $a->{fileName}"
                              . " for writing\n");
                    } else {
                        if ( !$a->{files}[$i]->{fh}->rewind() ) {
                            push(@{$a->{errors}}, 
                                     "Unable to rewind"
                                   . " $a->{files}[$i]->{name} for copy\n");
                        }
                        $a->filePartialCopy($a->{files}[$i]->{fh}, $a->{fhOut},
                                        $a->{nWrite});
                    }
                }
                $a->{files}[$i]->{fh}->close();
                splice(@{$a->{files}}, $i, 1);
                $i--;
            }
        }
    }
    if ( defined($a->{fhOut}) && $dataLen > 0 ) {
        #
        # if we are in writing mode then just write the data
        #
        my $n = $a->{fhOut}->write(\$a->{data});
        if ( $n != $dataLen ) {
            push(@{$a->{errors}}, "Unable to write $dataLen bytes to"
                                . " $a->{fileName} (got $n)\n");
        }
    }
    $a->{nWrite} += $dataLen;
    $a->{data} = "";
    return if ( defined($dataRef) );

    #
    # We are at EOF, so finish up
    #
    $a->{eof} = 1;
    foreach my $f ( @{$a->{files}} ) {
        $f->{fh}->close();
    }
    if ( $a->{fileSize} == 0 ) {
        #
        # Simply create an empty file
        #
        local(*OUT);
        if ( !open(OUT, ">$a->{fileName}") ) {
            push(@{$a->{errors}}, "Can't open $a->{fileName} for empty"
                                . " output\n");
        } else {
            close(OUT);
        }
        return (1, $a->{digest}, -s $a->{fileName}, $a->{errors});
    } elsif ( defined($a->{fhOut}) ) {
        $a->{fhOut}->close();
        return (0, $a->{digest}, -s $a->{fileName}, $a->{errors});
    } else {
        if ( @{$a->{files}} == 0 ) {
            push(@{$a->{errors}}, "Botch, no matches on $a->{fileName}"
                                . " ($a->{digest})\n");
        } elsif ( @{$a->{files}} > 1 ) {
            my $str = "Unexpected multiple matches on"
                   . " $a->{fileName} ($a->{digest})\n";
            for ( my $i = 0 ; $i < @{$a->{files}} ; $i++ ) {
                $str .= "     -> $a->{files}[$i]->{name}\n";
            }
            push(@{$a->{errors}}, $str);
        }
        #print("   Linking $a->{fileName} to $a->{files}[0]->{name}\n");
        if ( @{$a->{files}} && !link($a->{files}[0]->{name}, $a->{fileName}) ) {
            push(@{$a->{errors}}, "Can't link $a->{fileName} to"
                                . " $a->{files}[0]->{name}\n");
        }
        return (1, $a->{digest}, -s $a->{fileName}, $a->{errors});
    }
}

#
# Finish writing: pass undef dataRef to write so it can do all
# the work.  Returns a 4 element array:
#
#   (existingFlag, digestString, outputFileLength, errorList)
#
sub close
{
    my($a) = @_;

    return $a->write(undef);
}

#
# Copy $nBytes from files $fhIn to $fhOut.
#
sub filePartialCopy
{
    my($a, $fhIn, $fhOut, $nBytes) = @_;
    my($nRead);

    while ( $nRead < $nBytes ) {
        my $thisRead = $nBytes - $nRead < $BufSize
                            ? $nBytes - $nRead : $BufSize;
        my $data;
        my $n = $fhIn->read(\$data, $thisRead);
        if ( $n != $thisRead ) {
            push(@{$a->{errors}},
                        "Unable to read $thisRead bytes from "
                       . $fhIn->name . " (got $n)\n");
            return;
        }
        $n = $fhOut->write(\$data, $thisRead);
        if ( $n != $thisRead ) {
            push(@{$a->{errors}},
                        "Unable to write $thisRead bytes to "
                       . $fhOut->name . " (got $n)\n");
            return;
        }
        $nRead += $thisRead;
    }
}

#
# Compare $nBytes from files $fh0 and $fh1, and also compare additional
# $extra bytes from $fh1 to $$extraData.
#
sub filePartialCompare
{
    my($a, $fh0, $fh1, $nBytes, $extra, $extraData) = @_;
    my($nRead, $n);
    my($data0, $data1);

    while ( $nRead < $nBytes ) {
        my $thisRead = $nBytes - $nRead < $BufSize
                            ? $nBytes - $nRead : $BufSize;
        $n = $fh0->read(\$data0, $thisRead);
        if ( $n != $thisRead ) {
            push(@{$a->{errors}}, "Unable to read $thisRead bytes from "
                                 . $fh0->name . " (got $n)\n");
            return;
        }
        $n = $fh1->read(\$data1, $thisRead);
        return 0 if ( $n < $thisRead || $data0 ne $data1 );
        $nRead += $thisRead;
    }
    if ( $extra > 0 ) {
        # verify additional bytes
        $n = $fh1->read(\$data1, $extra);
        return 0 if ( $n != $extra || $data1 ne $$extraData );
    } else {
        # verify EOF
        $n = $fh1->read(\$data1, 100);
        return 0 if ( $n != 0 );
    }
    return 1;
}

1;