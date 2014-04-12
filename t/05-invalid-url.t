#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;
use AnyEvent::UserAgent;


my $ua = AnyEvent::UserAgent->new;
my $cv = AE::cv;

$ua->get('invalid', sub {
	my ($res) = @_;

	ok   $res->code > 590, 'HTTP status with error';
	like $res->message, qr/Only http and https/, 'Allow only http(s) request';
	$cv->send();
});
$cv->recv();
