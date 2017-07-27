package SmartPathing::GridLists;

use strict;
use Carp::Assert;
use Utils::ObjectList;
use base qw(ObjectList);

use SmartPathing::Grid;

sub new {
	my ($class, $type) = @_;
	assert(defined $type) if DEBUG;
	assert(UNIVERSAL::isa($type, "Grid")) if DEBUG;

	my $self = $class->SUPER::new();

	$self->{AL_type} = $type;
	
	$self->{MobBindID} = {};

	return $self;
}

sub DESTROY {
	my ($self) = @_;
	$self->clear();
}

sub add {
	my ($self, $grid) = @_;
	assert(defined $grid) if DEBUG;
	assert($grid->isa($self->{AL_type})) if DEBUG;
	assert(defined $grid->{mob_binID}) if DEBUG;
	assert($self->find($grid) == -1) if DEBUG;

	my $binID = $self->SUPER::add($grid);
	$grid->{binID} = $binID;

	my $indexSlot = $self->getMobBindIDSlot($grid->{mob_binID});
	push @{$indexSlot}, $binID;
	
	return $binID;
}

sub remove {
	my ($self, $grid) = @_;
	assert(defined $grid) if DEBUG;
	assert(UNIVERSAL::isa($grid, $self->{AL_type})) if DEBUG;
	assert(defined $grid->{mob_binID}) if DEBUG;

	my $result = $self->SUPER::remove($grid);
	if ($result) {
		my $indexSlot = $self->getMobBindIDSlot($grid->{mob_binID});

		if (@{$indexSlot} == 1) {
			delete $self->{MobBindID}{$grid->{mob_binID}};
		} else {
			for (my $i = 0; $i < @{$indexSlot}; $i++) {
				if ($indexSlot->[$i] == $grid->{binID}) {
					splice(@{$indexSlot}, $i, 1);
					last;
				}
			}
		}
	}
	return $result;
}

sub removeByMobBinID {
	my ($self, $MobBindID) = @_;
	my $grid = $self->getByMobBinID($MobBindID);
	if (defined $grid) {
		return $self->remove($grid);
	} else {
		return 0;
	}
}

sub getByMobBinID {
	my ($self, $MobBindID) = @_;
	assert(defined $MobBindID) if DEBUG;
	my $indexSlot = $self->{MobBindID}{$MobBindID};
	if ($indexSlot) {
		return $self->get($indexSlot->[0]);
	} else {
		return undef;
	}
}

sub getMobBindIDSlot {
	my ($self, $mob_bindID) = @_;
	return $self->{MobBindID}{$mob_bindID} ||= [];
}

1;
