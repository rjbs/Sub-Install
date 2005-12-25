use Sub::Install;
use Test::More 'no_plan';

use strict;
use warnings;

# These tests largely copied from Damian Conway's Sub::Installer tests.

{ # Install a sub in a package...
  my $sub_ref = Sub::Install::install_sub({ code => \&ok, as => 'ok1' });

  isa_ok($sub_ref, 'CODE', 'return value of first install_sub');

  is_deeply($sub_ref, \&ok, 'it returns the correct code ref');

  ok1(1, 'installed sub runs');
}

{ # Install the same sub in the same package...
  local $SIG{__WARN__}
    = sub { pass('warned as expected') if $_[0] =~ /redefined/ };

  my $sub_ref = Sub::Install::install_sub({ code => \&is, as => 'ok1' });

  isa_ok($sub_ref, 'CODE', 'return value of second install_sub');

  is_deeply($sub_ref, \&is, 'install2 returns correct code ref');

  ok1(1,1, 'installed sub runs (with new arguments)');
}

{ # Install in another package...
  my $sub_ref = Sub::Install::install_sub({
    code => \&ok,
    into => 'Other',
    as   => 'ok1'
  });

  isa_ok($sub_ref, 'CODE', 'return value of third install_sub');

  is_deeply($sub_ref, \&ok, 'it returns the correct code ref');

  ok1(1,1, 'sub previously installed into main still runs properly');

  package Other;
  ok1(1,   'remotely installed sub runs properly');
}

{ # cross-package installation
  sub Other::Another::foo { return $_[0] }

  my $sub_ref = Sub::Install::install_sub({
    code => 'foo',
    from => 'Other::Another',
    into => 'Other::YetAnother',
    as   => 'return_lhs'
  });

  isa_ok($sub_ref, 'CODE', 'return value of fourth install_sub');

  is_deeply(
    $sub_ref,
    \&Other::Another::foo,
    'it returns the correct code ref'
  );

  is(
    Other::Another->foo,
    'Other::Another',
    'the original code does what we want',
  );

  is(
    Other::YetAnother->return_lhs,
    'Other::YetAnother',
    'and the installed code works, too',
  );
}
