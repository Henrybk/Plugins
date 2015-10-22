package onMonsterKill;

use strict;
use Globals;
use Utils;
use Misc;
use AI;
use Log qw(debug message warning error);

Plugins::register('onMonsterKill', 'Check killed monsters', \&on_unload, \&on_unload);

my $hooks = Plugins::addHooks(
	['target_died', \&on_Hash, undef]
);

sub on_unload {
	Plugins::delHooks($hooks);
}

sub on_Hash {
	my ($self, $args) = @_;
	my $monster = $args->{monster};
	my $i = 0;
	while (exists $config{"onMonsterKill_$i"}) {
		if ($config{"onMonsterKill_$i"} && checkSelfCondition("onMonsterKill_$i") && checkMonster("onMonsterKill_$i", $monster)) {
			Commands::run($config{"onMonsterKill_$i"});
			last;
		}
	} continue {
		$i++;
	}
}

sub checkMonster {
	my ($prefix, $monster) = @_;
	return 0 if (!$prefix);
	return 0 if ($config{$prefix . "_disabled"});
	if ($config{$prefix."_name"}) {
		return 0 if ($monster->{name} ne $config{$prefix."_name"});
	}
	if ($config{$prefix."_name_given"}) {
		return 0 if ($monster->{name_given} ne $config{$prefix."_name_given"});
	}
	if ($config{$prefix."_nameID"}) {
		return 0 if ($monster->{nameID} ne $config{$prefix."_nameID"});
	}
	if ($config{$prefix."_dmgFromYou"}) {
		return 0 if (!inRange($monster->{dmgFromYou}, $config{$prefix."_dmgFromYou"}));
	}
	if ($config{$prefix."_numAtkFromYou"}) {
		return 0 if (!inRange($monster->{numAtkFromYou}, $config{$prefix."_numAtkFromYou"}));
	}
	if ($config{$prefix."_moblv"}) {
		return 0 if ($monster->{lv} != $config{$prefix."_moblv"});
	}
	return 1;
}

1;