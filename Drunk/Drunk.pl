package Drunk;

use utf8;
use strict;
use warnings;
use File::Spec;
use FileParsers;
use Plugins;
use Settings;
use Globals;
use Log qw(message error debug warning);

our $folder = $Plugins::current_plugin_folder;
use lib $Plugins::current_plugin_folder;

XSLoader::load('DrunkPath');

use DrunkPath;

Plugins::register('Drunk', 'Drunk', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['getRoute',   \&ongetRoute,    undef]
);

# onUnload
sub Unload {
	Plugins::delHooks($hooks);
}

use constant {
	PLUGIN_NAME => 'Drunk',
};

sub Unload {
	message "[".PLUGIN_NAME."] Plugin unloading or reloading.\n", 'success';
}

sub ongetRoute {
	my ($self, $args) = @_;
	
	return if (!defined $args->{self_call} || !$args->{self_call});
	return if (!exists $config{"drunk"} || !defined $config{"drunk"} || !$config{"drunk"});
	return if (
		   $args->{self}{LOSSubRoute}
		|| $args->{self}{meetingSubRoute}
		|| $args->{self}{isIdleWalk}
		|| $args->{self}{isSlaveRescue}
		|| $args->{self}{isMoveNearSlave}
		|| $args->{self}{isEscape}
		|| $args->{self}{isItemTake}
		|| $args->{self}{isItemGather}
		|| $args->{self}{runFromTarget}
	);
	
	my $drunk = $config{"drunk"};
	
	my $pathfinding = new DrunkPath();
	
	warning "[".PLUGIN_NAME."] Utilizing DrunkPath on getRoute self call, drunk value of $drunk.\n";
	$args->{pathfinding} = $pathfinding;
	$args->{return} = 1;
	
	return;
}

1;