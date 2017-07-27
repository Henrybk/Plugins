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
			my $pos = $y * $self->{width} + $x;
			my $added_weight = get_added_weight($obs_x, $obs_y, $x, $y);
			$self->{grid_changes}{$pos} = $added_weight;
		}
	}
}

sub get_added_weight {
	my ($obs_x, $obs_y, $cell_x, $cell_y) = @_;
	my $distace = blockDistance( { x => $obs_x, y => $obs_y} , { x => $cell_x, y => $cell_y} );
	
	my $test_w = (15 - $distace);
	
	return $test_w;
}

1;
