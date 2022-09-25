package cycle;

use Plugins;
use Globals;
use Log qw( warning message error debug );
use Time::HiRes qw(time);
use Misc;
use Devel::Cycle;
use Devel::Refcount qw( refcount );

# Plugin
Plugins::register(PLUGINNAME, "", \&core_Unload, \&core_Reload);

my $commands_hooks = Commands::register(
	['cycle', 'test notification',			\&cmdcycleification],
);

my $hooks = Plugins::addHooks(
	['docycle',		\&cmdcycleification, undef],
);

sub core_Unload {
	error("Unloading plugin...", "cycle");
	core_SafeUnload();
}

sub core_Reload {
	warning("Reloading plugin...", "cycle");
	core_SafeUnload();
}

sub core_SafeUnload {
	Plugins::delHook($hooks);
	Commands::unregister($commands_hooks);
}

sub cmdcycleification {
	warning "Finding memory cycles\n";
	find_cycle($char);
}
1;