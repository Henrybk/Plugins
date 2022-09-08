package checkAggressive;

use utf8;
use strict;
use warnings;
use File::Spec;
use JSON::Tiny qw(from_json to_json);
use FileParsers;
use Plugins;
use Settings;
use Globals;
use Log qw(message error debug warning);

Plugins::register('checkAggressive', 'checkAggressive', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['start3',						\&on_start3, undef],
	['ai_check_Aggressiveness',		\&on_ai_check_Aggressiveness, undef],
);

use constant {
	PLUGIN_NAME => 'checkAggressive',
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

sub on_ai_check_Aggressiveness {
	my ($self, $args) = @_;
	
	my $monster = $args->{monster};
	
	return unless (exists $mobs_info->{$monster->{nameID}});
	return unless ($mobs_info->{$monster->{nameID}}{is_aggressive} == 1);
	
	#$mobs_info->{$monster->{nameID}}{lvl}
	#$mobs_info->{$monster->{nameID}}{is_aggressive}
	
	return unless (Misc::checkMonsterCleanness($monster->{ID}));
	
	return unless (Misc::objectIsMovingTowards($monster, $char));
	
	debug "[".PLUGIN_NAME."] Monster $monster at ($monster->{pos}{x} $monster->{pos}{y}) | Lvl $mobs_info->{$monster->{nameID}}{lvl} | is Aggressive, clean, and coming to us\n";
	
	$args->{return} = 1;
	return;
}

1;