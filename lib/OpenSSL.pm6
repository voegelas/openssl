class OpenSSL;

use OpenSSL::SSL;

use NativeCall;

has $.ctx;
has $.ssl;
has $.client;

method new(Bool :$client = False, Int :$version?) {
    OpenSSL::SSL::SSL_library_init();
    OpenSSL::SSL::SSL_load_error_strings();

    my $method;
    if $version.defined {
        $method = $version == 2
            ?? ($client ?? OpenSSL::Method::SSLv2_client_method() !! OpenSSL::Method::SSLv2_server_method())
            !! ($client ?? OpenSSL::Method::SSLv3_client_method() !! OpenSSL::Method::SSLv3_server_method());
    }
    else {
        $method = $client ?? OpenSSL::Method::SSLv23_client_method() !! OpenSSL::Method::SSLv23_server_method();
    }
    my $ctx     = OpenSSL::Ctx::SSL_CTX_new( $method );
    my $ssl     = OpenSSL::SSL::SSL_new( $ctx );

    self.bless(:$ctx, :$ssl, :$client);
}

method set-fd(int32 $fd) {
    OpenSSL::SSL::SSL_set_fd($!ssl, $fd);
}

method set-connect-state {
    OpenSSL::SSL::SSL_set_connect_state($!ssl);
}

method set-accept-state {
    OpenSSL::SSL::SSL_set_accept_state($!ssl);
}

method connect {
    OpenSSL::SSL::SSL_connect($!ssl);
}

method accept {
    OpenSSL::SSL::SSL_accept($!ssl);
}

method write(Str $s) {
    my int32 $n = $s.chars;
    OpenSSL::SSL::SSL_write($!ssl, str-to-carray($s), $n);
}

method read(Int $n, Bool :$bin) {
    my int32 $count = $n;
    my $carray = get_buf($count);
    my $read = OpenSSL::SSL::SSL_read($!ssl, $carray, $count);

    my $buf = buf8.new($carray[0..$read]) if $bin.defined;

    return $bin.defined ?? $buf !! $carray[0..$read]>>.chr.join('');
}

method shutdown {
    OpenSSL::SSL::SSL_shutdown($.ssl);
}

method ctx-free {
    OpenSSL::Ctx::SSL_CTX_free($!ctx);
}

method free {
    OpenSSL::SSL::SSL_free($!ssl);
}

method close {
    until self.shutdown { };
}

sub get_buf(int32) returns CArray[uint8] is native('./libbuf') { * }

sub str-to-carray(Str $s) {
    my @s = $s.split('');
    my $c = CArray[uint8].new;
    for 0 ..^ $s.chars -> $i {
        my uint8 $elem = @s[$i].ord;
        $c[$i] = $elem;
    }
    $c;
}
