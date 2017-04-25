# =======================
# keepPreserveSkill v0.9.1 beta
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
#	keepPreserveSkill_on 1 (boolean active/inactive)
#	keepPreserveSkill_handle MG_COLDBOLT (handle of skill to be kept)
#	keepPreserveSkill_timeout 450 (amount of seconds after we used preserve in which we will start to try to use it again while walking, taking items, routing, etc)
#	keepPreserveSkill_timeoutCritical 550 (same as above, but after this time we will try to use it even while attacking)
#
#
# Extras: The plugin will make the character try to teleport if there is a monster on screen and you don't have preserve activated, this can make you keep teleport forever on very mobbed maps like juperus.

package keepPreserveSkill;

use Plugins;
use Globals;
use Log qw(message warning error debug);
use File::Spec;
use JSON::Tiny qw(from_json to_json);
use AI;
use Misc;
use Network;
use Network::Send;
use Utils;
use Commands;
use Actor;

use constant {
	INACTIVE => 0,
	ACTIVE => 1
};

Plugins::register('Preserve', 'Preserve', , \&on_unload, \&on_unload);

my $base_hooks = Plugins::addHooks(
	['start3',        \&on_start3],
	['postloadfiles', \&checkConfig],
	['configModify',  \&on_configModify]
);

our $folder = $Plugins::current_plugin_folder;

my $last_preserve_use_time;

my $keeping_hooks;

my $in_game_hook = undef;

my $status = INACTIVE;

my $plugin_name = "keepPreserveSkill";

our %mobs;

sub on_unload {
   Plugins::delHook($base_hooks);
   changeStatus(INACTIVE);
   message "[$plugin_name] Plugin unloading or reloading.\n", 'success';
}

sub on_start3 {
    %mobs = %{loadFile(File::Spec->catdir($folder,'mobs_info.json'))};
	if (!defined %mobs || !%mobs || scalar keys %mobs == 0) {
		error "[$plugin_name] Could not load mobs info due to a file loading problem.\n.";
		return;
	}
	Log::message( sprintf "[%s] Found %d mobs.\n", $plugin_name, scalar keys %mobs );
}

sub loadFile {
    my $file = shift;

	unless (open FILE, "<:utf8", $file) {
		error "[$plugin_name] Could not load file $file.\n.";
		return;
	}
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	my $jsonString = join('',@lines);

	my %converted = %{from_json($jsonString, { utf8  => 1 } )};

	return \%converted;
}

sub checkConfig {
	if (validate_settings()) {
		changeStatus(ACTIVE);
	} else {
		changeStatus(INACTIVE);
	}
}

sub on_configModify {
	my (undef, $args) = @_;
	return unless ($args->{key} eq 'keepPreserveSkill_on' || $args->{key} eq 'keepPreserveSkill_handle' || $args->{key} eq 'keepPreserveSkill_timeout' || $args->{key} eq 'keepPreserveSkill_timeoutCritical');
	if (validate_settings($args->{key}, $args->{val})) {
		changeStatus(ACTIVE);
	} else {
		changeStatus(INACTIVE);
	}
}

sub validate_settings {
	my ($key, $val) = @_;
	
	my $on_off;
	my $handle;
	my $timeout;
	my $timeoutCritical;
	if (!defined $key) {
		$on_off = $config{keepPreserveSkill_on};
		$handle = $config{keepPreserveSkill_handle};
		$timeout = $config{keepPreserveSkill_timeout};
		$timeoutCritical = $config{keepPreserveSkill_timeoutCritical};
	} else {
		$on_off =           ($key eq 'keepPreserveSkill_on'              ?   $val : $config{keepPreserveSkill_on});
		$handle =           ($key eq 'keepPreserveSkill_handle'          ?   $val : $config{keepPreserveSkill_handle});
		$timeout =          ($key eq 'keepPreserveSkill_timeout'         ?   $val : $config{keepPreserveSkill_timeout});
		$timeoutCritical =  ($key eq 'keepPreserveSkill_timeoutCritical' ?   $val : $config{keepPreserveSkill_timeoutCritical});
	}
	
	my $error = 0;
	if (!defined $on_off || !defined $handle || !defined $timeout || !defined $timeoutCritical) {
		message "[$plugin_name] There are config keys not defined, plugin won't be activated.\n","system";
		$error = 1;
		
	} elsif ($on_off !~ /^[01]$/) {
		message "[$plugin_name] Value of key 'keepPreserveSkill_on' must be 0 or 1, plugin won't be activated.\n","system";
		$error = 1;
		
	} elsif ($timeout !~ /^\d+$/) {
		message "[$plugin_name] Value of key 'keepPreserveSkill_timeout' must be a number, plugin won't be activated.\n","system";
		$error = 1;
		
	} elsif ($timeoutCritical !~ /^\d+$/) {
		message "[$plugin_name] Value of key 'keepPreserveSkill_timeoutCritical' must be a number, plugin won't be activated.\n","system";
		$error = 1;
	}
	
	if ($error == 1) {
		configModify('keepPreserveSkill_on', 0) if ($on_off != 0);
		return 0;
	}
	
	if ($char && $net && $net->getState() == Network::IN_GAME) {
		return 0 unless (check_skills($handle, $on_off));
		return $on_off;
		
	} else {
		if ($on_off == 1 && !defined $in_game_hook) {
			$in_game_hook = Plugins::addHooks(
				['in_game',  \&on_in_game]
			);
		}
		return 0;
	}
}

sub on_in_game {
	if (check_skills($config{keepPreserveSkill_handle}, 1)) {
		changeStatus(ACTIVE);
	} else {
		changeStatus(INACTIVE);
	}
	Plugins::delHook($in_game_hook);
	undef $in_game_hook;
}

sub check_skills {
	my $handle = shift;
	my $on_off = shift;
	
	my $error = 0;
	if (!$char->getSkillLevel(new Skill(handle => 'ST_PRESERVE'))) {
		message "[$plugin_name] You don't have the skill Preserve\n","system";
		$error = 1;
		
	} elsif (!$char->getSkillLevel(new Skill(handle => $handle))) {
		message "[$plugin_name] You don't have the skill you want to keep: ".$handle."\n","system";
		$error = 1;
	}
	
	if ($error == 1) {
		configModify('keepPreserveSkill_on', 0) if ($on_off ne '0');
		return 0;
	}
	
	return 1;
}

sub changeStatus {
	my $new_status = shift;
	
	return if ($new_status == $status);
	
	if ($new_status == INACTIVE) {
		Plugins::delHook($keeping_hooks);
		debug "[$plugin_name] Plugin stage changed to 'INACTIVE'\n", "$plugin_name", 1;
		
	} elsif ($new_status == ACTIVE) {
		$keeping_hooks = Plugins::addHooks(
			['AI_pre',\&on_RepeatStuff, undef],
			['Actor::setStatus::change',\&on_statusChange, undef]
		);
		debug "[$plugin_name] Plugin stage changed to 'ACTIVE'\n", "$plugin_name", 1;
	}
	
	$status = $new_status;
}

######

sub on_statusChange {
	my (undef, $args) = @_;
	if ($args->{handle} eq 'EFST_PRESERVE' && $args->{actor_type}->isa('Actor::You') && $args->{flag} == 1) {
		message "[$plugin_name] Preserve was used, reseting timer\n","system";
		$last_preserve_use_time = time;
	}
}

sub on_RepeatStuff {
	return if (!$char || !$net || $net->getState() != Network::IN_GAME);
	return if ($char->{muted});
	return if ($char->{casting});
	return if ($char->statusActive('EFST_POSTDELAY'));
	
	unless (check_skills($config{keepPreserveSkill_handle}, 1)) {
		message "[$plugin_name] Deactivating plugin due to not having preserve skill or the skill you want to keep.\n","system";
		configModify('keepPreserveSkill_on', 0);
		changeStatus(INACTIVE);
		return;
	}
	
	if ($char->statusActive('EFST_PRESERVE')) {
		return unless (timeOut($config{keepPreserveSkill_timeout}, $last_preserve_use_time));
		if (AI::isIdle || AI::is(qw(mapRoute follow sitAuto take sitting clientSuspend move route items_take items_gather))) {
			message "[$plugin_name] Using non-critical preserve with ".(($last_preserve_use_time+600)-time)." seconds left on counter\n","system";
			Commands::run("ss 475 1");
			return;
		}
		
		return unless (timeOut($config{keepPreserveSkill_timeoutCritical}, $last_preserve_use_time));
		if (AI::is(qw(attack))) {
			message "[$plugin_name] Using critical preserve with ".(($last_preserve_use_time+600)-time)." seconds left on counter\n","system";
			Commands::run("ss 475 1");
			return;
		}
		
	} else {
		my $teleport = 0;
		if (ai_getAggressives()) {
			message "[$plugin_name] A monster is attacking us, teleporting to not lose skill\n","system";
			$teleport = 1;
			
		} elsif (scalar @{$monstersList->getItems()} > 0) {
			foreach my $mob (@{$monstersList->getItems()}) {
				my $id = $mob->{nameID};
				my $mob_info = $mobs{$id};
				next unless ($mob_info->{is_aggressive} == 1);
				message "[$plugin_name] Aggressive monster near, teleporting to not lose skill\n","system";
				$teleport = 1;
				last;
			}
		}
		if ($teleport == 1) {
			if (main::useTeleport(1)) {
				message "[$plugin_name] Teleport sent.\n", "info";
			} else {
				message "[$plugin_name] Cannot use teleport.\n", "info";
			}
		} else {
			message "[$plugin_name] Using preserve skill\n","system";
			Commands::run("ss 475 1");
		}
	}
}

return 1;