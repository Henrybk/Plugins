##############################
# =======================
# BetterWalkPlan v3
# =======================
# This plugin is licensed under the GNU GPL
# Created by Henrybk from openkore brasil
# Based on the waypoint (made by d3fc0n https://forums.openkore.com/viewtopic.php?t=725) and planwalk (made by sofax222 https://forums.openkore.com/viewtopic.php?t=13558)
#
#
# What it does: Plan your lockmap traversing on a config file, now with JSON
#
# Config keys (put in config.txt):
#	BetterShopper_on 1
#
# config files:
#	walk.json
#
# Recommended json validator:
#	https://jsonformatter.curiousconcept.com/#
#
###############################################
package BetterWalkPlan;

use strict;
use Plugins;
use Globals;
use Utils;
use Misc;
use AI;
use Log qw(debug message warning error);
use Translation;
use File::Spec;
use JSON::Tiny qw(from_json to_json);

use List::Util qw(shuffle);

my $planStep = 0;
my $reverseOnEnd = 0;
my $file_handle;
my $betterWalk_file = "walk.json";
my %walkMaps;

Plugins::register('BetterWalkPlan', 'New and revised waypoint/planwalk', \&on_unload, \&on_unload);

my $hooks = Plugins::addHooks(
	['configModify',			\&on_configModify],
	['ai_processRandomWalk',	\&on_ai_processRandomWalk],
);

sub on_unload {
	Plugins::delHooks($hooks);
	Settings::removeFile($file_handle) if (defined $file_handle);
	undef $file_handle;
	undef $betterWalk_file;
	undef $planStep;
	undef $reverseOnEnd;
	undef %walkMaps;
}

sub on_configModify {
	my (undef, $args) = @_;
	if ($args->{key} eq 'BetterWalkPlan') {
		$planStep = 0;
		$reverseOnEnd = 0;
		
	} elsif ($args->{key} eq 'lockMap') {
		$planStep = 0;
		$reverseOnEnd = 0;
	}
}

sub loadFiles {
	$file_handle = setLoad($betterWalk_file);
	Settings::loadByHandle($file_handle);
}

sub setLoad {
	my $file = shift;
	my $handle = Settings::addControlFile(
		$file,
		loader => [\&parseWalkPlan, \%walkMaps],
		internalName => 'walk.json',
		mustExist => 0
	);
	return $handle;
}

sub parseWalkPlan {
	my $file = shift;
	my $r_hash = shift;

	open FILE, "<:utf8", $file;
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	my $jsonString = join('',@lines);

	my %converted = %{from_json($jsonString, { utf8  => 1 } )};

	%{$r_hash} = %converted;
	return 1;
}

sub on_ai_processRandomWalk {
	my (undef, $args) = @_;
	
	my $field_name = $field->baseName;
	if ($config{BetterWalkPlan} && exists($walkMaps{$field_name}) && timeOut($walkMaps{$field_name})) {
		
		if (!exists $walkMaps{$field_name}{traversingOrder}) {
			$planStep = 0;
			$reverseOnEnd = 0;
		}
		
		if ($planStep == 0) {
			@{$walkMaps{$field_name}{traversingOrder}} = (0..$#{$walkMaps{$field_name}{instructions}});
			if ($walkMaps{$field_name}{random} == 1) {
				@{$walkMaps{$field_name}{traversingOrder}} = shuffle(@{$walkMaps{$field_name}{traversingOrder}});
			}
			message ("[BetterWP] Traversing order will be ".(join(' ', @{$walkMaps{$field_name}{traversingOrder}}))."\n", "route");
		}
		
		my $traverseStep = $walkMaps{$field_name}{traversingOrder}[$planStep];
		my $step = $walkMaps{$field_name}{instructions}[$traverseStep];
		my $routeX = $step->{x};
		my $routeY = $step->{y};
		
		my $again = 0;
		if (!$field->isWalkable($routeX, $routeY)) {
			error "Invalid coordinates specified (".$routeX.", ".$routeY.") for BetterWalkPlan (coordinates are unwalkable); step $planStep of plan: ".$field->descString()."\n";
			#configModify('BetterWalkPlan', 0);
			$again = 1;
		} else {
			message ("[BetterWP] Following step $traverseStep of plan to: ".$field->descString().": ".$routeX.", ".$routeY."\n", "route");
			ai_route(
				$field_name, $routeX, $routeY, 
				maxRouteTime => $config{route_randomWalk_maxRouteTime},
				attackOnRoute => 2,
				noMapRoute => ($config{route_randomWalk} == 2 ? 1 : 0),
				isRandomWalk => 1
			);
		}
		if (
			   ($planStep == $#{$walkMaps{$field_name}{instructions}} && !$walkMaps{$field_name}{reverseOnEnd})
			|| ($planStep == 0 && $reverseOnEnd == 1)
		) {
			$walkMaps{$field_name}{time} = time;
			$planStep = 0;
			$reverseOnEnd = 0;
			
		} elsif ($planStep == $#{$walkMaps{$field_name}{instructions}} && $walkMaps{$field_name}{reverseOnEnd}) {
			$planStep--;
			$reverseOnEnd = 1;
			
		} else {
			if ($reverseOnEnd == 0) { $planStep++; } else { $planStep--; };
		}
		if ($again == 0) {
			$args->{return} = 1;
		} else {
			on_ai_processRandomWalk(undef, $args);
		}
	}
}

loadFiles();

1;