package BetterWalkPlan;

use strict;
use Globals;
use Utils;
use Misc;
use AI;
use Log qw(debug message warning error);
use Translation;
use File::Spec;
use JSON::Tiny qw(from_json to_json);

my $planStep = 0;
my $reverseOnEnd = 0;
my $file_handle;
my $betterWalk_file = "walk.json";
my %walkMaps;

Plugins::register('BetterWalkPlan', 'Revised waypoint/planwalk 3.0', \&on_unload, \&on_unload);

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
	if ($args->{key} eq 'betterWalkPlan') {
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
	if ($config{betterWalkPlan} && exists($walkMaps{$field_name}) && timeOut($walkMaps{$field_name})) {
		
		my $step = $walkMaps{$field_name}{instructions}[$planStep];
		my $routeX = $step->{x};
		my $routeY = $step->{y};
		
		my $again = 0;
		if (!$field->isWalkable($routeX, $routeY)) {
			error "Invalid coordinates specified (".$routeX.", ".$routeY.") for BetterWalkPlan (coordinates are unwalkable); step $planStep of plan: ".$field->descString()."\n";
			#configModify('betterWalkPlan', 0);
			$again = 1;
		} else {
			message ("[BetterWP] Following step $planStep of plan to: ".$field->descString().": ".$routeX.", ".$routeY."\n", "route");
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