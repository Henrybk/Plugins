############################################################
#
# forgeWeapon
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
# Plugin made by Henrybk from openkore Brasil
#
# What id does: Enables the forging of weapons by smiths
#
# How to use: Use the command as follows:
# forgeWeapon WeaponID ExtraId01 ExtraId02 ExtraId03
#
# WeaponID is the ID of the wanted weapon, you can see this on forge_list after you use an appropriate hammer
# ExtraId01-03 can be star crumbs or elemental stones.
# 
# By Henrybk
#
############################################################
package forgeWeapon;
 
use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning);
use Network;
use Network::Send;


my $plugin_folder = $Plugins::current_plugin_folder;
my $file = $plugin_folder.'\forgeWeapon\forge.txt';
my %weapons;

my %elementalStonesIds = ('994' => 1, '995' => 1, '996' => 1, '997' => 1);

my $starCrumbID = 1000;

my @Ids;

my $sentForge = 0;

my $starCrumbCount = 0;
my $elementalID = 0;
 
#########
# startup
Plugins::register('forgeWeapon', 'Enables weapon creation', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['packet_pre/forge_list', \&on_forge_list, undef],
	['packet_pre/refine_result', \&on_refine_result, undef],
	['start3', \&parseForgeItems, undef]
);
 
my $chooks = Commands::register(
	['forgeWeapon', "Forges a weapon", \&commandHandler]
);

# onUnload
sub Unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub on_forge_list {
	$sentForge = 1;
	$messageSender->sendProduceMix($Ids[0], $Ids[1], $Ids[2], $Ids[3]);
}

sub on_refine_result {
	my (undef, $args) = @_;
	if (($args->{fail} == 0 || $args->{fail} == 1) && $sentForge) {
		$sentForge = 0;
		if ($starCrumbCount) {
			my $item = $char->inventory->getByNameID($starCrumbID);
			if ($item) {
				inventoryItemRemoved($item->{invIndex}, $starCrumbCount);
				Plugins::callHook('packet_item_removed', {index => $item->{invIndex}});
			}
		}
		if ($elementalID) {
			my $item = $char->inventory->getByNameID($elementalID);
			if ($item) {
				inventoryItemRemoved($item->{invIndex}, 1);
				Plugins::callHook('packet_item_removed', {index => $item->{invIndex}});
			}
		}
	}
}
 
sub commandHandler {
	my (undef, $args) = @_;
	### no parameter given
	if (!defined $args || (split(/\s+/, $args)) > 4) {
		message "[forgeWeapon] No arguments given!\n".
		"Usage: forgeWeapon WeaponID ExtraId01 ExtraId02 ExtraId03\n";
		return;
	}
	
	
	if (checkCanForge($args)) {
		(@Ids) = split(/\s+/, $args);
		my $item = $char->inventory->getByNameID($weapons{$Ids[0]}{'reqItem'});
		$item->use;
	}
}

sub checkCanForge {
	my ($args) = @_;
	my (@itemIds) = split(/\s+/, $args);

	my $forgeID = shift(@itemIds);

	$starCrumbCount = 0;
	$elementalID = 0;

	#Check if the item exists in the hash %weapons
	if (!exists $weapons{$forgeID}) {
		error "[forgeWeapon] The weapon id you provided is not known\n";
		return 0;
	}

	#Check if we have the hammer
	if (!$char->inventory->getByNameID($weapons{$forgeID}{'reqItem'})) {
		error "[forgeWeapon] You do not have the required hammer\n";
		return 0;
	}

	#Check if we have the skill
	if (!$char->getSkillLevel(new Skill(handle => $weapons{$forgeID}{'skillHandle'}))) {
		error "[forgeWeapon] You do not have the required skill\n";
		return 0;
	}

	#Check id we have enough materials
	my $item;
	my $wantedAmount;
	foreach my $materialID (keys %{$weapons{$forgeID}{'materials'}}) {
		$wantedAmount = $weapons{$forgeID}{'materials'}{$materialID};
		$item = $char->inventory->getByNameID($materialID);
		if (!$item) {
			error "[forgeWeapon] You do not have the material ".$items_lut{$materialID}."\n";
			return 0;
		} else {
			next if ($item->{amount} >= $wantedAmount);
			error "[forgeWeapon] You do not have enough ".$items_lut{$materialID}."\n";
			return 0;
		}
	} continue {
		undef $item;
		undef $wantedAmount;
	}
	

	foreach my $extraID (@itemIds) {
		if ($extraID == $starCrumbID) {
			$starCrumbCount++;
			next;
		} elsif (exists $elementalStonesIds{$extraID}) {
			if ($elementalID) {
				error "[forgeWeapon] You cannot use two elemental stones (".$items_lut{$elementalID}." and ".$items_lut{$extraID}.").\n";
				return 0;
			} else {
				if ($char->inventory->getByNameID($extraID)) {
					$elementalID = $extraID;
					next;
				} else {
					error "[forgeWeapon] You do not have the material ".$items_lut{$extraID}."\n";
					return 0;
				}
			}
		} else {
			error "[forgeWeapon] The item ".$items_lut{$extraID}." is not a Star Crumb neither an elemental stone\n";
			return 0;
		}
	}

	if ($starCrumbCount) {
		$item = $char->inventory->getByNameID($starCrumbID);
		if (!$item) {
			error "[forgeWeapon] You do not have the material ".$items_lut{$starCrumbID}."\n";
			return 0;
		} else {
			unless ($item->{amount} >= $starCrumbCount) {
				error "[forgeWeapon] You do not have enough ".$items_lut{$starCrumbID}."\n";
				return 0;
			}
		}
	}
	
	return 1;
}

sub parseForgeItems {
	undef %weapons;
	my ($openBlock, $forgeID, $reqItem, $skillHandle, $materialID, %materials);
	if ($file) {
		open my $plan, "<:utf8", $file;
		while (<$plan>) {
			$. == 1 && s/^\x{FEFF}//;
			s/(.*)[\s\t]+#.*$/$1/;
			s/^\s*#.*$//;
			s/^\s*//;
			s/\s*[\r\n]?$//g;
			s/  +/ /g;
			next unless ($_);
			if ($openBlock) {
				if (/^skillHandle\s(.+)$/i) {
					if (!$1) { 
						error "[ForgeWeapon] Unset value at line $., type: skillHandle. (Ignoring block)\n";
						$openBlock = 0;
						undef $forgeID;
						undef $reqItem;
						undef $skillHandle;
						undef $materialID;
						undef %materials;
					} else {
						$skillHandle = $1;
					}
				} elsif (/^reqItem\s(\d+)$/i) {
					$reqItem = $1;
				} elsif (/^item (\d+) {$/i) {
					$openBlock = 2;
					$materialID = $1;
				} elsif ($openBlock == 2) {
					 if (/^amount\s(\d+)/i) {
						$materials{$materialID} = $1;
					 } elsif (/} item (\d+) {$/i) {
						if (!exists ($materials{$materialID})) {
							error "[ForgeWeapon] Unset amount for material $materialID. (Ignoring block)\n";
							$openBlock = 0;
							undef $forgeID;
							undef $reqItem;
							undef $skillHandle;
							undef $materialID;
							undef %materials;
						} else {
							$materialID = $1;
						}
					 } elsif (/^}$/) {
						if (!exists ($materials{$materialID})) {
							error T("[ForgeWeapon] Unset amount for material $materialID. (Ignoring block)\n");
							$openBlock = 0;
							undef $forgeID;
							undef $reqItem;
							undef $skillHandle;
							undef $materialID;
							undef %materials;
						} else {
							$openBlock = 1;
						}
					 }
				} elsif (/^}$/) {
					if (!$reqItem || !$skillHandle || !%materials) {
						error "[ForgeWeapon] Unset value for item $forgeID. (Ignoring block)\n";
					} else {
						$weapons{$forgeID}{'reqItem'} = $reqItem;
						$weapons{$forgeID}{'skillHandle'} = $skillHandle;
						foreach my $material (keys %materials) {
							$weapons{$forgeID}{'materials'}{$material} = $materials{$material};
						}
					}
					$openBlock = 0;
					undef $forgeID;
					undef $reqItem;
					undef $skillHandle;
					undef $materialID;
					undef %materials;
				} else {
					$openBlock = 0;
					undef $forgeID;
					undef $reqItem;
					undef $skillHandle;
					undef $materialID;
					undef %materials;
					error "[ForgeWeapon] Unkown sintax at line $. (Ignoring block)\n";
				}
			} elsif (/^forge (\d+) {$/i) {
				$forgeID = $1;
				$openBlock = 1;
			}
		}
		close($plan);
	}
}



return 1;