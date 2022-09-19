package avoidAssisters;

use strict;
use Globals;
use Settings;
use Misc;
use Plugins;
use Utils;
use Log qw(message debug error warning);

Plugins::register('avoidAssisters', 'enable custom conditions', \&onUnload);

my $hooks = Plugins::addHooks(
	['checkMonsterAutoAttack', \&on_checkMonsterAutoAttack, undef],
);

sub onUnload {
    Plugins::delHooks($hooks);
}

my %assisters_max = (
	1013 => 1, #Wolf
	1051 => 2, #Thief Bug
	1053 => 2, #Thief Bug Female
);

sub on_checkMonsterAutoAttack {
	my (undef, $args) = @_;
	
	return unless (exists $assisters_max{$args->{monster}->{nameID}});
	
	my $count = 0;
	for my $monster (@$monstersList) {
		next unless ($monster->{nameID} == $args->{monster}->{nameID});
		next if ($monster->{ID} eq $args->{monster}->{ID});
		
		if ($monster->{dmgFromYou} || $monster->{missedFromYou} || $monster->{'dmgToYou'} || $monster->{'missedYou'}) {
			$count++;
			next;
		}
		
		if (scalar(keys %{$monster->{missedFromPlayer}}) == 0
		 && scalar(keys %{$monster->{dmgFromPlayer}})    == 0
		 && scalar(keys %{$monster->{castOnByPlayer}})   == 0
		 && scalar(keys %{$monster->{missedToPlayer}}) == 0
		 && scalar(keys %{$monster->{dmgToPlayer}})    == 0
		 && scalar(keys %{$monster->{castOnToPlayer}}) == 0
		 && !objectIsMovingTowardsPlayer($monster)
		) {
			$count++;
			next;
		}
	}
	
	if ($count > $assisters_max{$args->{monster}->{nameID}}) {
		warning "Dropping target ".$args->{monster}." because it has ".$count." assisters and the max allowed is ".$assisters_max{$args->{monster}->{nameID}}.".\n";
		$args->{return} = 0;
	}
}

return 1;