package randItemsTakeTimeout;

use utf8;
use strict;
use warnings;
use Plugins;
use Globals;
use Log qw(message error debug warning);

Plugins::register('randItemsTakeTimeout', 'randItemsTakeTimeout', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['ai_items_take',				\&on_ai_items_take, undef],
);

use constant {
	PLUGIN_NAME => 'randItemsTakeTimeout',
};

my @rand_percent = (-60..40);

sub Unload {
	Plugins::delHook($hooks);
	message "[".PLUGIN_NAME."] Plugin unloading or reloading.\n", 'success';
}

sub on_ai_items_take {
	
	my $original = $timeout{ai_items_take_delay}{timeout};
	
	my $rand = $rand_percent[rand @rand_percent];
	my $rand_mult = 1 + ($rand/100);
	
	my $new = int(($original * $rand_mult)*10)/10;
	
	AI::args->{ai_items_take_delay}{timeout} = $new;
	
	debug "[".PLUGIN_NAME."] Randoming items take timeout from $original to $new\n";
	
	return;
}

1;