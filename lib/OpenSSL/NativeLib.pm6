unit module OpenSSL::NativeLib;

my %libraries = Rakudo::Internals::JSON.from-json: %?RESOURCES<libraries.json>.slurp(:close);

my sub library-name(%library, $dll) {
    if $*DISTRO.is-win {
        return dll-resource($dll);
    }

    my $name    = %library<name>.IO;
    my $version = %library<version>;
    if defined $version {
        return $*VM.platform-library-name($name, version => Version($version)).Str;
    }
    return $*VM.platform-library-name($name).Str;
}

sub ssl-lib is export {
    state $lib = library-name(%libraries<ssl>, 'ssleay32.dll');
}

sub gen-lib is export {
    state $lib = library-name(%libraries<ssl>, 'libeay32.dll');
}

sub crypto-lib is export {
    state $lib = library-name(%libraries<crypto>, 'libeay32.dll');
}

# Windows only
# Problem: The dll files in resources/ don't like to be renamed, but CompUnit::Repository::Installation
# does not provide a mechanism for storing resources without name mangling. Find::Bundled provided
# this before, but it has suffered significant bit rot.
# "Fix": Continue to store the name mangled resource. Check $*TMPDIR/<sha1 of resource path>/$basename
# and use it if it exists, otherwise copy the name mangled file to this location but using the
# original unmangled name.
# XXX: This should be removed when CURI/%?RESOURCES gets a mechanism to bypass name mangling
use nqp;
sub dll-resource($resource-name) {
    my $resource      = %?RESOURCES{$resource-name};
    return $resource.absolute if $resource.basename eq $resource-name;

    my $content_id    = nqp::sha1($resource.absolute);
    my $content_store = $*TMPDIR.child($content_id);
    my $content_file  = $content_store.child($resource-name).absolute;
    return $content_file if $content_file.IO.e;

    mkdir $content_store unless $content_store.e;
    copy($resource, $content_file);

    $content_file;
}
