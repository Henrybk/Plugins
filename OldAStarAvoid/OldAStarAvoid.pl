package OldAStarAvoid;

use strict;
use Globals;
use Settings;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug error warning);
use Data::Dumper;

Plugins::register('OldAStarAvoid', 'Enables smart pathing using the dynamic aspect of D* Lite pathfinding', \&onUnload);

use constant {
	PLUGIN_NAME => 'OldAStarAvoid',
	ENABLE_MOVE => 1,
	ENABLE_REMOVE => 0,
};

my $hooks = Plugins::addHooks(
	['PathFindingReset', \&on_PathFindingReset, undef], # Changes args
	['AI_pre/manual', \&on_AI_pre_manual, undef],    # Recalls routing
	['packet_mapChange', \&on_packet_mapChange, undef],
);

my $obstacle_hooks = Plugins::addHooks(
	# Mobs
	['add_monster_list', \&on_add_monster_list, undef],
	['monster_disappeared', \&on_monster_disappeared, undef],
	['monster_moved', \&on_monster_moved, undef],
	
	# Players
	['add_player_list', \&on_add_player_list, undef],
	['player_disappeared', \&on_player_disappeared, undef],
	['player_moved', \&on_player_moved, undef],
	
	# Spells
	['packet_areaSpell', \&on_add_areaSpell_list, undef],
	['packet_pre/area_spell_disappears', \&on_areaSpell_disappeared, undef],
);

sub onUnload {
    Plugins::delHooks($hooks);
	Plugins::delHooks($obstacle_hooks);
}

my %mob_nameID_obstacles = (
	1368 => [0, 0, 0, 0], #Planta carnívora
	1475 => [0, 0, 0, 0], #wraith
);

my %player_name_obstacles = (
	'henry safado' => [0, 0, 0, 0],
);

my %area_spell_type_obstacles = (
	'135' => [0, 0, 1, 2],
);

my %obstaclesList;

my $mustRePath = 0;

sub on_packet_mapChange {
	undef %obstaclesList;
	$mustRePath = 0;
}

###################################################
######## Main obstacle management
###################################################

sub add_obstacle {
	my ($actor, $wall_dists) = @_;
	
	warning "[".PLUGIN_NAME."] Adding obstacle $actor on location ".$actor->{pos}{x}." ".$actor->{pos}{y}.".\n";
	
	my $changes = create_changes_array($actor->{pos}{x}, $actor->{pos}{y}, $wall_dists);
	
	$obstaclesList{$actor->{ID}} = $changes;
	
	$mustRePath = 1;
}

sub move_obstacle {
	my ($actor, $wall_dists) = @_;
	
	return unless (ENABLE_MOVE);
	
	warning "[".PLUGIN_NAME."] Moving obstacle $actor (from ".$actor->{pos}{x}." ".$actor->{pos}{y}." to ".$actor->{pos_to}{x}." ".$actor->{pos_to}{y}.").\n";
	
	my $new_changes = create_changes_array($actor->{pos_to}{x}, $actor->{pos_to}{y}, $wall_dists);
	
	$obstaclesList{$actor->{ID}} = $new_changes;
	
	$mustRePath = 1;
}

sub remove_obstacle {
	my ($actor) = @_;
	
	return unless (ENABLE_REMOVE);
	
	warning "[".PLUGIN_NAME."] Removing obstacle $actor from ".$actor->{pos}{x}." ".$actor->{pos}{y}.".\n";
	
	delete $obstaclesList{$actor->{ID}};
	
	$mustRePath = 1;
}

###################################################
######## Tecnical subs
###################################################

sub on_AI_pre_manual {
	return unless (AI::is("route"));
	return unless ($mustRePath);
	
	my $task;
	
	if (UNIVERSAL::isa($char->args, 'Task::Route')) {
		$task = $char->args;
		
	} elsif ($char->args->getSubtask && UNIVERSAL::isa($char->args->getSubtask, 'Task::Route')) {
		$task = $char->args->getSubtask;
		
	} else {
		return;
	}
	
	$mustRePath = 0;
	
	if (scalar @{$task->{solution}} == 0) {
		Log::warning "[test] Route already reseted.\n";
		return;
	}
	
	Log::warning "[test] Reseting route.\n";
	
	$task->resetRoute;
}

sub on_PathFindingReset {
	my (undef, $args) = @_;
	
	my @obstacles = keys(%obstaclesList);
	
	warning "[".PLUGIN_NAME."] on_PathFindingReset before check, there are ".@obstacles." obstacles.\n";
	
	return unless (@obstacles > 0);
	
	Log::warning "[test] Using grided info.\n";
	
	$args->{args}{distance_map} = \(get_final_grid());
	$args->{args}{avoidWalls} = 1;
	
	$args->{args}{width} = $args->{args}{field}{width} unless ($args->{args}{width});
	$args->{args}{height} = $args->{args}{field}{height} unless ($args->{args}{height});
	$args->{args}{timeout} = 1500 unless ($args->{args}{timeout});
	
	$args->{return} = 0;
}

sub get_final_grid {
	my $grid = $field->{dstMap};
	
	my $changes = sum_all_changes();
	
	foreach my $change (@{$changes}) {
		my $position = $change->{y} * $field->{width} + $change->{x};
		my $current_wall_dist = unpack('C', substr($grid, $position, 1));
		next if ($current_wall_dist == 0);
		
		my $wall_dist_changed = $change->{wall_dist};
		
		if ($current_wall_dist > $wall_dist_changed) {
			substr($grid, $position, 1, pack('C', $wall_dist_changed));
		}
	}
	
	return $grid;
}

sub create_changes_array {
	my ($obs_x, $obs_y, $wall_dist_array) = @_;
	
	my @wall_dists = @{$wall_dist_array};
	
	my $max_distance = $#wall_dists;
	
	my @changes_array;
	
	for (my $y = ($obs_y - $max_distance);     $y <= ($obs_y + $max_distance);   $y++) {
		for (my $x = ($obs_x - $max_distance);     $x <= ($obs_x + $max_distance);   $x++) {
			my $xDistance = abs($obs_x - $x);
			my $yDistance = abs($obs_y - $y);
			my $cell_distance = (($xDistance > $yDistance) ? $xDistance : $yDistance);
			my $wall_dist = $wall_dists[$cell_distance];
			next unless ($field->isWalkable($x, $y));
			push(@changes_array, { x => $x, y => $y, wall_dist => $wall_dist});
		}
	}
	
	return \@changes_array;
}

sub sum_all_changes {
	my %changes_hash;
	
	foreach my $key (keys %obstaclesList) {
		foreach my $change (@{$obstaclesList{$key}}) {
			my $x = $change->{x};
			my $y = $change->{y};
			my $wall_dist = $change->{wall_dist};
			$changes_hash{$x}{$y} = $wall_dist;
		}
	}
	
	my @rebuilt_array;
	foreach my $x_keys (keys %changes_hash) {
		foreach my $y_keys (keys %{$changes_hash{$x_keys}}) {
			next if ($changes_hash{$x_keys}{$y_keys} == 0);
			push(@rebuilt_array, { x => $x_keys, y => $y_keys, wall_dist => $changes_hash{$x_keys}{$y_keys} });
		}
	}
	
	return \@rebuilt_array;
}

###################################################
######## Player avoiding
###################################################

sub on_add_player_list {
	my (undef, $args) = @_;
	my $actor = $args;
	
	return unless (exists $player_name_obstacles{$actor->{name}});
	
	my @wall_dists = @{$player_name_obstacles{$actor->{name}}};
	
	add_obstacle($actor, \@wall_dists);
}

sub on_player_moved {
	my (undef, $args) = @_;
	my $actor = $args;
	
	return unless (exists $obstaclesList{$actor->{ID}});
	
	my @wall_dists = @{$player_name_obstacles{$actor->{name}}};
	
	move_obstacle($actor, \@wall_dists);
}

sub on_player_disappeared {
	my (undef, $args) = @_;
	my $actor = $args->{player};
	
	return unless (exists $obstaclesList{$actor->{ID}});
	
	remove_obstacle($actor);
}

###################################################
######## Mob avoiding
###################################################

sub on_add_monster_list {
	my (undef, $args) = @_;
	my $actor = $args;
	
	return unless (exists $mob_nameID_obstacles{$actor->{nameID}});
	
	my @wall_dists = @{$mob_nameID_obstacles{$actor->{nameID}}};
	
	add_obstacle($actor, \@wall_dists);
}

sub on_monster_moved {
	my (undef, $args) = @_;
	my $actor = $args;

	return unless (exists $obstaclesList{$actor->{ID}});
	
	my @wall_dists = @{$mob_nameID_obstacles{$actor->{nameID}}};
	
	move_obstacle($actor, \@wall_dists);
}

sub on_monster_disappeared {
	my (undef, $args) = @_;
	my $actor = $args->{monster};
	
	return unless (exists $obstaclesList{$actor->{ID}});
	
	remove_obstacle($actor);
}

###################################################
######## Spell avoiding
###################################################

# TODO: Add fail flag check

sub on_add_areaSpell_list {
	my (undef, $args) = @_;
	my $ID = $args->{ID};
	my $spell = $spells{$ID};
	
	return unless (exists $area_spell_type_obstacles{$spell->{type}});
	
	my @wall_dists = @{$area_spell_type_obstacles{$spell->{type}}};
	
	add_obstacle($spell, \@wall_dists);
}

sub on_areaSpell_disappeared {
	my (undef, $args) = @_;
	my $ID = $args->{ID};
	my $spell = $spells{$ID};
	
	return unless (exists $obstaclesList{$spell->{ID}});
	
	remove_obstacle($spell);
}

return 1;