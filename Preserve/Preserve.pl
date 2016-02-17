# =======================
# Preserve v0.9 beta
# =======================
# This plugin is licensed under the GNU GPL
# Created by Henrybk
#
# What it does: tries to keep your copied skill from being lost
#
#
# Example (put in config.txt):
#	
#	Config example:
#	testPreserve 1 (boolean active/inactive)
#	testPreserveSkill MG_COLDBOLT (handle of skill to be kept)
#	testPreserveTimeout 450 (amount of seconds after we used preserve in which we will start to try to use it again while walking, taking items, routing, etc)
#	testPreserveTimeoutCritical 550 (same as above, but after this time we will try to use it even while attacking)
#
#
# Extras: The plugin will make the character try to teleport if there is a monster on screen and you don't have preserve activated, this can make you keep teleport forever on very mobbed maps like juperus.

package Preserve;

use Plugins;
use Globals;
use Log qw(message warning error debug);
use AI;
use Misc;
use Network;
use Network::Send;
use Utils;
use Commands;
use Actor;

use constant {
	STALKER => 4018,
	SHADOWCHASER => 4079
};

Plugins::register('Preserve', 'Preserve', \&on_unload);
my $hooks = Plugins::addHooks(
	['AI_pre',\&on_RepeatStuff, undef],
	['Actor::setStatus::change',\&on_statusChange, undef]
);

my $lastUsedPreserveTime;

sub on_unload {
	Plugins::delHooks($hooks);
}

sub on_statusChange {
	my (undef, $args) = @_;
	if ($args->{handle} eq 'EFST_PRESERVE' && $args->{actor_type}->isa('Actor::You') && $args->{flag} == 1) {
		message "[Preserve] Preserve was used, reseting timer\n","system";
		$lastUsedPreserveTime = time;
	}
}

sub on_RepeatStuff {
	return if (!$char || !$net || $net->getState() != Network::IN_GAME);
	return if ($char->{muted});
	return if ($char->{casting});
	if ($config{testPreserve} && $config{testPreserveSkill}) {
		if ($char->{jobID} != STALKER && $char->{jobID} != SHADOWCHASER) {
			message "[Preserve] You're not a stalker/SC\n","system";
			configModify("testPreserve", 0);
		} elsif (!$char->getSkillLevel(new Skill(handle => 'ST_PRESERVE'))) {
			message "[Preserve] You don't have the skill Preserve\n","system";
			configModify("testPreserve", 0);
		} elsif (!$char->getSkillLevel(new Skill(handle => $config{testPreserveSkill}))) {
			message "[Preserve] You don't have the skill you want to keep: ".$config{testPreserveSkill}."\n","system";
			configModify("testPreserve", 0);
		} elsif ($char->statusActive('EFST_PRESERVE')) {
			return if ($char->statusActive('EFST_POSTDELAY'));
			if (timeOut($config{testPreserveTimeout}, $lastUsedPreserveTime) && (AI::isIdle || AI::is(qw(mapRoute follow sitAuto take sitting clientSuspend move route items_take items_gather)))) {
				message "[Preserve] Using normal preserve with ".(($lastUsedPreserveTime+600)-time)." seconds left on counter\n","system";
				Commands::run("ss 475 1");
			} elsif (timeOut($config{testPreserveTimeoutCritical}, $lastUsedPreserveTime) && AI::is(qw(attack))) {
				message "[Preserve] Using critical preserve with ".(($lastUsedPreserveTime+600)-time)." seconds left on counter\n","system";
				Commands::run("ss 475 1");
			}
		} else {
			foreach (@{$monstersList->getItems()}) { message "[Preserve] Monster near, teleporting to not lose skill\n","system"; main::useTeleport(1); return; }
			return if ($char->statusActive('EFST_POSTDELAY'));
			return unless (AI::isIdle || AI::is(qw(mapRoute follow sitAuto take sitting clientSuspend move route items_take items_gather)));
			message "[Preserve] No monster near, using preserve\n","system";
			Commands::run("ss 475 1");
		}
	}
}

return 1;