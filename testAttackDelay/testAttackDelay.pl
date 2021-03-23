package testAttackDelay;
 
use strict;
use Plugins;
use Globals;
use Log qw(warning);
use Time::HiRes qw(time);
 
#########
# startup
Plugins::register('testAttackDelay', 'tests attack delay', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['packet_attack', \&onpacket_attack, undef]
);

sub Unload {
	Plugins::delHooks($hooks);
}

sub onpacket_attack {
	my ($self, $args) = @_;
	
	my $source = Actor::get($args->{sourceID});
	my $target = Actor::get($args->{targetID});
	
	if ($source->isa('Actor::Slave')) {
		if (!exists $source->{dmgtest}) {
			warning "$source attack $target - first attack at all\n";
			$source->{dmgtest}{$args->{targetID}} = time;
		
		} elsif (exists $source->{dmgtest} && !exists $source->{dmgtest}{$args->{targetID}}) {
			delete $source->{dmgtest};
			warning "$source attack $target - changed target, first attack to it\n";
			$source->{dmgtest}{$args->{targetID}} = time;
			
		} else {
			my $newtime = time;
			warning "$source attack $target - delay (".($newtime - $source->{dmgtest}{$args->{targetID}}).")\n";
			$source->{dmgtest}{$args->{targetID}} = $newtime;
		}
	}
}

return 1;
