use Sub::Install qw(reinstall_sub);
use Test::More 'no_plan';

use strict;
use warnings;

# These tests largely copied from Damian Conway's Sub::Installer tests.

{ # Install a sub in a package...

  my $sub_ref = reinstall_sub({ code => \&ok, as => 'ok1' });

  isa_ok($sub_ref, 'CODE', 'return value of first install_sub');

  is_deeply($sub_ref, \&Test::More::ok, 'it returned the right coderef');

  $sub_ref->(1, 'returned code ref runs');
  ok1(1, "reinstalled sub runs");
}

{ # Install the same sub in the same package...
  local $SIG{__WARN__}
    = sub { fail("warned unexpected: @_") if $_[0] =~ /redefined/ };

  my $sub_ref = reinstall_sub({ code => \&is, as => 'ok1' });

  isa_ok($sub_ref, 'CODE', 'return value of second install_sub');

  is_deeply($sub_ref, \&Test::More::is, 'it returned the right coderef');

  $sub_ref->(1, 1, 'returned code ref runs');
  ok1(1,1, 'reinstalled sub reruns');
}

{ # Install in another package...
  my $new_code = sub { ok(1, "remotely installed sub runs") };

  my $sub_ref = reinstall_sub({
    code => $new_code,
    into => 'Other',
    as   => 'ok1',
  });

  isa_ok($sub_ref, 'CODE', 'return value of third install_sub');

  is_deeply($sub_ref, $new_code, 'it returned the right coderef');

  ok1(1,1, 'reinstalled sub reruns');

  package Other;
  ok1();
}
