use 5.010;
use Test::More('tests', 1);

use MooseX::Declare;
use POE;

class Foo with POEx::Role::TCPServer
{
    use MooseX::Types::Moose(':all');
    use POEx::Types(':all');
    use IO::Socket::INET;
    use aliased 'POEx::Role::Event';

    has sock => ( is => 'rw', isa => Object, clearer => 'clear_sock' );

    method handle_inbound_data($data, WheelID $id) is Event
    {
        $self->clear_wheels;
        $self->clear_socket_factory;
        $self->clear_sock;

        Test::More::pass("Got inbound data: $data");
    }

    after _start(@args) is Event
    {
        $self->post($self, 'client');
    }

    method client() is Event
    {
        my $sock = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => '54444', Proto => 'tcp');
        $self->sock($sock);
        $sock->print("TEST\n");
    }
}

Foo->new
(
    listen_ip   => '127.0.0.1',
    listen_port => '54444',
    alias       => 'foo', 
    options     => { trace => 1, debug => 1}
);

POE::Kernel->run();

