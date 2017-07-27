package SmartPathing;

use strict;
use Globals;
use Settings;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug error warning);

use lib $Plugins::current_plugin_folder;

use SmartPathing::FieldGrid;
use SmartPathing::GridLists;
use SmartPathing::Grid;

Plugins::register('SmartPathing', 'enables smart pathing', \&onUnload);

my $hooks = Plugins::addHooks(
	['PathFindingReset', \&on_PathFindingReset, undef], # Changes args
	['AI_pre/manual', \&on_AI_pre_manual, undef],    # Recalls routing
	['packet_mapChange', \&on_packet_mapChange, undef],
);

my $mob_hooks = Plugins::addHooks(
	['add_monster_list', \&on_add_monster_list, undef],
	['monster_disappeared', \&on_monster_disappeared, undef],
);

sub onUnload {
    Plugins::delHooks($hooks);
	Plugins::delHooks($mob_hooks);
}

my %nameID_obstacles = (
	1013 => 1, #Wolf
);

my %obstaclesList;

my $mustRePath = 0;

my $field_grid = new SmartPathing::FieldGrid();

sub on_packet_mapChange {
	$field_grid->set_mother_grid_field($field);
}

sub on_add_monster_list {
	my (undef, $args) = @_;
	my $actor = $args;
	return unless (exists $nameID_obstacles{$actor->{nameID}});
	
	$field_grid->add_mob_obstacle($actor->{binID});
}

sub on_monster_disappeared {
	my (undef, $args) = @_;
	my $actor = $args->{monster};
	if (exists $obstaclesList{$actor->{binID}}) {
		delete $obstaclesList{$actor->{binID}};
		
	} elsif (exists $new_objects{$actor->{binID}}) {
		delete $new_objects{$actor->{binID}};
	}
	
	$field_grid->remove_mob_obstacle($actor->{binID});
}

sub on_AI_pre_manual {
	return unless (AI::is("route"));
	return unless (scalar %new_objects);
	
	$mustRePath = 1;
	
	my $current_task = $char->args;
	
	my $map = $field->baseName;
	my $x = $current_task->{dest}{pos}{x};
	my $y = $current_task->{dest}{pos}{y};
	
	my %current_goal;
	
	$current_goal{$_} = $current_task->{$_} for qw(maxDistance maxTime avoidWalls attackID attackOnRoute noSitAuto LOSSubRoute distFromGoal pyDistFromGoal notifyUponArrival);
	
	AI::clear(qw/route/);
	
	$char->route(
		$map,
		$x,
		$y,
		%current_goal
	);
}

sub on_PathFindingReset {
	my (undef, $args) = @_;
	
	return unless ($mustRePath);
	
	$args->{args}{width} = $args->{args}{field}{width} unless ($args->{args}{width});
	$args->{args}{height} = $args->{args}{field}{height} unless ($args->{args}{height});
	$args->{args}{timeout} = 1500 unless ($args->{args}{timeout});
	
	$args->{args}{distance_map} = $field_grid->get_final_grid();
	
	$mustRePath = 0;
	$args->{return} = 0;
}

sub get_added_weight {
	my ($obs_x, $obs_y, $cell_x, $cell_y) = @_;
	
}

return 1;