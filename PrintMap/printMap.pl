package printMap;

use lib $Plugins::current_plugin_folder;

use strict;
use Time::HiRes qw( &time );
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning debug);
use File::Spec;
use GD;

Plugins::register('printMap', 'allows usage of printMaps', \&Unload);

our $folder = $Plugins::current_plugin_folder;

my $chooks = Commands::register(
	['printMap', "printMap plugin", \&commandHandler]
);


sub Unload {
	message "[printMap] Plugin unloading\n", "system";
	Commands::unregister($chooks);
}

sub commandHandler {
	### no parameter given
	if (!defined $_[1]) {
		message "usage: printMap map fromX fromY toX toy avoid\n", "list";
		return;
	}
	
	my ( $arg, @params ) = parseArgs( $_[1] );
	
	my $move_field = new Field(name => $arg);
	
	my $from = {
		x => $params[0],
		y => $params[1]
	};
	my $to = {
		x => $params[2],
		y => $params[3]
	};
	
	my $solution = [];
	my $dist_path = new PathFinding(
		field => $move_field,
		start => $from,
		dest => $to,
		avoidWalls => $params[4]
	)->run($solution);
	
	my %all;
	foreach my $current (@{$solution}) {
		$all{$current->{x}}{$current->{y}} = 1;
	}
	
	my $im = new GD::Image($move_field->width, $move_field->height);
	
	my $white = $im->colorAllocate(255,255,255);
	my $black = $im->colorAllocate(0,0,0);       
	my $red = $im->colorAllocate(255,0,0);  

	foreach my $y (0..($move_field->height - 1)) {
		foreach my $x (0..($move_field->width - 1)) {
			if (exists $all{$x} && exists $all{$x}{$y}) {
				$im->setPixel($x,invert_y($y, $move_field->height),$red);
			} elsif ($move_field->isWalkable($x,$y)) {
				$im->setPixel($x,invert_y($y, $move_field->height),$white);
			} else {
				$im->setPixel($x,invert_y($y, $move_field->height),$black);
			}
		}
	}
	
	my $png_data = $im->png;
	
	open IMG, ">:raw", "prob1.png";
	binmode IMG;
	print IMG $png_data;
	close IMG;
}

sub invert_x {
	my ($x, $width) = @_;
	return $x;
}

sub invert_y {
	my ($y, $height) = @_;
	return ($height - $y);
}


1;