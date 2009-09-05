#!/usr/bin/perl -w

BEGIN {
    if ( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ( '../lib', '../ext/Test-Harness/t/lib' );
    }
    else {
        unshift @INC, 't/lib';
    }
}

use strict;

use Test::More tests => 34;
use File::Spec;

my $dir = File::Spec->catdir(
    (   $ENV{PERL_CORE}
        ? ( File::Spec->updir(), 'ext', 'Test-Harness' )
        : ()
    ),
    't',
    'source_tests'
);

use_ok( 'TAP::Parser::Source' );

# Basic tests
{
    my $source = TAP::Parser::Source->new;
    isa_ok( $source, 'TAP::Parser::Source', 'new source' );
    can_ok( $source, qw( raw meta config merge switches test_args assemble_meta ) );

    is_deeply( $source->config, {}, 'config empty by default' );
    $source->config->{Foo} = { bar => 'baz' };
    is_deeply( $source->config_for( 'Foo' ), { bar => 'baz' }, 'config_for( Foo )' );
    is_deeply( $source->config_for( 'TAP::Parser::SourceHandler::Foo' ),
	       { bar => 'baz' }, 'config_for( ...::SourceHandler::Foo )' );

    ok( ! $source->merge, 'merge not set by default' );
    $source->merge( 1 );
    ok( $source->merge, '... merge now set' );

    is( $source->switches, undef, 'switches not set by default' );
    $source->switches([ '-Ilib' ]);
    is_deeply( $source->switches, ['-Ilib'], '... switches now set' );

    is( $source->test_args, undef, 'test_args not set by default' );
    $source->test_args([ 'foo' ]);
    is_deeply( $source->test_args, ['foo'], '... test_args now set' );

    $source->raw( \'hello world' );
    my $meta = $source->assemble_meta;
    is_deeply( $meta, {
		       is_scalar    => 1,
		       is_object    => 0,
		       has_newlines => 0,
		       length       => 11,
		      }, 'assemble_meta for scalar that isnt a file' );

    is( $source->meta, $meta, '... and caches meta' );
}

# array check
{
    my $source = TAP::Parser::Source->new;
    $source->raw([ 'hello', 'world' ]);
    my $meta = $source->assemble_meta;
    is_deeply( $meta, {
		       is_array     => 1,
		       is_object    => 0,
		       size         => 2,
		      }, 'assemble_meta for array' );
}

# hash check
{
    my $source = TAP::Parser::Source->new;
    $source->raw({ hello => 'world' });
    my $meta = $source->assemble_meta;
    is_deeply( $meta, {
		       is_hash      => 1,
		       is_object    => 0,
		      }, 'assemble_meta for array' );
}

# glob check
{
    my $source = TAP::Parser::Source->new;
    $source->raw( \*__DATA__ );
    my $meta = $source->assemble_meta;
    is_deeply( $meta, {
		       is_glob      => 1,
		       is_object    => 0,
		      }, 'assemble_meta for array' );
}

# object check
{
    my $source = TAP::Parser::Source->new;
    $source->raw( bless {}, 'Foo::Bar' );
    my $meta = $source->assemble_meta;
    is_deeply( $meta, {
		       is_object    => 1,
		       class        => 'Foo::Bar',
		      }, 'assemble_meta for array' );
}

# file test
{
    my $test   = File::Spec->catfile( $dir, 'source.t' );
    my $source = TAP::Parser::Source->new;

    $source->raw( \$test );
    my $meta = $source->assemble_meta;
    # separate meta->file to break up the test
    my $file = delete $meta->{file};
    is_deeply( $meta, {
		       is_scalar    => 1,
		       has_newlines => 0,
		       length       => length( $test ),
		       is_object    => 0,
		       is_file      => 1,
		       is_dir       => 0,
		       is_symlink   => 0,
		      }, 'assemble_meta for file' );

    # now check file meta - remove things that will vary between machine
    my $stat = delete $file->{stat};
    is( @$stat, 13, '... file->stat set' );
    my $size = delete $file->{size};
    ok( $size, '... file->size set' );
    my $dir = delete $file->{dir};
    ok( $dir, '... file->dir set' );
    is_deeply( $file, {
		       basename   => 'source.t',
		       ext        => '.t',
		       lc_ext     => '.t',
		       shebang    => '#!/usr/bin/perl',
		       binary     => 0,
		       text       => 1,
		       empty      => 0,
		       exists     => 1,
		       is_dir     => 0,
		       is_file    => 1,
		       is_symlink => 0,
		       sticky     => 0,
		       read       => 1,
		       write      => 1,
		       execute    => 0,
		       setgid     => 0,
		       setuid     => 0,
		      }, '... file->* set' );
}

# dir test
{
    my $test   = File::Spec->catfile( $dir );
    my $source = TAP::Parser::Source->new;

    $source->raw( \$test );
    my $meta = $source->assemble_meta;
    # separate meta->file to break up the test
    my $file = delete $meta->{file};
    is_deeply( $meta, {
		       is_scalar    => 1,
		       has_newlines => 0,
		       length       => length( $test ),
		       is_object    => 0,
		       is_file      => 0,
		       is_dir       => 1,
		       is_symlink   => 0,
		      }, 'assemble_meta for directory' );

    # now check file meta - remove things that will vary between machine
    my $stat = delete $file->{stat};
    is( @$stat, 13, '... file->stat set' );
    my $size = delete $file->{size};
    ok( $size, '... file->size set' );
    my $dir = delete $file->{dir};
    ok( $dir, '... file->dir set' );
    is_deeply( $file, {
		       basename   => 'source_tests',
		       ext        => '',
		       lc_ext     => '',
		       binary     => 1,
		       text       => 0,
		       empty      => 0,
		       exists     => 1,
		       is_dir     => 1,
		       is_file    => 0,
		       is_symlink => 0,
		       sticky     => 0,
		       read       => 1,
		       write      => 1,
		       execute    => 1,
		       setgid     => 0,
		       setuid     => 0,
		      }, '... file->* set' );
}

# symlink test
SKIP: {
    my $symlink_exists = eval { symlink( '', '' ); 1 };
    skip 'symlink not supported on this platform', 5 unless $symlink_exists;

    my $test    = File::Spec->catfile( $dir, 'source.t' );
    my $symlink = File::Spec->catfile( $dir, 'source_link.T' );
    my $source  = TAP::Parser::Source->new;

    eval { symlink( File::Spec->rel2abs( $test ), $symlink ) };
    if (my $e = $@) {
	diag( $@ );
	die "aborting test";
    }

    $source->raw( \$symlink );
    my $meta = $source->assemble_meta;
    # separate meta->file to break up the test
    my $file = delete $meta->{file};
    is_deeply( $meta, {
		       is_scalar    => 1,
		       has_newlines => 0,
		       length       => length( $symlink ),
		       is_object    => 0,
		       is_file      => 1,
		       is_dir       => 0,
		       is_symlink   => 1,
		      }, 'assemble_meta for symlink' );

    # now check file meta - remove things that will vary between machine
    my $stat = delete $file->{stat};
    is( @$stat, 13, '... file->stat set' );
    my $lstat = delete $file->{lstat};
    is( @$lstat, 13, '... file->lstat set' );
    my $size = delete $file->{size};
    ok( $size, '... file->size set' );
    my $dir = delete $file->{dir};
    ok( $dir, '... file->dir set' );
    is_deeply( $file, {
		       basename   => 'source_link.T',
		       ext        => '.T',
		       lc_ext     => '.t',
		       shebang    => '#!/usr/bin/perl',
		       binary     => 0,
		       text       => 1,
		       empty      => 0,
		       exists     => 1,
		       is_dir     => 0,
		       is_file    => 1,
		       is_symlink => 1,
		       sticky     => 0,
		       read       => 1,
		       write      => 1,
		       execute    => 0,
		       setgid     => 0,
		       setuid     => 0,
		      }, '... file->* set' );

    unlink $symlink;
}

