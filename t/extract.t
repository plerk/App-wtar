use strict;
use warnings;
use Test::More tests => 5;
use App::wtar;
use File::Temp qw( tempdir );
use Path::Class qw ( file );
use File::Spec;
use Capture::Tiny qw( capture_stdout );

my $r;

my $archive_filename = file(__FILE__)->parent->file('foo.tar')->absolute;

note "filename = $archive_filename";

my $dir = tempdir( CLEANUP => 1 );

note "dir = $dir";

chdir $dir;

my $out = capture_stdout { $r = App::wtar->main('xf', $archive_filename->stringify) };
is $r, 0, "wtar xf $archive_filename";

note $out if $out ne '';

is $out, "";

foreach my $fn (qw( foo bar baz ))
{
  ok -e "foo/$fn.txt", "foo/fn.txt";
}

chdir(File::Spec->rootdir);
