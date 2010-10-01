use Test::More;

use POE;
use MooseX::Declare;

my $port = int(rand(10000)) + 50000;

class Foo {
    use MooseX::Types::Moose(':all');
    use POEx::Types(':all');
    use IO::Socket::INET;
    use aliased 'POEx::Role::Event';

    has sock => ( is => 'rw', isa => Object, clearer => 'clear_sock' );

    method handle_inbound_data($data, WheelID $id) is Event {
        $self->yield('shutdown');
        $self->clear_sock;

        Test::More::pass("Got inbound data: $data");
    }
    
    with 'POEx::Role::TCPServer';
    
    after _start(@args) is Event {
        $self->post($self, 'client');
    }

    method client() is Event {
        my $sock = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => $port, Proto => 'tcp');
        $self->sock($sock);
        $sock->print("TEST\n");
    }
}

Foo->new
(
    listen_ip   => '127.0.0.1',
    listen_port => $port,
    alias       => 'foo', 
    options     => { trace => 1, debug => 1 }
);

POE::Kernel->run();

done_testing();
0;
