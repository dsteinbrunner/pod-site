#!/usr/bin/perl -w

use strict;
use Test::More tests => 53;
#use Test::More 'no_plan';
use File::Spec::Functions qw(tmpdir catdir catfile);
use File::Path qw(remove_tree);
use Test::File;
use Test::XPath;

my $CLASS;
BEGIN {
    $CLASS = 'Pod::Site';
    use_ok $CLASS or die;
}

my $mod_root = catdir qw(t lib);
my $tmpdir   = catdir tmpdir, "$$-pod-site-test";
my $doc_root = catdir $tmpdir, 'doc_root';
my $base_uri = '/docs/';

END { remove_tree if -d $tmpdir }

ok my $ps = Pod::Site->new({
    doc_root     => $doc_root,
    base_uri     => $base_uri,
    module_roots => $mod_root,
}), 'Create Pod::Site object';

file_not_exists_ok $doc_root, 'Doc root should not yet exist';
ok $ps->build, 'Build the site';
file_exists_ok $doc_root, 'Doc root should now exist';
is_deeply $ps->module_tree, {
    'Heya' => {
        'Man' => {
            'What.pm' => catfile qw(t lib Heya Man What.pm)
        },
        'Man.pm' => catfile qw(t lib Heya Man.pm)
    },
    'Heya.pm' => catfile( qw(t lib Heya.pm)),
    'Foo' => {
        'Bar' => {
            'Baz.pm' => catfile(qw(t lib Foo Bar Baz.pm))
        },
        'Shizzle.pm' => catfile(qw(t lib Foo Shizzle.pm)),
        'Bar.pm' => catfile qw(t lib Foo Bar.pm)
    },
    'Hello.pm' => catfile qw(t lib Hello.pm)
}, 'Should have a module tree';
is $ps->main_module,   'Foo::Bar::Baz', 'Should have a main module';
is $ps->sample_module, 'Foo::Bar::Baz', 'Should have a sample module';
is $ps->title,         'Foo::Bar::Baz', 'Should have default title';

##############################################################################
# Validate the index page.
ok my $tx = Test::XPath->new(
    file => catfile($doc_root, 'index.html'),
    is_html => 1
), 'Load index.html';

# Some basic sanity-checking.
$tx->is( 'count(/html)',      1, 'Should have 1 html element' );
$tx->is( 'count(/html/head)', 1, 'Should have 1 head element' );
$tx->is( 'count(/html/body)', 1, 'Should have 1 body element' );
$tx->is( 'count(/html/*)', 2, 'Should have 2 elements in html' );
$tx->is( 'count(/html/head/*)', 6, 'Should have 6 elements in head' );

# Check the head element.
$tx->is(
    '/html/head/meta[@http-equiv="Content-Type"]/@content',
    'text/html; charset=UTF-8',
    'Should have the content-type set in a meta header',
);
$tx->is(
    '/html/head/title',
    'Foo::Bar::Baz',
    'Title should be corect'
);
$tx->is(
    '/html/head/meta[@name="base-uri"]/@content',
    $base_uri,
    'base-uri should be corect'
);
$tx->is(
    '/html/head/link[@type="text/css"][@rel="stylesheet"]/@href',
    'podsite.css',
    'Should load the CSS',
);
$tx->is(
    '/html/head/script[@type="text/javascript"]/@src',
    'podsite.js',
    'Should load the JS',
);
$tx->is(
    '/html/head/meta[@name="generator"]/@content',
    ref($ps) . ' ' . ref($ps)->VERSION,
    'The generator meta tag should be present and correct'
);

# Check the body element.
$tx->is( 'count(/html/body/div)', 2, 'Should have 2 top-level divs' );
$tx->ok( '/html/body/div[@id="nav"]', sub {
    $_->is('./h3', 'Foo::Bar::Baz', 'Should have title header');
    $_->ok('./ul[@id="tree"]', sub {
        $_->ok('./li[@id="toc"]', sub {
            $_->is('./a[@href="toc.html"]', 'TOC', 'Should have TOC item');
        }, 'Should have toc li');
    }, 'Should have tree ul')
}, 'Should have nav div');
$tx->ok( '/html/body/div[@id="doc"]', 'Should have doc div');

#diag `cat $doc_root/index.html`;

##############################################################################
# Validate the TOC.
ok $tx = Test::XPath->new(
    file => catfile($doc_root, 'toc.html'),
    is_html => 1
), 'Load toc.html';

# Some basic sanity-checking.
$tx->is( 'count(/html)',      1, 'Should have 1 html element' );
$tx->is( 'count(/html/head)', 1, 'Should have 1 head element' );
$tx->is( 'count(/html/body)', 1, 'Should have 1 body element' );
$tx->is( 'count(/html/*)', 2, 'Should have 2 elements in html' );

# Check the head element.
$tx->is( 'count(/html/head/*)', 3, 'Should have 3 elements in head' );
$tx->is(
    '/html/head/meta[@http-equiv="Content-Type"]/@content',
    'text/html; charset=UTF-8',
    'Should have the content-type set in a meta header',
);

$tx->is( '/html/head/title', $ps->title, 'Title should be corect');

$tx->is(
    '/html/head/meta[@name="generator"]/@content',
    ref($ps) . ' ' . ref($ps)->VERSION,
    'The generator meta tag should be present and correct'
);

# Check the body.
$tx->is( 'count(/html/body/*)', 7, 'Should have 7 elements in body' );

# Headers.
$tx->is( 'count(/html/body/h1)', 2, 'Should have 2 h1 elements in body' );

$tx->is( '/html/body/h1[1]', $ps->title, 'Should have title in first h1 header');
$tx->is(
    '/html/body/h1[2]', 'Instructions',
    'Should have "Instructions" in second h1 header'
);

$tx->is( 'count(/html/body/h3)', 1, 'Should have 1 h3 element in body' );
$tx->is( '/html/body/h3', 'Classes & Modules', 'h3 should be correct');

# Paragraphs.
$tx->is( 'count(/html/body/p)', 2, 'Should have 2 p elements in body' );
$tx->like(
    '/html/body/p[1]', qr/^Select class names/,
    'First paragraph should look right'
);

$tx->is(
    '/html/body/p[2]', 'Happy Hacking!', 'Second paragraph should be right'
);

# Example list.
$tx->is( 'count(/html/body/ul)', 2, 'Should have 2 ul elements in body' );
$tx->ok('/html/body/ul[1]', sub {
    $_->is('count(./li)', 2, 'Should have two list items');
    $_->is('count(./li/a)', 2, 'Both should have anchors');
    $_->is(
        './li/a[@href="./?Foo::Bar::Baz"]', '/?Foo::Bar::Baz',
        'First link should be correct'
    );
    $_->is(
        './li/a[@href="./Foo::Bar::Baz"]', '/Foo::Bar::Baz',
        'Second link should be correct'
    );
}, 'Should have first unordered list');

# Class list.
$tx->ok('/html/body/ul[2]', sub {

}, 'Should have second unordered list');

#diag `cat $doc_root/toc.html`;

