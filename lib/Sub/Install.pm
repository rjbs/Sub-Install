package Sub::Install;

use warnings;
use strict;

use Carp qw(croak);

=head1 NAME

Sub::Install - install subroutines into packages easily

=head1 VERSION

version 0.90

 $Id: /my/rjbs/subinst/trunk/lib/Sub/Install.pm 16622 2005-11-23T00:17:55.304991Z rjbs  $

=cut

our $VERSION = '0.90';

=head1 SYNOPSIS

  use Sub::Install;

  Sub::Install::install_sub({
    code => sub { ... },
    into => $package,
    as   => $subname
  });

=head1 DESCRIPTION

This module makes it easy to install subroutines into packages without the
unslightly mess of C<no strict> or typeglobs lying about where just anyone can
see them.

=head1 FUNCTIONS

=head2 C< install_sub >

  Sub::Install::install_sub({
   code => \&subroutine,
   into => "Finance::Shady",
   as   => 'launder',
  });

This routine installs a given code reference into a package as a normal
subroutine.  The above is equivalent to:

  no strict 'refs';
  *{"Finance::Shady" . '::' . "launder"} = \&subroutine;

If C<into> is not given, the sub is installed into the calling package.

If C<code> is not a code reference, it is looked for as an existing sub in the
package named in the C<from> parameter.  If C<from> is not given, it will look
in the calling package.

If C<as> is not given, and if C<code> is a name, C<as> will default to C<code>.
If C<as> is not given, but if C<code> is a code ref, Sub::Install will try to
find the name of the given code ref and use that as C<as>.

That means that this code:

  Sub::Install::install_sub({
    code => 'twitch',
    from => 'Person::InPain',
    into => 'Person::Teenager',
    as   => 'dance',
  });

is the same as:

  package Person::Teenager;

  Sub::Install::install_sub({
    code => Person::InPain->can('twitch'),
    as   => 'dance',
  });

=head2 C< reinstall_sub >

This routine behaves exactly like C<L</install_sub>>, but does not emit a
warning if warnings are on and the destination is already defined.

=cut

sub _name_of_code {
  my ($code) = @_;
  require B;
  my $name = B::svref_2object($code)->GV->NAME;
  return $name unless $name =~ /\A__ANON__/;
  return;
}

# do the heavy lifting
sub _build_public_installer {
  my ($installer) = @_;

  sub {
    my ($arg) = @_;
    my ($calling_pkg) = caller(0);

    # I'd rather use ||= but I'm whoring for Devel::Cover.
    for (qw(into from)) { $arg->{$_} = $calling_pkg unless $arg->{$_} }

    # This is the only absolutely required argument, in many cases.
    croak "named argument 'code' is not optional" unless $arg->{code};

    if (ref $arg->{code} eq 'CODE') {
      $arg->{as} ||= _name_of_code($arg->{code});
    } else {
      croak
        "couldn't find subroutine named $arg->{code} in package $arg->{from}"
        unless my $code = $arg->{from}->can($arg->{code});

      $arg->{as}   = $arg->{code} unless $arg->{as};
      $arg->{code} = $code;
    }

    croak "couldn't determine name under which to install subroutine"
      unless $arg->{as};

    $installer->(@$arg{qw(into as code) });
  }
}

# do the ugly work

my $_misc_warn_re;
my $_redef_warn_re;
BEGIN {
  $_misc_warn_re = qr/
    Prototype\ mismatch:\ sub\ .+?  |
    Constant subroutine \S+ redefined
  /x;
  $_redef_warn_re = qr/Subroutine\ \S+\ redefined/x;
}

my $eow_re;
BEGIN { $eow_re = qr/ at .+? line \d+\.\Z/ };

sub _do_with_warn {
  my ($arg) = @_;
  sub {
    my ($code) = @_;

    my $warn = $SIG{__WARN__} ? $SIG{__WARN__} : sub { warn @_ };
    local $SIG{__WARN__} = sub {
      my ($error) = @_;
      for (@{ $arg->{suppress} }) {
          return if $error =~ $_;
      }
      for (@{ $arg->{croak} }) {
        if (my ($base_error) = $error =~ /\A($_) $eow_re/x) {
          Carp::croak $base_error;
        }
      }
      for (@{ $arg->{carp} }) {
        if (my ($base_error) = $error =~ /\A($_) $eow_re/x) {
          return $warn->(Carp::shortmess $base_error);
          last;
        }
      }
      ($arg->{default} || $warn)->($error);
    };
    $code->();
  };
}

sub _generate_installer {
  my ($arg) = @_;
  sub {
    my ($pkg, $name, $code) = @_;
    my $inst = sub {
      no strict 'refs';
      *{"$pkg\::$name"} = $code;
      return $code;
    };
    $arg->{inst_wrapper} ? $arg->{inst_wrapper}->($inst) : $inst->();
  }
}

BEGIN {
  my $install   = _generate_installer({
    inst_wrapper => _do_with_warn({
      carp => [ $_misc_warn_re, $_redef_warn_re ]
    }),
  });

  *install_sub = _build_public_installer($install);

  my $reinstall = _generate_installer({
    inst_wrapper => _do_with_warn({
      carp     => [ $_misc_warn_re ],
      suppress => [ $_redef_warn_re ],
    }),
  });

  *reinstall_sub = _build_public_installer($reinstall);

  *_install_fatal = _generate_installer({
    inst_wrapper => _do_with_warn({
      croak    => [ $_redef_warn_re ],
    }),
  });
}

=head2 C< install_installers >

This routine is provided to allow Sub::Install compatibility with
Sub::Installer.  It installs C<install_sub> and C<reinstall_sub> methods into
the package named by its argument.

 Sub::Install::install_installers('Code::Builder'); # just for us, please
 Code::Builder->install_sub({ name => $code_ref });

 Sub::Install::install_installers('UNIVERSAL'); # feeling lucky, punk?
 Anything::At::All->install_sub({ name => $code_ref });

The installed installers are similar, but not identical, to those provided by
Sub::Installer.  They accept a single hash as an argument.  The key/value pairs
are used as the C<as> and C<code> parameters to the C<install_sub> routine
detailed above.  The package name on which the method is called is used as the
C<into> parameter.

Unlike Sub::Installer's C<install_sub> will not eval strings into code, but
will look for named code in the calling package.

=cut

sub install_installers {
  my ($into) = @_;

  for my $method (qw(install_sub reinstall_sub)) {
    my $code = sub {
      my ($package, $subs) = @_;
      my ($caller) = caller(0);
      my $return;
      for (my ($name, $sub) = %$subs) {
        $return = Sub::Install->can($method)->({
          code => $sub,
          from => $caller,
          into => $package,
          as   => $name
        });
      }
      return $return;
    };
    install_sub({ code => $code, into => $into, as => $method });
  }
}

=head1 EXPORTS

Sub::Install exports C<install_sub> and C<reinstall_sub> only if they are
requested.

=cut

my @EXPORT_OK;
BEGIN { @EXPORT_OK = qw(install_sub reinstall_sub); }

sub import {
  my $class = shift;
  my %todo  = map { $_ => 1 } @_;
  my ($target) = caller(0);

  # eating my own dogfood
  install_sub({ code => $_, into => $target }) for grep {$todo{$_}} @EXPORT_OK;
}

=head1 SEE ALSO

=over

=item L<Sub::Installer>

This module is (obviously) a reaction to Damian Conway's Sub::Installer, which
does the same thing, but does it by getting its greasy fingers all over
UNIVERSAL.  I was really happy about the idea of making the installation of
coderefs less ugly, but I couldn't bring myself to replace the ugliness of
typeglobs and loosened strictures with the ugliness of UNIVERSAL methods.

=item L<Sub::Exporter>

This is a complete Exporter.pm replacement, built atop Sub::Install.

=back

=head1 AUTHOR

Ricardo Signes, C<< <rjbs@cpan.org> >>

Several of the tests are adapted from tests that shipped with Damian Conway's
Sub-Installer distribution.

=head1 BUGS

Please report any bugs or feature requests to C<bug-sub-install@rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org>.  I will be notified, and
then you'll automatically be notified of progress on your bug as I make
changes.

=head1 COPYRIGHT

Copyright 2005-2006 Ricardo Signes, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
