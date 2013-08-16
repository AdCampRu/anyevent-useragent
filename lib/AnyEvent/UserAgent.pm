package AnyEvent::UserAgent;

# This module based on original AnyEvent::HTTP::Simple module by punytan
# (punytan@gmail.com): http://github.com/punytan/AnyEvent-HTTP-Simple

use Moo;

use AnyEvent::HTTP ();
use HTTP::Cookies ();
use HTTP::Request ();
use HTTP::Request::Common ();
use HTTP::Response ();


our $VERSION = '0.01';


has timeout => (is => 'rw', default => sub { 30 });
has agent => (is => 'rw', default => sub { $AnyEvent::HTTP::USERAGENT . ' AnyEvent-UserAgent/' . $VERSION });
has cookie_jar => (is => 'rw', default => sub { HTTP::Cookies->new(hide_cookie2 => 1) });


sub get    { _request(GET    => @_) }
sub head   { _request(HEAD   => @_) }
sub post   { _request(POST   => @_) }
sub put    { _request(PUT    => @_) }
sub delete { _request(DELETE => @_) }

sub _request {
	my $cb   = pop();
	my $meth = shift();
	my $self = shift();

	no strict 'refs';
	$self->request(&{'HTTP::Request::Common::' . $meth}(@_), $cb);
}

sub request {
	my ($self, $req, $cb) = @_;

	$req->headers->user_agent($self->agent);
	$self->cookie_jar->add_cookie_header($req);

	my $headers = $req->headers;

	delete($headers->{'::std_case'});

	my %opts = (
		timeout => $self->timeout,
		headers => $headers,
		body    => $req->content,
	);

	AnyEvent::HTTP::http_request(
		$req->method,
		$req->uri,
		%opts,
		sub {
			$cb->(_response($req, $self->cookie_jar, @_));
		}
	);
}

sub _response {
	my ($req, $jar, $body, $hdrs) = @_;

	my $res = HTTP::Response->new(delete($hdrs->{Status}), delete($hdrs->{Reason}));
	my $prev;

	if (exists($hdrs->{Redirect})) {
		$prev = _response($req, $jar, @{delete($hdrs->{Redirect})});
	}

	if ($prev) {
		my $meth = $prev->request->method;
		my $code = $prev->code;
		if ($meth ne 'HEAD' && ($code == 301 || $code == 302 || $code == 303)) {
			$meth = 'GET';
		}
		$res->previous($prev);
		no strict 'refs';
		$res->request(&{'HTTP::Request::Common::' . $meth}(delete($hdrs->{URL})));
	}
	else {
		delete($hdrs->{URL});
		$res->request($req);
	}
	if (defined($hdrs->{HTTPVersion})) {
		$res->protocol('HTTP/' . delete($hdrs->{HTTPVersion}));
	}
	if (my $cookies = $hdrs->{'set-cookie'}) {
		local @_ = split(/,(\w+=)/, ',' . $cookies);
		shift();
		my @val;
		push(@val, join('', shift(), shift())) while @_;
		$hdrs->{'set-cookie'} = \@val;
	}
	if (keys(%$hdrs)) {
		$res->header(%$hdrs);
	}
	if (defined($body)) {
		$res->content_ref(\$body);
	}

	$jar->extract_cookies($res);

	return $res;
}


1;
