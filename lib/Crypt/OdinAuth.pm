package Crypt::OdinAuth;

use 5.006;
use strict;
use warnings;

=head1 NAME

Crypt::OdinAuth - Cryptographic calculations for the OdinAuth SSO system

=head1 VERSION

Version 0.2.1

=cut

our $VERSION = '0.2.1';

use Digest;
use Digest::HMAC;
use Digest::SHA256;
use MIME::Base64 qw(encode_base64url decode_base64url);

use constant OLD_COOKIE => 24*60*60; # cookie older than 24h is discarded

=head1 SYNOPSIS

This module exports functions for calculating and verifying signed
cookies for OdinAuth SSO Apache handler.

    use Crypt::OdinAuth;

    Crypt::OdinAuth::hmac_for('secret', 'login_name', 'role1,role2,role3', 1337357387, 'netcat')
    #=> '349b7135f43bd4c0111564960e7d9d583dde0c5c'

    Crypt::OdinAuth::cookie_for('secret', 'login_name', 'role1,role2,role3', 'netcat')
    #=> 'login_name-role1,role2,role3-1337357638-7ec415a6816c8e9dab7b788e1262769ef80af7d8'

=head1 SUBROUTINES

=head2 hmac_for(secret, user, roles, timestamp, user_agent)

=cut
sub hmac_for ($$$$$) {
    my ( $secret, $user, $roles, $ts, $ua ) = @_;
    my $hmac = Digest::HMAC->new($secret, Digest->new("SHA-256"));

    $hmac->add(join(',',
                    encode_base64url($user),
                    encode_base64url($roles),
                    $ts,
                    encode_base64url($ua)));
    return $hmac->hexdigest;
}

=head2 cookie_for(secret, user, roles, user_agent)

=cut

sub cookie_for {
    my ( $secret, $user, $roles, $ua, $ts ) = @_;
    $ts = time() unless defined($ts);

    my $hmac = hmac_for($secret, $user, $roles, $ts, $ua);
    return join(',',
                encode_base64url($user),
                encode_base64url($roles),
                $ts,
                $hmac);
}

=head2 check_cookie(secret, cookie, user_agent)

=cut

sub check_cookie ($$$) {
    my ( $secret, $cookie, $ua ) = @_;

    $cookie =~ /^\s*([a-zA-Z0-9_-]+),([a-zA-Z0-9_-]+),(\d+),([0-9a-f]+)\s*$/
      or die "Wrong cookie format\n";

    my $user = decode_base64url($1);
    my $roles = decode_base64url($2);
    my $ts = $3;
    my $hmac = $4;

    # Use double hmac to prevent timing attacks
    # http://codahale.com/a-lesson-in-timing-attacks/
    # http://www.isecpartners.com/blog/2011/2/18/double-hmac-verification.html
    my $hmac_received   = Digest::HMAC->new($secret, Digest->new("SHA-256"));
    my $hmac_calculated = Digest::HMAC->new($secret, Digest->new("SHA-256"));

    $hmac_received->add($hmac);
    $hmac_calculated->add(hmac_for($secret, $user, $roles, $ts, $ua));

    die "Invalid signature\n"
      if ( $hmac_received->digest ne $hmac_calculated->digest );

    die "Cookie is old\n"
        if ( $ts < time() - OLD_COOKIE );

    die "Cookie is in future\n"
        if ( $ts > time() + 5*60 );

    return $user, $roles;
}

=head1 AUTHOR

Maciej Pasternacki, C<< <maciej at pasternacki.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-apache2-authen-odinauth at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Apache2-Authen-OdinAuth>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Crypt::OdinAuth


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Apache2-Authen-OdinAuth>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Apache2-Authen-OdinAuth>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Apache2-Authen-OdinAuth>

=item * Search CPAN

L<http://search.cpan.org/dist/Apache2-Authen-OdinAuth/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Maciej Pasternacki.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Crypt::OdinAuth
