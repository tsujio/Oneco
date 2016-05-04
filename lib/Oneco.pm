package Oneco;

use 5.010;
use strict;
use warnings;

use CGI;

sub new {
  my ($class) = @_;

  bless {
    router => Oneco::Router->new,
  }, $class;
}

# Route defining methods
sub get { $_[0]->{router}->add('GET', $_[1], $_[2]); return; }
sub post { $_[0]->{router}->add('POST', $_[1], $_[2]); return; }
sub put { $_[0]->{router}->add('PUT', $_[1], $_[2]); return; }
sub patch { $_[0]->{router}->add('PATCH', $_[1], $_[2]); return; }
sub delete { $_[0]->{router}->add('DELETE', $_[1], $_[2]); return; }

# Run app
sub run {
  my ($self) = @_;

  # Create cgi object
  my $cgi = CGI->new;
  $cgi->charset('utf-8');

  # Create controller object
  my $controller = Oneco::Controller->new($cgi);

  # Find matched rule
  my $matched = $self->{router}->match(
    $cgi->request_method,
    $cgi->path_info
  );

  # Matched rule not found
  unless (defined $matched) {
    $controller->render_error(404);
    return;
  }

  # Execute callback
  $matched->{callback}(
    $controller,
    @{$matched->{params}}
  );

  return;
}

###############################################################################
# Oneco::Router ###############################################################
###############################################################################

package Oneco::Router;

use 5.010;
use strict;
use warnings;

sub new {
  my $class = shift;
  bless {
    routes => {},
  }, $class;
}

# Add route
sub add {
  my ($self, $method, $path, $callback) = @_;

  # Make regex from path DSL
  my $path_re = $self->parse_path_dsl($path);

  # Store rule with specified method
  my $rules = $self->{routes}{lc($method)} // [];
  push @$rules, { path => $path_re, callback => $callback };
  $self->{routes}{lc($method)} = $rules;
}

# Parse path DSL (ex. '/foo/:bar') and generate regex
sub parse_path_dsl {
  my ($self, $path) = @_;

  # Split path with '/'
  my @path_elms = split m{/}, $path;

  # Make path regex string
  my $path_re_str = '';
  for my $elm (@path_elms) {
    unless (length $elm) {
      next;
    }

    if ($elm =~ /^:([a-zA-Z_]+)$/) {
      # Case of wildcard
      $path_re_str .= "/(?<$1>[^/]+)";
    } else {
      # Case of static string
      $path_re_str .= "/$elm";
    }
  }

  # Path should start with '/'
  if (index($path_re_str, '/') != 0) {
    $path_re_str = '/' . $path_re_str;
  }

  # Make regex and return
  my $path_re = qr/\A$path_re_str\z/;
  return $path_re;
}

# Match rules and return callback with wildcard params
sub match {
  my ($self, $method, $path) = @_;

  # Get rules from method name
  my $rules = $self->{routes}{lc($method)};
  return undef unless defined $rules;

  # Trim '/' at the tail of path
  $path =~ s!(.)/\z!$1!;

  # Find matched rule
  for my $rule (@$rules) {
    my @params = $path =~ $rule->{path};
    if (@params) {
      # Found
      return { callback => $rule->{callback}, params => [ @params ]};
    }
  }
  return undef;
}

###############################################################################
# Oneco::Controller ###########################################################
###############################################################################

package Oneco::Controller;

use 5.010;
use strict;
use warnings;

sub new {
  my ($class, $cgi) = @_;

  bless {
    cgi => $cgi,
  }, $class;
}

# Output response
sub render {
  my $self = shift;
  my $view_name = shift;
  my $params = { @_ };

  # Output header
  print $self->{cgi}->header;

  # Output body
  print Oneco::Template->new($view_name)->render($params);

  return;
}

# Output error response
sub render_error {
  my ($self, $status) = @_;

  print $self->{cgi}->header(-status => '404 Not Found');
  return;
}

###############################################################################
# Oneco::Template #############################################################
###############################################################################

package Oneco::Template;

use 5.010;
use strict;
use warnings;

use HTML::Template;
use File::Basename qw/dirname/;
use File::Spec::Functions qw/catfile/;

sub new {
  my ($class, $view_name) = @_;

  # View search dir
  my $views_dir = catfile(dirname($ENV{SCRIPT_FILENAME}), 'views');

  # Search view file
  my $file_path = catfile($views_dir, $view_name);
  for my $suffix ('', qw/.tmpl/) {
    if (-f ($file_path . $suffix)) {
      $file_path .= $suffix;
      last;
    }
  }
  die "$file_path not found" unless -f $file_path;

  bless {
    file_path => $file_path,
  }, $class;
}

# Build template
sub render {
  my ($self, $params) = @_;

  my $template = HTML::Template->new(
    filename => $self->{file_path},
    utf8 => 1
  );
  $template->param($params);

  return $template->output();
}

1;
