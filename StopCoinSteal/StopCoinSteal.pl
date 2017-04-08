############################
# StopCoinSteal plugin for OpenKore by Henrybk
#
# This software is open source, licensed under the GNU General Public
# License, version 2.
#
# This plugin extends all functions which use 'checkMonsterCondition'.
# Basically these are AttackSkillSlot, equipAuto, AttackComboSlot, monsterSkill.
#
# Following new checks are possible:
#
# target_notCoinStolen
############################

package StopCoinSteal;

use strict;
use Plugins;
use Globals;
use Settings;
use Log qw(message warning error debug);
use Misc qw(bulkConfigModify);
use Translation qw(T TF);
use Utils;


Plugins::register('StopCoinSteal', 'StopCoinSteal', \&onUnload);
my $hooks = Plugins::addHooks(
	['checkMonsterCondition', \&extendedCheck, undef],
	['packet_pre/skill_used_no_damage', \&onPacketSkillUseNoDamage, undef]
);

sub onUnload {
	Plugins::delHooks($hooks);
}

sub extendedCheck {
	my (undef, $args) = @_;

	return 0 if !$args->{monster} || $args->{monster}->{nameID} eq '';

	if ($config{$args->{prefix} . '_notCoinStolen'}) {
		if ($config{$args->{prefix} . '_notCoinStolen'} == 1 && $args->{monster}->{was_coin_stolen} == 1) {
			return $args->{return} = 0;
		}
	}

	return 1;
}

sub onPacketSkillUseNoDamage {
	my ($self, $args) = @_;
	
	return unless ($args->{sourceID} eq $char->{ID});
	
	return unless ($monsters{$args->{targetID}} && $monsters{$args->{targetID}}{nameID});
	
	return unless ($args->{skillID} == 211);
	
	$monsters{$args->{targetID}}{was_coin_stolen} = 1;
	message "[StopCoinSteal] Monster ".$monsters{$args->{targetID}}." was coin stolen.\n";
}

1;
