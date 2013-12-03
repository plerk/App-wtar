use strict;
use warnings;
use Test::More tests => 19;
use App::wtar::Constant;
use App::wtar::Options;

my $opt;

$opt = App::wtar::Options->new("tvf", "foo.tar");
isa_ok $opt, 'App::wtar::Options';
is $opt->mode, MODE_LIST, 'opt.mode == MODE_LIST';
is $opt->verbose, 1, 'opt.mode == 1';
isa_ok $opt->uri, 'URI', 'opt.uri isa URI';
note "uri = " . $opt->uri;

$opt = App::wtar::Options->new("xf", "/tmp/foo.tar");
isa_ok $opt, 'App::wtar::Options';
is $opt->mode, MODE_EXTRACT, 'opt.mode == MODE_EXTRACT';
is $opt->verbose, 0, 'opt.verbose == 0';
isa_ok $opt->uri, 'URI', 'opt.uri isa URI';
note "uri = " . $opt->uri;

$opt = App::wtar::Options->new(qw( --get --verbose ));
isa_ok $opt, 'App::wtar::Options';
is $opt->mode, MODE_EXTRACT, 'opt.mode == MODE_EXTRACT';
is $opt->verbose, 1, 'opt.verbose = 1';
isa_ok $opt->uri, 'URI', 'opt.uri isa URI';
note "uri = " . $opt->uri;

$opt = App::wtar::Options->new(qw( --list --file=ftp://foo.bar.baz/path1/path2 ));
isa_ok $opt, 'App::wtar::Options';
is $opt->mode, MODE_LIST, 'opt.mode == MODE_LIST';
is $opt->verbose, 0, 'opt.verbose = 0';
isa_ok $opt->uri, 'URI', 'opt.uri isa URI';
note "uri = " . $opt->uri;

is $opt->uri->scheme, 'ftp', 'opt.uri.scheme = ftp';
is $opt->uri->host, 'foo.bar.baz', 'opt.uri.host = foo.bar.baz';
is $opt->uri->path, '/path1/path2', 'opt.uri.path = /path1/path2';
