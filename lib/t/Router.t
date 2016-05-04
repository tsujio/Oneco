#!/usr/bin/env perl

###############################################################################
#  Test cases for Oneco::Router ###############################################
###############################################################################

use 5.010;
use strict;
use warnings;

use Test::More;

use FindBin;
use File::Basename qw/dirname/;
use lib dirname($FindBin::Bin);
use Oneco;

my $router;
my $path_re;
my $matched;

###############################################################################
#  Test for #parse_path_dsl ###################################################
###############################################################################

$router = Oneco::Router->new;

# Route '/'
$path_re = $router->parse_path_dsl('/');
ok('/' =~ $path_re, "Path='/' route='/'");
ok('/foo' !~ $path_re, "Path='/foo' route='/'");
ok('/ ' !~ $path_re, "Path='/ ' route='/'");
is(keys(%+), 0, "# of wildcards path='/' route='/'");

# Route '/foo'
$path_re = $router->parse_path_dsl('/foo');
ok('/' !~ $path_re, "Path='/' route='/foo'");
ok('/foo' =~ $path_re, "Path='/foo' route='/foo'");
ok('/fooo' !~ $path_re, "Path='/fooo' route='/foo'");
ok('/foo/' !~ $path_re, "Path='/foo/' route='/foo'");
ok('/foo ' !~ $path_re, "Path='/foo ' route='/foo'");
is(keys(%+), 0, "# of wildcards path='/foo' route='/foo'");

# Route '/foo/bar'
$path_re = $router->parse_path_dsl('/foo/bar');
ok('/' !~ $path_re, "Path='/' route='/foo/bar'");
ok('/foo' !~ $path_re, "Path='/foo' route='/foo/bar'");
ok('/foo/bar' =~ $path_re, "Path='/foo/bar' route='/foo/bar'");
ok('/foo/barr' !~ $path_re, "Path='/foo/barr' route='/foo/bar'");
ok('/foo/bar/' !~ $path_re, "Path='/foo/bar/' route='/foo/bar'");
ok('/foo/bar ' !~ $path_re, "Path='/foo/bar ' route='/foo/bar'");
is(keys(%+), 0, "# of wildcards path='/foo/bar' route='/foo/bar'");

# Route '/foo/:bar'
$path_re = $router->parse_path_dsl('/foo/:bar');
ok('/' !~ $path_re, "Path='/' route='/foo/:bar'");
ok('/foo' !~ $path_re, "Path='/foo' route='/foo/:bar'");
ok('/foo/bar' =~ $path_re, "Path='/foo/bar' route='/foo/:bar'");
is(keys(%+), 1, "# of wildcards path='/foo/bar' route='/foo/:bar'");
is($+{bar}, 'bar', "Value of parameter 'bar' path='/foo/bar' route='/foo/:bar'");
ok('/foo/1' =~ $path_re, "Path='/foo/1' route='/foo/:bar'");
is(keys(%+), 1, "# of wildcards path='/foo/1' route='/foo/:bar'");
is($+{bar}, '1', "Value of parameter 'bar' path='/foo/1' route='/foo/:bar'");
ok('/foo/bar/' !~ $path_re, "Path='/foo/bar/' route='/foo/:bar'");

# Route '/:foo/:bar'
$path_re = $router->parse_path_dsl('/:foo/:bar');
ok('/' !~ $path_re, "Path='/' route='/:foo/:bar'");
ok('/foo' !~ $path_re, "Path='/foo' route='/:foo/:bar'");
ok('/foo/bar' =~ $path_re, "Path='/foo/bar' route='/:foo/:bar'");
is(keys(%+), 2, "# of wildcards path='/foo/bar' route='/:foo/:bar'");
is($+{foo}, 'foo', "Value of parameter 'foo' path='/foo/bar' route='/:foo/:bar'");
is($+{bar}, 'bar', "Value of parameter 'bar' path='/foo/bar' route='/:foo/:bar'");
ok('/foo/' !~ $path_re, "Path='/foo/' route='/:foo/:bar'");
ok('/foo/bar/' !~ $path_re, "Path='/foo/bar/' route='/:foo/:bar'");

###############################################################################
# Test for #add and #match ####################################################
###############################################################################

$router = Oneco::Router->new;

# Add routes
$router->add('GET', '/', sub { '/' });
$router->add('POST', '/foo', sub { '/foo' });
$router->add('POST', '/foo/:bar', sub { '/foo/:bar' });

# GET /
$matched = $router->match('GET', '/');
is($matched->{callback}(), '/', "Check callback req='GET /'");

# POST /
$matched = $router->match('POST', '/');
ok(!defined $matched, "Check callback req='POST /'");

# POST /foo
$matched = $router->match('POST', '/foo');
is($matched->{callback}(), '/foo', "Check callback req='POST /foo'");

# POST /foo/
$matched = $router->match('POST', '/foo/');
is($matched->{callback}(), '/foo', "Check callback req='POST /foo'");

# POST /foo/bar
$matched = $router->match('POST', '/foo/bar');
is($matched->{callback}(), '/foo/:bar', "Check callback req='POST /foo/bar'");
is(@{$matched->{params}}, 1, "Check # of params req='POST /foo/bar'");
is($matched->{params}[0], 'bar', "Check value of param 'bar' req='POST /foo/bar'");

###############################################################################
#  End of tests ###############################################################
###############################################################################

done_testing();
