package App::wtar;

use strict;
use warnings;
use v5.10;
use EV;
use Net::Curl::Multi;
use Net::Curl::Multi::EV;
use Net::Curl::Easy qw( :constants );
use AnyEvent;
use Archive::Libarchive::Any qw( :all );
use App::wtar::Constant;
use App::wtar::Options;

# ABSTRACT: Non-blocking combination of wget and tar
# VERSION

=head1 DESCRIPTION

This module contains the machinery for L<wtar>.

=head1 METHODS

=head2 main

The main class method for this package allows you to run wtar
without forking.  It returns a status value which should be 
zero (0) on success.

 App::wtar->main('tvf', 'http://example.com/foo.tar.gz');

is the same as

 % wtar tvf http://example.com/foo.tar.gz

=head1 SEE ALSO

L<wtar>

=cut

sub main
{
  my $class = shift;
  my $opt = App::wtar::Options->new(@_);
  my $r;
  
  if($opt->mode == MODE_EXTRACT || $opt->mode == MODE_LIST)
  {
    my $archive = archive_read_new();
    archive_read_support_filter_all($archive);
    archive_read_support_format_all($archive);
    
    my $disk;
    if($opt->mode == MODE_EXTRACT)
    {
      $disk = archive_write_disk_new();
      archive_write_disk_set_options($disk,
        ARCHIVE_EXTRACT_TIME |
        ARCHIVE_EXTRACT_PERM |
        ARCHIVE_EXTRACT_ACL  |
        ARCHIVE_EXTRACT_FFLAGS,
      );
      archive_write_disk_set_standard_lookup($disk);
    }
  
    if($opt->uri->scheme eq 'file')
    {
      my $filename = $opt->uri->file;
      $r = archive_read_open_filename($archive, $filename, 10240);
      die "error opening file $filename: " . archive_error_string($archive) if $r != ARCHIVE_OK; # TODO
    }
    elsif($opt->uri->scheme =~ /^(https?|ftp)$/)
    {
      my $data = { opt => $opt };
      archive_read_open($archive, $data, \&_myopen, \&_myread, \&_myclose);
    }
    
    while(1)
    {
      $r = archive_read_next_header($archive, my $entry);
      last if $r == ARCHIVE_EOF;
      print STDERR archive_error_string($archive), "\n" unless $r == ARCHIVE_OK;
      return 2 if $r < ARCHIVE_WARN;

      if($opt->mode == MODE_EXTRACT)
      {
        print $class->_verbose($entry), "\n" if $opt->verbose;

        $r = archive_write_header($disk, $entry);
        print STDERR archive_error_string($archive), "\n" unless $r == ARCHIVE_OK;
        return 2 if $r < ARCHIVE_WARN;

        while(1)
        {
          $r = archive_read_data_block($archive, my $buffer, my $offset);
          last if $r == ARCHIVE_EOF;
          print STDERR archive_error_string($archive), "\n" unless $r == ARCHIVE_OK;
          return 2 if $r < ARCHIVE_WARN;
          
          $r = archive_write_data_block($disk, $buffer, $offset);
          print STDERR archive_error_string($disk), "\n" unless $r == ARCHIVE_OK;
          return 2 if $r < ARCHIVE_WARN;
        }
      }
      else # MODE_LIST
      {
        if($opt->verbose)
        {
          print $class->_verbose($entry), "\n";
        }
        else
        {
          print archive_entry_pathname($entry), "\n";
        }
      }
    }
    
    $r = archive_read_close($archive);
    die "error closing archive: " . archive_error_string($archive) if $r != ARCHIVE_OK; # TODO
    archive_read_free($archive); 
    
    if($disk)
    {
      archive_write_close($disk); 
      archive_write_free($disk);
    }
  }
  
  return 0;
}

sub _verbose
{
  my($class, $entry) = @_;

  # TODO: also print out the time/date

  sprintf "%s%s %s %5d %s",
    archive_entry_strmode($entry),
    archive_entry_uname($entry)//archive_entry_uid($entry)//'unknown',
    archive_entry_gname($entry)//archive_entry_gid($entry)//'unknown',
    archive_entry_size($entry),
    archive_entry_pathname($entry);
}

sub _myopen
{
  my($archive, $data) = @_;
  
  $data->{buffer} = [];
  $data->{cv1}    = AE::cv;
  $data->{eof}    = 0;
  
  my $total = 0;
  
  my $curl = $data->{curl} = Net::Curl::Easy->new;
  $curl->setopt( CURLOPT_URL, $data->{opt}->uri->as_string );
  $curl->setopt( CURLOPT_WRITEDATA, $data );
  $curl->setopt( CURLOPT_WRITEFUNCTION, sub {
    my($curl, $buffer, $data) = @_;
    push @{ $data->{buffer} }, $buffer;
    $data->{cv1}->send;
    length $buffer;
  });
  
  my $multi = Net::Curl::Multi->new;
  my $curl_ev = Net::Curl::Multi::EV::curl_ev($multi);
  
  $curl_ev->($curl, sub { $data->{eof} = 1 }, 4*60);
  
  ARCHIVE_OK;
}

sub _myread
{
  my($archive, $data) = @_;
  while(1)
  {
    if(@{ $data->{buffer} } > 0)
    {
      return (ARCHIVE_OK, shift @{ $data->{buffer} });
    }
    elsif($data->{eof})
    {
      return (ARCHIVE_OK, '');
    }
    else
    {
      $data->{cv1}->recv;
      $data->{cv1} = AE::cv;
    }
  }
}

sub _myclose
{
  my($archive, $data) = @_;
  ARCHIVE_OK;
}

1;

