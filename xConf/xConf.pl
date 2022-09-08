# xConf plugin by 4epT (ICQ 2227733)
# Based on Lims idea
# Version: 5.0
# Last changes 30.08.2022 by Henrybk
# Plug-in for change mon_control/items_contro, using console commands.
#
# Examples of commands:
# mconf Spore 0 0 0
# mconf 1014 0 0 0
#
# iconf Meat 50 1 0
# iconf 517 50 1 0
#

package xConf;

use strict;
use Plugins;
use Globals;
use Log qw(message error debug warning);
use Misc qw(parseReload itemNameSimple);

Plugins::register('xConf', 'commands for change items_control, mon_control', \&Unload, \&Unload);

my $chooks = Commands::register(
	['iconf', 'edit items_control.txt', \&xConf],
	['mconf', 'edit mon_control.txt', \&xConf],
);

sub Unload {
	Commands::unregister($chooks);
	message "xConf plugin reloading or unloading\n", 'success'
}

sub GetNamebyID {
	my $itemID = shift;

	my $name = itemNameSimple($itemID);
	
	my $numSlots = $itemSlotCount_lut{$itemID};
	
	$name .= " [$numSlots]" if $numSlots;
	
    return $name;
}

sub xConf {
	my ($cmd, $args) = @_;
	my ($file, $file2, $found, $key, $oldval, $type, $value, $name, $inf_hash, $ctrl_hash);
	
	($key, $value) = $args =~ /([\s\S]+?)(?:\s)([\-\d\.]+[\s\S]*)/;
	$key = $args if !$key;
	$key =~ s/^\s+|\s+$//g;
	debug "extracted from args: KEY: $key, VALUE: $value\n";
	if (!$key) {
		error "Syntax Error in function '$cmd'. Not found <key>\n".
				"Usage: $cmd <key> [<value>]\n";
		return;
	}
	if ($cmd eq 'iconf') {
		$inf_hash  = \%items_lut;
		$ctrl_hash = \%items_control;
		$file = 'items_control.txt';
		$file2 = 'tables\..\items.txt';
		$type = 'Item';
	} elsif ($cmd eq 'mconf') {
		$inf_hash  = \%monsters_lut;
		$ctrl_hash = \%mon_control;
		$file = 'mon_control.txt';
		$file2 = 'tables\..\monsters.txt';
		$type = 'Monster';
	} 
	
	## Check $key in tables\monsters.txt & tables\items.txt
	if ($key ne "all") {

		#key is an ID, have to find the name of the item/monster
		if (exists $inf_hash->{$key}) {
			debug "key is an ID, $type '$inf_hash->{$key}' ID: $key is found in file '$file2'.\n";
			$found = 1;
			if ($cmd eq 'iconf') {
				$name = GetNamebyID($key);
			} else {
				$name = $inf_hash->{$key};
			}

		#key is a name, have to find ID of the item/monster
		} else {
			foreach (values %{$inf_hash}) {
				if ((lc($key) eq lc($_))) {
					$name = $_;
					foreach my $ID (keys %{$inf_hash}) {
						if ($inf_hash->{$ID} eq $name) {
							$key = $ID;
							$found = 1;
							debug "$type '$name' found in file '$file2'.\n";
							last;
						}
					}
					last;
				}
			}
		}

		#at this point, $key is always the ID of the item/monster
		#and the name is stored on $name
	}
	
	my $realKey;
	
	if (exists $ctrl_hash->{$name} || exists $ctrl_hash->{lc($name)}) {
		$realKey = $name;
	} else {
		$realKey = $key;
	}
	
	my $old_key;
	if (exists $ctrl_hash->{$name}) {
		$old_key = $name;
	} elsif (exists $ctrl_hash->{lc($name)}) {
		$old_key = lc($name);
	} elsif (exists $ctrl_hash->{$key}) {
		$old_key = $key;
	}
	
	if (defined $old_key) {
		if ($cmd eq 'iconf') {
			$oldval = sprintf("%s %s %s %s %s", $ctrl_hash->{$old_key}{keep}, $ctrl_hash->{$old_key}{storage}, $ctrl_hash->{$old_key}{sell},
				$ctrl_hash->{$old_key}{cart_add}, $ctrl_hash->{$old_key}{cart_get});
		} elsif ($cmd eq 'mconf') {
			$oldval = sprintf("%s %s %s %s %s", $ctrl_hash->{$old_key}{attack_auto}, $ctrl_hash->{$old_key}{teleport_auto},
				$ctrl_hash->{$old_key}{teleport_search}, $ctrl_hash->{$old_key}{skillcancel_auto}, $ctrl_hash->{$old_key}{attack_lvl},
				$ctrl_hash->{$old_key}{attack_jlvl}, $ctrl_hash->{$old_key}{attack_hp}, $ctrl_hash->{$old_key}{attack_sp},
				$ctrl_hash->{$old_key}{weight});
		}
	}
	
	$oldval =~ s/\s+$//g;
	$value =~ s/\s+$//g;
	
	debug "VALUE: '$value' | OLDVALUE: '$oldval'\n";
	debug "key: '$key' | realKey: '$realKey' | old_key: '$old_key'\n";
	
	if (!defined $value) {
		if (!defined $oldval) {
			error "$type '$key' is not found in file '$file'!\n";
		} else {
			message "$file: '$key' is $oldval\n", "info";
		}
	} else {
		filewrite($file, $key, $value, $name, $realKey);
	}
}

## write FILE
sub filewrite {
	my ($file, $key, $value, $name, $realKey) = @_;
	my @value;
	my $controlfile = Settings::getControlFilename($file);
	debug "sub WRITE = FILE: $file\nKEY: $key\nVALUE: $value\nNAME: $name\nREALKEY: $realKey\n";

	open(FILE, "<:encoding(UTF-8)", $controlfile);
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;
	
	my @new_lines;

	my $used = 0;
		@value = split(/\s+/, $value);
		my $index = 0;
		foreach my $line (@lines) {
			my ($what) = $line =~ /([\s\S]+?)\s[\-\d\.]+[\s\S]*/;
			$what =~ s/\s+$//g;
			$what =~ s/\"$//g;
			$what =~ s/^\"//g;
			$what = lc($what);
			my $tmp;
			if (lc($what) eq lc($realKey) || lc($what) eq lc($name) || $what == $key) {
				debug "Found old in line $index: $line\n";
			} else {
				push (@new_lines, $line);
			}
		} continue {
			$index++;
		}
		
		my $new_value = $key.' '.$value. " #". $name;
		
		debug "New record in line $index: $new_value\n";
		
		push (@new_lines, $new_value);
	
	open(WRITE, ">:utf8", $controlfile);
	print WRITE join ("\n", @new_lines);
	close(WRITE);
	parseReload($file);
}

1;
