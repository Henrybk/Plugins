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
	['monster_moved', \&on_monster_moved, undef],
);

sub onUnload {
    Plugins::delHooks($hooks);
	Plugins::delHooks($mob_hooks);
}

my %nameID_obstacles = (
	#1013 => 1, #Wolf
	1277 => 1,
);

my %obstaclesList;

my $mustRePath = 0;

my $field_grid = new SmartPathing::FieldGrid();

sub on_packet_mapChange {
	$field_grid->set_mother_grid_field($field);
	undef %obstaclesList;
	$mustRePath = 0;
}

sub on_add_monster_list {
	my (undef, $args) = @_;
	my $actor = $args;
	
	return unless (exists $nameID_obstacles{$actor->{nameID}});
	
	$obstaclesList{$actor->{binID}} = 1;
	
	Log::warning "[test] Adding Monster $actor.\n";
	
	$field_grid->add_mob_obstacle($actor->{binID});
	
	$mustRePath = 1;
}

sub on_monster_disappeared {
	my (undef, $args) = @_;
	my $actor = $args->{monster};
	
	return unless (exists $obstaclesList{$actor->{binID}});
	
	delete $obstaclesList{$actor->{binID}};
	
	Log::warning "[test] Removing Monster $actor.\n";
	
	$field_grid->remove_mob_obstacle($actor->{binID});
	
	$mustRePath = 1;
}

sub on_monster_moved {
	my (undef, $args) = @_;
	my $actor = $args;
	
	return unless (exists $obstaclesList{$actor->{binID}});
	
	Log::warning "[test] Updating Monster $actor.\n";
	
	$field_grid->update_mob_obstacle($actor->{binID});
	
	$mustRePath = 1;
}

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
	
	Log::warning "[test] There are ".scalar keys(%obstaclesList)." obstacles.\n";
	
	return unless (keys(%obstaclesList) > 0);
	
	Log::warning "[test] Using grided info.\n";
	
	$args->{args}{weight_map} = \($field_grid->get_final_grid());
	$args->{args}{avoidWalls} = 1;
	
	$args->{args}{width} = $args->{args}{field}{width} unless ($args->{args}{width});
	$args->{args}{height} = $args->{args}{field}{height} unless ($args->{args}{height});
	$args->{args}{timeout} = 1500 unless ($args->{args}{timeout});
	
	$args->{return} = 0;
}

return 1;