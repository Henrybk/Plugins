package teleportToDest;

use strict;
use warnings;
use Globals;
use Log qw(message debug error warning);
use Settings;
use Plugins;
use Misc;
use Utils;
use AI;
use Network;

Plugins::register("teleportToDest", "teleportToDest", \&unload, \&unload);
my $hooks = Plugins::addHooks(
	['AI_pre',\&on_RepeatStuff, undef],
	['packet_mapChange', \&MapLoaded, undef],
);

my $maploaded;

sub unload {
	Plugins::delHooks($hooks);
}

sub MapLoaded {
	$maploaded = 1;
}

sub on_RepeatStuff {
	if ($config{'teleportToDest'} && Misc::inLockMap() && $maploaded == 1) {
		my %want;
		if ($config{'teleportToDestxy'} =~ /(\d+)\s+(\d+)/) {
			($want{x}, $want{y}) = ($1, $2);
		} else {
			error T("Invalid coordinates in teleportToDestxy; teleportToDest disabled\n");
			configModify('teleportToDest', 0);
		}
		my $dist = round(distance($char->{pos_to}, \%want));
		if ($dist > $config{'teleportToDestMinDist'}) {
			message "[teleportToDest]Teleporting\n", "info";
			$maploaded = 0;
			useTeleport(1);
		} else {
			message "[teleportToDest]Destination reached; teleportToDest disabled\n", "info";
			configModify('teleportToDest', 0);
		}
	}
}

return 1;