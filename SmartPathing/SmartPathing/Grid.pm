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
		for (my $x = ($obs_x - 14); ($x <= ($obs_x + 14) && $x < $self->{width});    $x++) {
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
	my $distace = int (distance( { x => $obs_x, y => $obs_y} , { x => $cell_x, y => $cell_y} ));
	
	my $new_dist;
	
	if ($distace <= 3) {
		$new_dist = 1;
		
	} elsif ($distace <= 5) {
		$new_dist = 2;
		
	} elsif ($distace <= 7) {
		$new_dist = 3;
		
	} else {
		$new_dist = $distace;
	}
	
	return $new_dist;
}

1;
#eval message sprintf "%s\n", ord substr $field->{dstMap}, $field->width * 289 + 90