unit class Build;

my sub ldconfig-p {
    try run('/sbin/ldconfig', '-p', :out, :!err).out.lines(:close)
        .grep(/^\h/)
        .map: {
            /^\h+ $<name>=(\H+) .+ \=\> \h+ $<path>=(\H+)/;
            $<name>.Str => $<path>.Str
        }
}

method build($cwd --> Bool) {
    my %libraries =
        ssl    => { name => 'ssl',    version => Any },
        crypto => { name => 'crypto', version => Any };

    my $prefix;
    if %*ENV<OPENSSL_PREFIX>:exists {
        $prefix = %*ENV<OPENSSL_PREFIX>;
    } elsif !$*DISTRO.is-win {
        my $proc = run "brew", "--prefix", "--installed", "openssl", :out, :!err;
        if ?$proc {
            $prefix = $proc.out.slurp(:close).chomp;
        }
    }
    if $prefix {
        note "Using openssl prefix $prefix";
        %libraries<ssl><name>    = $prefix.IO.child('lib').child('ssl').Str;
        %libraries<crypto><name> = $prefix.IO.child('lib').child('crypto').Str;
    }
    else {
        given $*VM.osname {
            when 'linux' {
                # Check if libssl.so.1.1 and libcrypto.so.1.1 are available.
                my %libs = ldconfig-p();
                my $version = v1.1;
                for %libraries.values -> %library {
                    my $name = $*VM.platform-library-name(
                        %library<name>.IO,
                        version => $version
                    );
                    if %libs{$name}:exists {
                        %library<version> = $version;
                    }
                }
            }
        }
    }

    my $json = Rakudo::Internals::JSON.to-json: %libraries, :pretty, :sorted-keys;
    "resources/libraries.json".IO.spurt: $json;
    return True;
}
