package POEx::Role::TCPServer;

#ABSTRACT: A Moose Role that provides TCPServer behavior

use MooseX::Declare;

role POEx::Role::TCPServer {
    with 'POEx::Role::SessionInstantiation';
    use POEx::Types(':all');
    use MooseX::Types::Structured('Dict', 'Tuple', 'Optional');
    use MooseX::Types::Moose(':all');
    use POE::Wheel::ReadWrite;
    use POE::Wheel::SocketFactory;
    use POE::Filter::Line;
    
    use aliased 'POEx::Role::Event';

=head1 REQUIRES

=head2 METHODS

=head3 handle_inbound_data

    ($data, WheelID $id) is Event

This required method will be passed the data received, and from which wheel 
it came. 

=cut

    requires 'handle_inbound_data';

=attribute_protected socket_factory

    is: rw, isa: Object, predicate: has_socket_factory, clearer: clear_socket_factory

The POE::Wheel::SocketFactory created in _start is stored here.

=cut

    has socket_factory =>
    (
        is          => 'rw',
        isa         => Object,
        predicate   => 'has_socket_factory',
        clearer     => 'clear_socket_factory',
    );

=attribute_protected wheels

    traits: Hash, is: rw, isa: HashRef, clearer: clear_wheels

When connections are accepted, a POE::Wheel::ReadWrite object is created and 
stored in this attribute, keyed by WheelID. Wheels may be accessed via the
following provided methods.

    {
        'get_wheel'     => 'get',
        'set_wheel'     => 'set',
        'delete_wheel'  => 'delete',
        'count_wheels'  => 'count',
        'has_wheel'     => 'exists',
    }
=cut

    has wheels =>
    (
        is          => 'rw',
        isa         => HashRef,
        traits      => ['Hash'],
        lazy        => 1,
        default     => sub { {} },
        clearer     => 'clear_wheels',
        handles    =>
        {
            'get_wheel'     => 'get',
            'set_wheel'     => 'set',
            'delete_wheel'  => 'delete',
            'count_wheels'  => 'count',
            'has_wheel'     => 'exists',
        }
    );

=attribute_protected filter

    is: rw, isa: Filter

This stores the filter that is used when constructing wheels. It will be cloned
for each connection accepted. Defaults to a instance of POE::Filter::Line.

=cut

    has filter =>
    (
        is          => 'rw',
        isa         => Filter,
        default     => sub { POE::Filter::Line->new() }
    );


=attribute_protected input_filter

    is: rw, isa: Filter

If different filters are needed for input and output, supply this attribute with the input filter. It will override what is in L</filter>

=cut

    has input_filter =>
    (
        is          => 'rw',
        isa         => Filter,
        predicate   => 'has_input_filter',
    );

=attribute_protected output_filter

    is: rw, isa: Filter

If different filters are needed for input and output, supply this attribute with the output filter. It will override what is in L</filter>

=cut

    has output_filter =>
    (
        is          => 'rw',
        isa         => Filter,
        predicate   => 'has_output_filter'
    );

=attribute_public listen_ip

    is: ro, isa: Str, required

This will be used as the BindAddress to SocketFactory

=cut

    has listen_ip => 
    (
        is          => 'ro',
        isa         => Str,
        required    => 1,
    );
    
=attribute_public listen_port

    is: ro, isa: Int, required

This will be used as the BindPort to SocketFactory

=cut

    has listen_port => 
    (
        is          => 'ro',
        isa         => Int,
        required    => 1,
    );

=method_private after _start

    (@args) is Event

The _start event is after-advised to do the start up of the SocketFactory.

=cut

    after _start(@args) is Event {
        my $factory = POE::Wheel::SocketFactory->new
        (
            BindAddress     => $self->listen_ip,
            BindPort        => $self->listen_port,
            Reuse           => 1,
            SuccessEvent    => 'handle_on_connect',
            FailureEvent    => 'handle_listen_error',
        );
        $self->socket_factory($factory);
    }

=method_protected handle_on_connect

    (GlobRef $socket, Str $address, Int $port, WheelID $id) is Event

handle_on_connect is the SuccessEvent of the SocketFactory instantiated in _start. 

=cut

    method handle_on_connect (GlobRef $socket, Str $address, Int $port, WheelID $id) is Event {
        
        my $wheel = POE::Wheel::ReadWrite->new
        (
            Handle          => $socket,
            InputFilter     => $self->has_input_filter ? $self->input_filter->clone() : $self->filter->clone(),
            OutputFilter    => $self->has_output_filter ? $self->output_filter->clone() : $self->filter->clone(),
            InputEvent      => 'handle_inbound_data',
            ErrorEvent      => 'handle_socket_error',
            FlushedEvent    => 'handle_on_flushed',
        );
        
        $self->set_wheel($wheel->ID, $wheel);
    }

=method_protected handle_listen_error

    (Str $action, Int $code, Str $message, WheelID $id) is Event

handle_listen_error is the FailureEvent of the SocketFactory

=cut

    method handle_listen_error(Str $action, Int $code, Str $message, WheelID $id) is Event {
        warn "Received listen error: Action $action, Code $code, Message $message"
            if $self->options->{'debug'};
    }

=method_protected handle_socket_error

    (Str $action, Int $code, Str $message, WheelID $id) is Event

handle_socket_error is the ErrorEvent of each POE::Wheel::ReadWrite instantiated.

=cut

    method handle_socket_error(Str $action, Int $code, Str $message, WheelID $id) is Event {
        warn "Received socket error: Action $action, Code $code, Message $message"
            if $self->options->{'debug'};
    }

=method_protected handle_on_flushed

    (WheelID $id) is Event

handle_on_flushed is the FlushedEvent of each POE::Wheel::ReadWrite instantiated.

=cut

    method handle_on_flushed(WheelID $id) is Event {
        1;
    }


=method_public shutdown()

    is Event

shutdown unequivically terminates the TCPServer by clearing all wheels and 
aliases, forcing POE to garbage collect the session.

=cut

    method shutdown() is Event {
        $self->clear_socket_factory;
        $self->clear_wheels;
        $self->clear_alias;
        $self->poe->kernel->alias_remove($_) for $self->poe->kernel->alias_list();
    }

}

1;
__END__
=head1 DESCRIPTION

POEx::Role::TCPServer bundles up the lower level SocketFactory/ReadWrite
combination of wheels into a simple Moose::Role. It builds upon other POEx
modules such as POEx::Role::SessionInstantiation and POEx::Types. 

The events for SocketFactory for and for each ReadWrite instantiated are
methods that can be advised in any way deemed fit. Advising these methods
is actually encouraged and can simplify code for the consumer. 

The only method that must be provided by the consuming class is 
handle_inbound_data.

