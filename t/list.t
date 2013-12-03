use strict;
use warnings;
use Test::More tests => 2;
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

my $out = capture_stdout { $r = App::wtar->main('tf', $archive_filename->stringify) };
is $r, 0, "wtar xf $archive_filename";

note $out;

is $out, "foo/foo.txt\nfoo/bar.txt\nfoo/baz.txt\n";

chdir(File::Spec->rootdir);
