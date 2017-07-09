package BetterWalkPlan;

use strict;
use Globals;
use Utils;
use Misc;
use AI;
use Log qw(debug message warning error);
use Translation;
use File::Spec;

my $planStep = 0;
my $file_handle;
my $betterWalk_file;
my $reverse = 0;
my %walkMaps;

Plugins::register('BetterWalkPlan', 'Revised waypoint/planwalk 3.0', \&on_unload, \&on_unload);

my $start_hooks = Plugins::addHooks(
	['start3',                    \&on_start3, undef]
);

my $config_hooks;

my $chooks = Commands::register(
	['planwalk', "BetterWalkPlan", \&commandHandler]
);

sub on_unload {
	Plugins::delHooks($start_hooks);
	Plugins::delHooks($config_hooks);
	Commands::unregister($chooks);
	Settings::removeFile($file_handle) if (defined $file_handle);
	undef $file_handle;
	undef $betterWalk_file;
}

sub checkConfig {
	if (defined $config{betterWalk_file} && $config{betterWalk_file} ne $betterWalk_file) {
		$betterWalk_file = $config{betterWalk_file};
		Settings::removeFile($file_handle);
		$file_handle = Settings::addControlFile($betterWalk_file, loader => [ \&parseWalkPlan, undef], mustExist => 0);
		Settings::loadByHandle($file_handle);
		$planStep = 0;
		return;
		
	} elsif (!defined $config{betterWalk_file} && $betterWalk_file ne "betterwalk.txt") {
		$betterWalk_file = "betterwalk.txt";
		Settings::removeFile($file_handle);
		$file_handle = Settings::addControlFile($betterWalk_file, loader => [ \&parseWalkPlan, undef], mustExist => 0);
		Settings::loadByHandle($file_handle);
		$planStep = 0;
		return;
		
	}
}

sub on_configModify {
	my (undef, $args) = @_;
	if ($args->{key} eq 'betterWalk_file') {
		$betterWalk_file = $args->{val};
		Settings::removeFile($file_handle);
		$file_handle = Settings::addControlFile($betterWalk_file, loader => [ \&parseWalkPlan, undef], mustExist => 0);
		Settings::loadByHandle($file_handle);
		$planStep = 0;
	} elsif ($args->{key} eq 'betterWalkPlan' && $args->{val} == 0) {
		$planStep = 0;
	}
}

sub on_start3 {
	if (!defined $config{betterWalk_file}) {
		$config{betterWalk_file} = "betterwalk.txt";
		$betterWalk_file = "betterwalk.txt";
	} else {
		$betterWalk_file = $config{betterWalk_file};
	}
	$file_handle = Settings::addControlFile($betterWalk_file, loader => [ \&parseWalkPlan, undef], mustExist => 0);
	Settings::loadByHandle($file_handle);
	$config_hooks = Plugins::addHooks(
		['configModify',              \&on_configModify, undef],
		['postloadfiles',             \&checkConfig],
	);
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

# The correct way to do this should be by a hook and $args->{return}
*AI::CoreLogic::processRandomWalk = sub {
	if (AI::isIdle && (AI::SlaveManager::isIdle()) && $config{route_randomWalk} && !$ai_v{sitAuto_forcedBySitCommand}
		&& (!$field->isCity || $config{route_randomWalk_inTown})
		&& length($field->{rawMap}) 
		){
		
		# Plugin version
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
		
		# Normal randomwalk
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
			return;
			
		} elsif ($params[1] ne 'steps' && $params[1] ne 'reverseend' && $params[1] ne 'timeout') {
			error "[PlanWalk] Invalid key for conf\n"; 
			return;
			
		} elsif ($params[1] eq 'timeout' && $params[2] !~ /\d+/) {
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
		}
		
		&FileWrite($params[0], $params[1], $params[2]);
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
	my $Found = 0;
	my $line_index = 0;
	my $spaces;
	my $controlfile = Settings::getControlFilename($betterWalk_file);
	if (!defined $controlfile) {
		$controlfile = File::Spec->catdir($Settings::controlFolders[0],$betterWalk_file);
	}
	open(FILE, "<:utf8", $controlfile);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	my @clean_lines;
	
	foreach my $line (@lines) {
		if ($Found) {
			if ($line =~ /}/) {
				if ($key ne 'steps') {
					$line =~ s/}/\t$key $value\n}/i;
				} else {
					my @newsteps = split(/-/,$value);
					my $new_line;
					foreach my $step (@newsteps) {
						$new_line .= "\t".$step."\n";
					}
					$new_line .= '}';
					$line = $new_line;
				}
				last;
			} elsif ($key eq 'steps' && $line =~ /(\d+)(\[(\d+)\])?:(\d+)(\[(\d+)\])?/) {
				push(@clean_lines, ($line_index - scalar @clean_lines));
			} elsif ($key eq 'reverseend' && $line =~ /reverseend/i) {
				$line = "\treverseend ".$value;
				last;
			} elsif ($key eq 'timeout' && $line =~ /timeout/i) {
				$line = "\ttimeout ".$value;
				last;
			} else {
				next;
			}
		} elsif ($line =~ /$map/) {
			$Found = 1;
		}
	} continue {
		$line_index++;
	}
	
	if (!$Found) {
		push(@lines,'');
		push(@lines,'map '.$map.' {');
		
		if ($key eq 'steps') {
			my @newsteps = split(/-/,$value);
			foreach my $step (@newsteps) {
				push(@lines,"\t".$step);
			}
		} elsif ($key eq "reverseend") {
			push(@lines,"\treverseend ".$value);
			
		} elsif ($key eq "timeout") {
			push(@lines,"\ttimeout ".$value);
		}
		
		push(@lines,'}');
		
	} elsif ($key eq 'steps') {
		foreach my $index (@clean_lines) {
			splice(@lines, $index, 1);
		}
	}
	
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @lines);
	close(WRITE);
	
	Commands::run("reload $betterWalk_file")
}

1;