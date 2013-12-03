package
  App::wtar::Constant;

use strict;
use warnings;
use constant MODE_EXTRACT => 1;
use constant MODE_LIST    => 2;
use Exporter::Tidy
  default => [ qw( MODE_EXTRACT MODE_LIST ) ]
;

1;
