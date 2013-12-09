package App::wtar::Options;

use strict;
use warnings;
use v5.10;
use Moo;
use warnings NONFATAL => 'all';
use App::wtar::Constant;
use URI;
use URI::file;
use Path::Class ();

# ABSTRACT: Option parser for wtar
# VERSION

sub _file_to_uri
{
  my($class, $fn) = @_;
  if($fn =~ m{^(ftp|http|gopher|file)://})
  { return URI->new($fn) }
  else
  {
    if(-d Path::Class::Dir->new($fn))
    {
      die "cannot use directory as a tar filename" # TODO
    }
    my $file = Path::Class::File->new($fn);
    if($file->is_absolute)
    {
      return URI::file->new($file->stringify);
    }
    else
    {
      return URI::file->new($file->absolute->stringify);
    }
  }
}

sub BUILDARGS
{
  my($class, @args) = @_;
  die "must specify at least -x or -t" unless @args > 0; # TODO
  $args[0] = "-$args[0]" unless $args[0] =~ /^-/;

  local $URI::file::DEFAULT_AUTHORITY = 'localhost';

  my $args = {};

  while(@args > 0)
  {
    my $arg = shift @args;
    if($arg =~ /^--(extract|get)$/)
    { $args->{mode} = MODE_EXTRACT }
    elsif($arg =~ /^--list$/)
    { $args->{mode} = MODE_LIST }
    elsif($arg =~ /^--file=(.*)$/)
    { $args->{uri} = $class->_file_to_uri($1) }
    elsif($arg =~ /^--file$/)
    { $args->{uri} = $class->_file_to_uri(shift @args) }
    elsif($arg =~ /^--verbose$/)
    { $args->{verbose} = 1 }
    elsif($arg =~ /^--/)
    {
      die "unknown option $arg"; # TODO
    }
    elsif($arg =~ /^-(.*)$/)
    {
      foreach my $opt (split //, $1)
      {
        if($opt eq 'x')
        { $args->{mode} = MODE_EXTRACT }
        elsif($opt eq 't')
        { $args->{mode} = MODE_LIST }
        elsif($opt eq 'f')
        { $args->{uri} = $class->_file_to_uri(shift @args) }
        elsif($opt eq 'v')
        { $args->{verbose} = 1 }
        else
        {
          die "unknown option -$arg"; # TODO
        }
      }
    }
    else
    {
      push @{ $args->{files} }, $arg;
    }
  }
  
  $args;
}

has mode => ( # -x, -t
  is       => 'ro',
  required => 1,
  isa      => sub {
    die "not a mode" unless $_[0] == MODE_LIST 
                     ||     $_[0] == MODE_EXTRACT
  },
);

has uri => ( # -f
  is      => 'ro',
  default => sub { 
    local $URI::file::DEFAULT_AUTHORITY = 'localhost';
    URI::file->new('/dev/st0') 
  } 
);

has verbose => ( is => 'ro', default => 0 ); # -v
has files   => ( is => 'ro', default => sub { [] } );

1;

