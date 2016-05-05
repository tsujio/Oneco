package Oneco;

use 5.010;
use strict;
use warnings;

use CGI;
use File::Basename qw/dirname/;
use File::Spec::Functions qw/catfile/;
use Cwd qw/abs_path/;

sub new {
  my ($class) = @_;

  # Create cgi object
  my $cgi = CGI->new;
  $cgi->charset('utf-8');

  bless {
    cgi => $cgi,
    router => Oneco::Router->new,
    public_dir => catfile(dirname($ENV{SCRIPT_FILENAME}), 'public'),
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

  # Create controller object
  my $controller = Oneco::Controller->new($self->{cgi});

  # Serve static file if found in public dir
  my $static_file = catfile($self->{public_dir}, $self->{cgi}->path_info);
  $static_file = abs_path($static_file);
  if (index($static_file, $self->{public_dir}) == 0 && -f $static_file) {
    $controller->render_static($static_file);
    return;
  }

  # Find matched rule
  my $matched = $self->{router}->match(
    $self->{cgi}->request_method,
    $self->{cgi}->path_info
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

# Get URL
sub url {
  return $_[0]->{cgi}->url . ($_[1] // '');
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

  # Normalize path
  $path = '/' unless length $path;  # Set '/' if path is empty
  $path =~ s!(.)/\z!$1!;  # Trim '/' at the tail of path

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

use Encode qw/encode/;

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
  print encode('utf-8', $self->{cgi}->header);

  # Output body
  print encode('utf-8', Oneco::Template->new($view_name)->render($params));

  return;
}

# Output error response
sub render_error {
  my ($self, $status) = @_;

  print encode('utf-8', $self->{cgi}->header(-status => '404 Not Found'));
  return;
}

# Output static file
sub render_static {
  my ($self, $file_path) = @_;

  # Output header
  my $mime;
  if ($file_path =~ /\.html\z/) { $mime = 'text/html'; }
  if ($file_path =~ /\.js\z/) { $mime = 'text/js'; }
  if ($file_path =~ /\.css\z/) { $mime = 'text/css'; }
  print encode('utf-8', $self->{cgi}->header($mime));

  # Output file content
  open my $in, '<', $file_path or die "Cannot open $file_path: $!";
  binmode $in;
  while (1) {
    my $len = read $in, my $buf, 1024;  # Read by 1024 bytes of chunks
    die "Cannot read $file_path: $!" unless defined $len;
    last if $len == 0;
    print $buf;
  }
  close $in or die "Cannot close $file_path: $!";

  return;
}

# Redirect
sub redirect {
  my ($self, $dest) = @_;

  print encode('utf-8', $self->{cgi}->redirect($dest));
  return;
}

# Get request parameter
sub param {
  return $_[0]->{cgi}->param($_[1]);
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
    utf8 => 1,  # Input file encoding
    die_on_bad_params => 0,  # Ignore unused params
  );
  $template->param($params);

  return $template->output();
}

1;
