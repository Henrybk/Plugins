package BetterWalkPlan;

use strict;
use Globals;
use Utils;
use Misc;
use AI;
use Log qw(debug message warning error);
use Translation;

my $planStep = 0;
my $cfID;
my $betterWalk_file;
my $reverse = 0;
my %walkMaps;

Plugins::register('BetterWalkPlan', 'Revised waypoint/planwalk 3.0', \&on_unload, \&on_unload);

my $hooks = Plugins::addHooks(
	['configModify', \&on_configModify, undef],
	['start3', \&on_start3, undef]
);

my $chooks = Commands::register(
	['planwalk', "BetterWalkPlan", \&commandHandler]
);

sub on_unload {
	Plugins::delHooks($hooks);
}

sub on_configModify {
	my (undef, $args) = @_;
	if ($args->{key} eq 'betterWalk_file') {
		$betterWalk_file = $args->{val};
		Settings::removeFile($cfID);
		$cfID = Settings::addControlFile($betterWalk_file, loader => [ \&parseWalkPlan, undef]);
		Settings::loadByHandle($cfID);
		$planStep = 0;
	} elsif ($args->{key} eq 'betterWalkPlan' && $args->{val} == 0) {
		$planStep = 0;
	}
}

sub on_start3 {
	$betterWalk_file = (defined $config{betterWalk_file})? $config{betterWalk_file} : "betterwalk.txt";
	Settings::removeFile($cfID) if ($cfID);
	$cfID = Settings::addControlFile($betterWalk_file, loader => [ \&parseWalkPlan], mustExist => 0);
	Settings::loadByHandle($cfID);
}

sub parseWalkPlan {
	my $file = shift;
	undef %walkMaps;
	my ($openBlock, $map, $counter, $mapFile);
	if ($file) {
		open my $plan, "<:utf8", $file;
		while (<$plan>) {
			$. == 1 && s/^\x{FEFF}//;
			s/(.*)[\s\t]+#.*$/$1/;
			s/^\s*#.*$//;
			s/^\s*//;
			s/\s*[\r\n]?$//g;
			s/  +/ /g;
			next unless ($_);
			if ($openBlock) {
				if (/^}$/) {
					if (exists($walkMaps{$map}{X})) {
						$walkMaps{$map}{reverse} = 0 if (!exists($walkMaps{$map}{reverse}));
						$walkMaps{$map}{timeout} = 0 if (!exists($walkMaps{$map}{timeout}));
						$walkMaps{$map}{time} = 0;
					} else {
						delete $walkMaps{$map};
						error T("No plan specified for map $map (Ignoring block)\n");
					}
					$map = ();
					$openBlock = 0;
				} elsif (/^(\d+)(\[(\d+)\])?:(\d+)(\[(\d+)\])?$/) {
					if ($3) { $walkMaps{$map}{randX}[$counter] = $3; } else { $walkMaps{$map}{randX}[$counter] = 0; };
					if ($6) { $walkMaps{$map}{randY}[$counter] = $6; } else { $walkMaps{$map}{randY}[$counter] = 0; };
					$walkMaps{$map}{X}[$counter] = $1;
					$walkMaps{$map}{Y}[$counter] = $4;
					$counter++;
				} elsif (/^reverseend\s(\d+)$/i) {
					if ($1 != 0 && $1 != 1) { error T("Unsupported value $1 for ReverseEnd at $. (Set to 0)\n"); } else { $walkMaps{$map}{reverse} = $1; }
				} elsif (/^timeout\s(\d+)$/i) {
					$walkMaps{$map}{timeout} = $1;
				} else {
					delete $walkMaps{$map};
					$openBlock = 0;
					$map = ();
					error T("Unkown sintax at line $. (Ignoring block)\n");
				}
			} elsif (/^map (.+) {$/i) {
				$mapFile = $1.'.fld';
				$mapFile = File::Spec->catfile($Settings::fields_folder, $mapFile) if ($Settings::fields_folder);
				$mapFile .= ".gz" if (! -f $mapFile);
				if ($maps_lut{"${1}.rsw"} || -f $mapFile) {
					$openBlock = 1;
					$counter = 0;
					$map = $1;
				} else {
					error T("Unkown map at line $. (Ignoring block)\n");
				}
			}
		}
		close($plan);
	}
}

*AI::CoreLogic::processRandomWalk = sub {
	if (AI::isIdle && (AI::SlaveManager::isIdle()) && $config{route_randomWalk} && !$ai_v{sitAuto_forcedBySitCommand}
		&& (!$field->isCity || $config{route_randomWalk_inTown})
		&& length($field->{rawMap}) 
		){
		if ($config{betterWalkPlan} && exists($walkMaps{$field->baseName}) && timeOut($walkMaps{$field->baseName}{timeout}, $walkMaps{$field->baseName}{time})) {
			if ($config{'lockMap_x'} || $config{'lockMap_randX'} || $config{'lockMap_y'} || $config{'lockMap_randY'}) {
				error T("betterWalkPlan doesn't work with coordinate lockmap; BetterWalkPlan disabled\n");
				configModify('betterWalkPlan', 0);
			} else {
				my ($routeX, $routeY);
				if ($walkMaps{$field->baseName}{randX}[$planStep] == 0 && $walkMaps{$field->baseName}{randY}[$planStep] == 0) {
					($routeX, $routeY) = ($walkMaps{$field->baseName}{X}[$planStep], $walkMaps{$field->baseName}{Y}[$planStep]);
					if ($field->isWalkable($routeX, $routeY)) {
						message ("[BetterWP] Following ".($planStep+1)."th step of plan to: ".$field->descString().": ".$routeX.", ".$routeY."\n", "route");
						ai_route($field->baseName, $routeX, $routeY, 
							maxRouteTime => $config{route_randomWalk_maxRouteTime},
							attackOnRoute => 2,
							noMapRoute => ($config{route_randomWalk} == 2 ? 1 : 0));
					} else {
						error TF("Invalid coordinates specified (%d, %d) for BetterWalkPlan (coordinates are unwalkable); BetterWalkPlan disabled\n", $routeX, $routeY);
						configModify('betterWalkPlan', 0);
					}
				} else {
					my $i = 500;
					do {
						$routeX = $walkMaps{$field->baseName}{X}[$planStep] if ($char->{pos}{x} == $walkMaps{$field->baseName}{X}[$planStep] && !($walkMaps{$field->baseName}{randX}[$planStep] > 0));
						$routeX = $walkMaps{$field->baseName}{X}[$planStep] - $walkMaps{$field->baseName}{randX}[$planStep] + int(rand(2*$walkMaps{$field->baseName}{randX}[$planStep]+1)) if ($walkMaps{$field->baseName}{X}[$planStep] ne '' && $walkMaps{$field->baseName}{randX}[$planStep] >= 0);
						$routeY = $walkMaps{$field->baseName}{Y}[$planStep] if ($char->{pos}{y} == $walkMaps{$field->baseName}{Y}[$planStep] && !($walkMaps{$field->baseName}{randY}[$planStep] > 0));
						$routeY = $walkMaps{$field->baseName}{Y}[$planStep] - $walkMaps{$field->baseName}{randY}[$planStep] + int(rand(2*$walkMaps{$field->baseName}{randY}[$planStep]+1)) if ($walkMaps{$field->baseName}{Y}[$planStep] ne '' && $walkMaps{$field->baseName}{randY}[$planStep] >= 0);
					} while (--$i && (!$field->isWalkable($routeX, $routeY) || $routeX == 0 || $routeY == 0));
					if (!$i) {
						error TF("Invalid coordinates specified (%d, %d) for BetterWalkPlan (coordinates are unwalkable); BetterWalkPlan disabled\n", $routeX, $routeY);
						configModify('betterWalkPlan', 0);
					} else {
						message ("[BetterWP] Following ".($planStep+1)."th step of plan to: ".$field->descString().": ".$routeX.", ".$routeY."\n", "route");
						ai_route($field->baseName, $routeX, $routeY, 
							maxRouteTime => $config{route_randomWalk_maxRouteTime},
							attackOnRoute => 2,
							noMapRoute => ($config{route_randomWalk} == 2 ? 1 : 0));
					}
				}
				if ($walkMaps{$field->baseName}{timeout} && (($planStep+1 == @{$walkMaps{$field->baseName}{X}} && !$walkMaps{$field->baseName}{reverse})||($planStep == 0 && $reverse == 1))) {
						$walkMaps{$field->baseName}{time} = time;
						$planStep = 0;
						$reverse = 0;
				} elsif ($planStep+1 == @{$walkMaps{$field->baseName}{X}}) {
					if ($walkMaps{$field->baseName}{reverse}) {
						$planStep--;
						$reverse = 1;
					} else {
						$planStep = 0;
					}
				} elsif ($planStep == 0 && $reverse == 1) {
					$planStep++;
					$reverse = 0;
				} else {
					if ($reverse == 0) { $planStep++; } else { $planStep--; };
				}
			}
		} else {
			if($char->{pos}{x} == $config{'lockMap_x'} && !($config{'lockMap_randX'} > 0) && ($char->{pos}{y} == $config{'lockMap_y'} && !($config{'lockMap_randY'} >0))) {
				error T("Coordinate lockmap is used; randomWalk disabled\n");
				configModify('route_randomWalk', 0);
				return;
			}
			my ($randX, $randY);
			my $i = 500;
			do {
				$randX = int(rand($field->width-1)+1);
				$randX = $config{'lockMap_x'} if ($char->{pos}{x} == $config{'lockMap_x'} && !($config{'lockMap_randX'} > 0));
				$randX = $config{'lockMap_x'} - $config{'lockMap_randX'} + int(rand(2*$config{'lockMap_randX'}+1)) if ($config{'lockMap_x'} ne '' && $config{'lockMap_randX'} >= 0);
				$randY = int(rand($field->height-1)+1);
				$randY = $config{'lockMap_y'} if ($char->{pos}{y} == $config{'lockMap_y'} && !($config{'lockMap_randY'} > 0));
				$randY = $config{'lockMap_y'} - $config{'lockMap_randY'} + int(rand(2*$config{'lockMap_randY'}+1)) if ($config{'lockMap_y'} ne '' && $config{'lockMap_randY'} >= 0);
			} while (--$i && (!$field->isWalkable($randX, $randY) || $randX == 0 || $randY == 0));
			if (!$i) {
				error T("Invalid coordinates specified for randomWalk (coordinates are unwalkable); randomWalk disabled\n");
				configModify('route_randomWalk', 0);
			} else {
				message TF("Calculating random route to: %s: %s, %s\n", $field->descString(), $randX, $randY), "route";
				ai_route($field->baseName, $randX, $randY,
					maxRouteTime => $config{route_randomWalk_maxRouteTime},
					attackOnRoute => 2,
					noMapRoute => ($config{route_randomWalk} == 2 ? 1 : 0) );
			}
		}
	}
};

sub commandHandler {
	### no parameter given
	if (!defined $_[1]) {
		message "[PlanWalk] usage: planwalk [list|conf]\n", "list";
		message "planwalk conf <map> [<steps|timeout|reverseend>] [<value>]: changes a config on planwalk file\n".
			"planwalk (map): show plan for given map\n".
			"planwalk list: list available plans\n";
		return;
	}
	my ($arg, @params) = split(/\s+/, $_[1]);
	### parameter: list
	if ($arg eq 'list') {
		message(sprintf("The following plans are available:\n"), "list");
		foreach my $m (keys %walkMaps) {message "$m\n"}
	### parameter: conf
	} elsif ($arg eq 'conf') {
		if (@params != 3) {
			error "[PlanWalk] Syntax Error in function conf. Not found <map>\n".
				"Usage: planwalk conf <map> [<steps|timeout|reverseend>] [<value>]\n";
		} else {
			if (!exists($walkMaps{$params[0]})) {
				error "[PlanWalk] Given map for conf not found <map>\n";
			} else {
				if ($params[1] eq 'timeout' && $params[2] !~ /\d+/) {
					error "[PlanWalk] Invalid value for Timeout\n";
					return;
				} elsif ($params[1] eq 'reverseend' && $params[2] !~ /(0|1)/) {
					error "[PlanWalk] Invalid value for ReverseEnd\n";
					return;
				} elsif ($params[1] eq 'steps') {
					my @newsteps = split(/-/,$params[2]);
					foreach my $newstep (@newsteps) {
						unless ($newstep =~ /^(\d+)(\[(\d+)\])?:(\d+)(\[(\d+)\])?$/) {
							error "[PlanWalk] Invalid value for steps\n";
							return;
						}
					}
				} elsif ($params[1] ne 'steps' && $params[1] ne 'reverseend' && $params[1] ne 'timeout') {
					error "[PlanWalk] Invalid key for conf\n"; 
					return;
				}
				&FileWrite($params[0], $params[1], $params[2]);
			}
		}
	### parameter: probably a plan
	} else {
		if (!exists($walkMaps{$arg})) {
			message ("[PlanWalk] There is no plan for this map.\n","info");
		} else {
			message ("[PlanWalk] Plan for $arg.\n","info");
			for (my $o = 0; $o < @{$walkMaps{$arg}{X}}; $o++) {
			message ("$o - @{$walkMaps{$arg}{X}}[$o]+-@{$walkMaps{$arg}{randX}}[$o] @{$walkMaps{$arg}{Y}}[$o]+-@{$walkMaps{$arg}{randY}}[$o].\n","info");
			}
		}
	}
}

sub FileWrite {
	my ($map, $key, $value) = @_;
	my ($Found, $StepsIndex, $StartStepIndex, $EndStepIndex);
	my $spaces;#just to keep things organized
	my $controlfile = Settings::getControlFilename($betterWalk_file);
	open(FILE, "<:utf8", $controlfile);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	foreach my $line (@lines) {
		message "Line: $line\n";
		if ($Found) {
			if ($line =~ /}/) {
				if ($key eq 'steps') {
					if ($spaces) {
						$value =~ s/-/\n$spaces/ig;
						$line =~ s/}/$spaces$value\n}/i;
					} else {
						$value =~ s/-/\n/ig;
						$line =~ s/}/$value\n}/i;
					}
					$EndStepIndex = $StepsIndex;
				} else {
					$line =~ s/}/$key $value\n}/i;
				}
				last;
			} elsif ($key eq 'steps' && !$StartStepIndex && $line =~ /(\d+)(\[(\d+)\])?:(\d+)(\[(\d+)\])?/) {
				if ($line =~ /^(\s+)/) { $spaces = $1; } else { $spaces = 0; }
				$StartStepIndex = $StepsIndex;
			} elsif ($key eq 'reverseend' && $line =~ /reverseend/i) {
				$line =~ s/reverseend\s\d+/reverseend $value/i;
				last;
			} elsif ($key eq 'timeout' && $line =~ /timeout/i) {
				$line =~ s/timeout\s\d+/timeout $value/i;
				last;
			} else {
				next;
			}
		} elsif ($line =~ /$map/) {
			$Found = 1;
		}
	} continue {
		$StepsIndex++;
	}
	splice(@lines, $StartStepIndex, ($EndStepIndex-$StartStepIndex)) if ($key eq 'steps');
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @lines);
	close(WRITE);
	Commands::run("reload $betterWalk_file")
}

1;