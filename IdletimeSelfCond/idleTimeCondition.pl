package IdleCondition;

use strict;
use Plugins;
use Globals;
use Settings;
use Log qw(message warning error debug);
use Misc;
use Utils;


Plugins::register('IdleCondition', 'implement idleTime in checkSelfCondition', \&onUnload);
my $hooks = Plugins::addHooks(
	['checkSelfCondition', \&extendedCheck, undef]
);

my $time;

sub onUnload {
	Plugins::delHooks($hooks);
}

sub extendedCheck {
	my (undef, $args) = @_;
	if ($config{$args->{prefix}."_whenIdleFor"}) {
		if (!AI::isIdle) {
			$time = time;
			return $args->{return} = 0;
		} elsif (timeOut($config{$args->{prefix}."_whenIdleFor"}, $time)) {
			return $args->{return} = 1;
		} else {
			return $args->{return} = 0;
		}
	}
	return 1;
}

1;
