package POEx::Role::TCPServer::Types;
use warnings;
use strict;

use MooseX::Types -declare => [qw/ WheelID /];
use MooseX::Types::Moose('Int');

subtype WheelID,
    as Int,
    where { $_ > 0 },
    message { 'Something is horrible wrong with this wheel id' };

1;
