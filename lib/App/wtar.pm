package App::wtar;

use strict;
use warnings;
use v5.10;
use Archive::Libarchive::Any qw( :all );
use File::Strmode qw( strmode );
use App::wtar::Constant;
use App::wtar::Options;

# ABSTRACT: Non-blocking combination of wget and tar
# VERSION

=head1 DESCRIPTION

This module contains the machinery for L<wtar>.

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
    elsif($opt->uri->scheme =~ /^https?$/)
    {
      die 'FIXME';
    }
    elsif($opt->uri->scheme eq 'ftp')
    {
      die 'FIXME';
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
    strmode(archive_entry_mode($entry)),
    archive_entry_uname($entry),
    archive_entry_gname($entry),
    archive_entry_size($entry),
    archive_entry_pathname($entry);
}

1;

