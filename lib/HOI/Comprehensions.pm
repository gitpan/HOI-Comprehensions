package HOI::Comprehensions;

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw( comp get_member get_list is_over );
our $VERSION = '0.02';

use Alias qw(attr);

sub comp {
    my $computation = shift;
    my $generators_ = \@_;
    sub {
        my @guards = @_;
        my %generators;
        my ($evalstr, $postfix) = ("", "");
        while ($#$generators_ > -1) {
            my ($key, $value) = (shift @$generators_, shift @$generators_);
            $evalstr .= '$self->{generators}->{'.$key.'}->(';
            $postfix .= ')';
            $generators{$key} = 
                (ref($value) eq 'ARRAY') ? 
                    sub { 
                        my $idx = 0; 
                        sub { 
                            if ($#_ == -1) {
                                my $last_ret = { $key => $value->[$idx] };
                                $idx++;
                                my $last_done = ($idx > $#$value);
                                $idx %= ($#$value + 1);
                                return ($last_done, $last_ret);
                            }
                            my ($done, $res) = @_;
                            my $ret = { %$res, $key => $value->[$idx] };
                            $idx++ if ($done);
                            my $self_done = ($idx > $#$value);
                            $idx %= ($#$value + 1);
                            ($self_done, $ret);
                        } 
                    }->() : 
                    sub { 
                        if ($#_ == -1) {
                            my ($last_done, $last_res) = $value->();
                            return ($last_done, { $key => $last_res });
                        }
                        my ($done, $res) = @_;
                        my ($self_done, $self_res) = $value->();
                        my $ret = { %$res, $key => $self_res };
                        ($self_done * $done, $ret);
                    };
        }
        bless
        { 
            computation => $computation, 
            generators => \%generators, 
            all_done => 0,
            geneitr => $evalstr.$postfix,
            guards => \@guards, 
            list => [],
            caller => caller()
        }
    }
}

sub get_member {
    my ($self, $name) = @_;
    $self->{$name}
}

sub get_list {
    my ($self) = @_;
    $self->get_member('list')
}

sub is_over {
    my ($self) = @_;
    $self->get_member('all_done')
}

sub step_next_lazy {
    my ($self, $flag) = @_;
    return ($self->{list}, 1) if ($self->{all_done});
    my ($done, $arguments) = eval $self->{geneitr};
    $self->{all_done} = $done;
    my ($package_name) = $self->{caller};
    local $Alias::AttrPrefix = $package_name.'::';
    attr $arguments;
    %switches = (
        full => sub { 
            my $guards_ok = 1; 
            ($_->($arguments) or $guards_ok = 0) for (@{$self->{guards}}); 
            push @{$self->{list}}, $self->{computation}->($arguments) if ($guards_ok); 
            $guards_ok 
        },
        #cdr => sub { $self->{computation}->($arguments) },
    );
    my $guard = $switches{$flag}->();
    ($self->{list}, $done, $guard)
}

sub next { 
    my ($l_, $done, $guard);
    #print "cnt to $_[1]\n";
    for my $cnt (0..$_[1]) {
        do {
            ($l_, $done, $guard) = $_[0]->step_next_lazy('full'); 
        } until ($done or $guard);
    }
    ($l_->[$#$l_], $done, $guard)
}

use overload
    '<>' => sub { $_[0]->next(0) },
    '+' => 
    sub { 
        #print(scalar(@{$_[0]->{list}}), ' ', $_[1], "\n"); 
        my @ret = (scalar(@{$_[0]->{list}}) - 1 >= $_[1]) ? ($_[0]->{list}->[$_[1]], $_[0]->{all_done}) : ($_[0]->next($_[1] - scalar(@{$_[0]->{list}}))); 
        \@ret 
    },
    ;

1;

__END__

=head1 NAME

HOI::Comprehensions - Higher-Order Imperative "Re"features in Perl: List Comprehensions

=head1 SYNOPSIS

  use HOI::Comprehensions qw( comp );

  my $list = comp( sub { $x + $y + $z }, x => [ 1, 2, 3 ], y => [ 4, 5, 6 ], z => sub { ( 1, 1 ) } )->( sub { $x > 1 } );

  my ($elt, $done);
  do {
      ($elt, $done) = <$list>;
      print "$elt ";
  } while (not $done);
  print "\n";

=head1 DESCRIPTION

HOI::Comprehensions offers lazy-evaluated list comprehensions with limited support to 
generators of an infinite list. It works as if evaluating multi-level loops lazily.

Currently, the generators are handled in sequence of the argument list offered by the user.
As a result of such implementation, a list
    { (x, y) | x is natural number, y belongs to { 0, 1 }, x is odd }
may be evaluated incorrectly. To avoid such situation, make sure finite generators 
are subsequent to all the infinite ones.

=head1 FUNCTIONS

=head2 comp($@)->(@)

For creating a list comprehension object. The formula for computing the elements of
the list is given as a subroutine, following by the generators, in form of name => arrayref
or name => subroutine. Comp returns a function which takes all guards in form of subroutines.

A hashref which holds generator variables as its keys and value of those variables as
its values is passed to the formula subroutine. However, it is recommended to use such
variables directly instead of dereference the hashref.

Generators can be arrayrefs or subroutines. A subroutine generator should return a
pair ( elt, done ), where elt is the next element and done is a flag telling whether
the iteration is over.

=head1 METHODS

=head2 get_list

Get the list member of a list comprehension object. It returns a arrayref which holds
the actual list evaluated so far.

=head2 is_over

Returns a boolean which tells if the evaluation of the list is over.

=head2 get_member($)

Get a member of a list comprehension object by name.
A list comprehension object is actually a blessed hashref.

=head1 OPERATORS

=head2 <>

List evaluation iterator. Returns the "next" element generated in the sequence in the 
situation of eager evaluation, and a flag telling whether the evaluation is done.

=head2 +

List indexing operator. Takes an integer as the index and a list comprehension object.
The operator returns an arrayref [ $elt, $done ], where $elt is the element at the given
index and $done is a flag telling whether the evaluation is done.

=head1 AUTHOR

withering <withering@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by withering

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.20.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
