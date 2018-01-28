package SmartPathing::Grid;

use strict;
use Carp::Assert;
use Scalar::Util;
use List::MoreUtils;
use Globals;
use Utils;
use Log qw(message error debug);
use Misc;


sub new {
	my ($class, $height, $width, $mob_binID) = @_;
	
	my $self = bless {}, $class;
	
	$self->{height} = $height;
	$self->{width} = $width;
	$self->{mob_binID} = $mob_binID;
	
	$self->{grid_changes} = {};
	
	$self->create_grid();
	
	return $self;
}

sub create_grid {
	my ($self) = @_;
	my $monster = $monstersList->get($self->{mob_binID});
	my $obs_x = $monster->{pos}{x};
	my $obs_y = $monster->{pos}{y};
	
	for (my $y = ($obs_y - 14);     ($y <= ($obs_y + 14) && $y < $self->{height});   $y++) {
		for (my $x = ($obs_x - 14);     ($x <= ($obs_x + 14) && $x < $self->{width});   $x++) {
			$self->{grid_changes}{($y * $self->{width} + $x)} = get_added_weight($obs_x, $obs_y, $x, $y);
		}
	}
}

sub update {
	my ($self) = @_;
	$self->{grid_changes} = {};
	$self->create_grid();
}

sub get_added_weight {
	my ($obs_x, $obs_y, $cell_x, $cell_y) = @_;
	
	my $xDistance = abs($obs_x - $cell_x);
    my $yDistance = abs($obs_y - $cell_y);
	my $cell_distance = (($xDistance > $yDistance) ? $xDistance : $yDistance);
	
	my @weights = (50, 50, 50, 15, 10, 5);
	
	my $weight_change;
	
	if ($cell_distance <= $#weights) {
		$weight_change = $weights[$cell_distance];
		
	} else {
		$weight_change = 0;
	}
	
	return $weight_change;
}

1;