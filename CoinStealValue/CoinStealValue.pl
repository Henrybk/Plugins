package CoinStealValue;

use strict;
use Plugins;
use Globals;
use Settings;
use utf8;
use warnings;
use File::Spec;
use JSON::Tiny qw(from_json to_json);
use FileParsers;
use Log qw(message warning error debug);
use Utils;

Plugins::register('CoinStealValue', 'CoinStealValue', \&Unload);
my $hooks = Plugins::addHooks(
	['start3',						\&on_start3, undef],
	['checkMonsterCondition', \&extendedCheck, undef],
);

use constant {
	PLUGIN_NAME => 'CoinStealValue',
};

my $mobs_info;

our $folder = $Plugins::current_plugin_folder;

sub Unload {
	Plugins::delHook($hooks);
	message "[".PLUGIN_NAME."] Plugin unloading or reloading.\n", 'success';
}

sub on_start3 {
    $mobs_info = loadFile(File::Spec->catdir($folder,'mobs_info.json'));
	if (!defined $mobs_info) {
		error "[".PLUGIN_NAME."] Could not load mobs info due to a file loading problem.\n.";
		return;
	}
}

sub loadFile {
    my $file = shift;

	unless (open FILE, "<:utf8", $file) {
		error "[".PLUGIN_NAME."] Could not load file $file.\n.";
		return;
	}
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	my $jsonString = join('',@lines);

	my %converted = %{from_json($jsonString, { utf8  => 1 } )};

	return \%converted;
}

sub get_skill_lvl {
	my $skill = new Skill(handle => 'RG_STEALCOIN');
	my $skill_lvl = $char->getSkillLevel($skill);
	return $skill_lvl;
}

sub get_skill_sp_cost {
	my $skill = new Skill(handle => 'RG_STEALCOIN');
	my $skill_lvl = $char->getSkillLevel($skill);
	my $skill_sp_cost = $skill->getSP($skill_lvl);
	return $skill_sp_cost;
}

sub get_success_chance {
	my ($monster) = @_;
	return 0 unless (exists $mobs_info->{$monster->{nameID}});
	
	my $skill_lvl = get_skill_lvl();
	return 0 if ($skill_lvl == 0);
	
	my $lvl = $char->{'lv'};
	my $dex = $char->{'dex'};
	my $luk = $char->{'luk'};
	my $stats = $dex + $luk;
	
	my $mob_lvl = $mobs_info->{$monster->{nameID}}{lvl};
	my $delta_lvl = $lvl - $mob_lvl;
	
	my $success_chance = (($skill_lvl * 10) + ($delta_lvl * 2) + ($stats / 2)) / 10; #If chance > rand 1000 : steal || maximum : 678
	
	return $success_chance;
}

sub get_medium_zeny_gained {
	my ($monster) = @_;
	return 0 unless (exists $mobs_info->{$monster->{nameID}});
	my $mob_lvl = $mobs_info->{$monster->{nameID}}{lvl};
	
	my $skill_lvl = get_skill_lvl();
	return 0 if ($skill_lvl == 0);
	
	my $medium_zeny_gained = (($mob_lvl * $skill_lvl) / 10) + ($mob_lvl * 9);
	
	return $medium_zeny_gained;
}

sub get_zenyPerSP {
	my ($monster) = @_;
	
	return 0 unless (exists $mobs_info->{$monster->{nameID}});
	my $mob_lvl = $mobs_info->{$monster->{nameID}}{lvl};
	
	my $skill_lvl = get_skill_lvl();
	return 0 if ($skill_lvl == 0);
	
	my $success_chance = get_success_chance($monster);
	return 0 if ($success_chance <= 0);
	
	my $skill_sp_cost = get_skill_sp_cost();
	my $medium_zeny_gained = get_medium_zeny_gained($monster);

	my $zeny_to_chance = ($medium_zeny_gained * $success_chance) / 100;

	my $sp_to_zeny_chance = $zeny_to_chance / $skill_sp_cost;
	
	return $sp_to_zeny_chance;
}

sub extendedCheck {
	my (undef, $args) = @_;

	return 0 if !$args->{monster} || $args->{monster}->{nameID} eq '';

	if (my $value = $config{$args->{prefix} . '_MugZenyPerSP'}) {
		my $sp_value = get_zenyPerSP($args->{monster});
		return $args->{return} = 0 if ($sp_value == 0);
		return $args->{return} = 0 unless (inRange($sp_value, $value));
	}

	if (my $value = $config{$args->{prefix} . '_MugSucessChance'}) {
		my $success_chance = get_success_chance($args->{monster});
		return $args->{return} = 0 if ($success_chance == 0);
		return $args->{return} = 0 unless (inRange($success_chance, $value));
	}

	if (my $value = $config{$args->{prefix} . '_MugZenyStealAmount'}) {
		my $medium_zeny_gained = get_medium_zeny_gained($args->{monster});
		return $args->{return} = 0 if ($medium_zeny_gained == 0);
		return $args->{return} = 0 unless (inRange($medium_zeny_gained, $value));
	}

	return 1;
}

1;
