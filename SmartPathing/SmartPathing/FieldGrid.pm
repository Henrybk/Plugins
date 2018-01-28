package SmartPathing::FieldGrid;

use strict;
use Globals;
use Utils;
use Log qw(message error debug);
use Misc;

use SmartPathing::GridLists;
use SmartPathing::Grid;

sub new {
	my ($class) = @_;
	
	my $self = bless {}, $class;
	
	$self->reset_all_vars;
	
	return $self;
}

sub reset_all_vars {
	my ($self) = @_;
	$self->{field} = undef;
	
	$self->{height} = undef;
	$self->{width} = undef;
	
	$self->{grids_list} = new SmartPathing::GridLists('SmartPathing::Grid');
	
	$self->{current_mother_grid} = undef;
	
	$self->{current_final_grid} = undef;
}

sub set_mother_grid_field {
	my ($self, $field) = @_;
	
	if (defined $self->{field}) {
		$self->reset_all_vars;
	}
	
	$self->{field} = $field;
	
	$self->{height} = $field->{height};
	$self->{width} = $field->{width};
	
	$self->set_mother_grid;
}

sub set_mother_grid {
	my ($self) = @_;
	$self->{current_mother_grid} = $self->{field}{weightMap};
	$self->{current_final_grid} = $self->{current_mother_grid};
}

sub add_mob_obstacle {
	my ($self, $mob_binID) = @_;
	my $grid = new SmartPathing::Grid($self->{height}, $self->{width}, $mob_binID);
	$self->{grids_list}->add($grid);
	$self->add_grid($grid);
}

sub remove_mob_obstacle {
	my ($self, $mob_binID) = @_;
	my $grid = $self->{grids_list}->getByMobBinID($mob_binID);
	$self->{grids_list}->remove($grid);
	$self->remove_grid($grid);
}

sub update_mob_obstacle {
	my ($self, $mob_binID) = @_;
	my $grid = $self->{grids_list}->getByMobBinID($mob_binID);
	$self->remove_grid($grid);
	$grid->update();
	$self->add_grid($grid);
}

sub add_grid {
	my ($self, $grid) = @_;
	foreach my $position (keys %{$grid->{grid_changes}}) {
		my $current_weight = unpack('C', substr($self->{current_final_grid}, $position, 1));
		next if ($current_weight == 0);
		
		my $weight_changed = $grid->{grid_changes}{$position};
		
		my $new_weight = $current_weight + $weight_changed;
		
		substr($self->{current_final_grid}, $position, 1, pack('C', $new_weight));
	}
}

sub remove_grid {
	my ($self, $grid) = @_;
	foreach my $position (keys %{$grid->{grid_changes}}) {
		my $current_weight = unpack('C', substr($self->{current_final_grid}, $position, 1));
		next if ($current_weight == 0);
		
		my $weight_changed = $grid->{grid_changes}{$position};
		
		my $new_weight = $current_weight - $weight_changed;
		
		substr($self->{current_final_grid}, $position, 1, pack('C', $new_weight));
	}
}

sub get_final_grid {
	my ($self) = @_;
	return $self->{current_final_grid};
}

1;
