#!/usr/bin/env perl
# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl HOI-Comprehensions.t'

#########################

use Test::More qw(no_plan);
BEGIN { use_ok('HOI::Comprehensions') };

#########################

my $list = HOI::Comprehensions::comp( sub { $x + $y + $z }, x => [ 1, 2, 3 ], y => [ 4, 5, 6 ], z => sub { ( 1, 1 ) } )->( sub { $x > 1 } );
my ($elt, $done);
do {
    ($elt, $done) = <$list>;
} while (not $done);

my $target = [];
for my $i (2..3) {
    for my $j (4..6) {
        push @$target, $i + $j + 1;
    }
}
is_deeply($target, $list->get_list, "eq");

$done = 0;
my $cnt_done = 0;
for (my $idx = 0; $idx < 6; $idx++) {
    ($elt, $done) = @{$idx + $list};
    $cnt_done += $done;
}
ok($cnt_done == 6);

done_testing(3);
