############################################################
#
# zenyLog
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
# What id does: Saves specific information on your zeny income, it
# can save all your zeny income from the skill Steal Coin and items
# sold to npcs and create a log of it.
#
# How to use: Configure your config txt as follows, 1 activates and
# 0 deactivates.
#
# zenyLogStealCoin 1/0 #Saves zeny income of the skill Steal Coin
# zenyLogNpcSell 1/0 #Saves zeny income of items sold to npcs
# zenyLogSaveLog 1/0 #Creates a log on the log directory with the information
#
# To see your log and/or save it you must use the console command 'createZenyLog'.
# 
# By Henrybk
#
############################################################
package zenyLog;
 
use strict;
use Plugins;
use Settings;
use Globals;
use Utils;
use Misc;
use Log qw(message error warning);
use Network;
 
#########
# startup
Plugins::register('zenyLog', 'Creates a detailed zeny log', \&Unload, \&Unload);

my $hooks = Plugins::addHooks(
	['zeny_change',\&on_zeny_change, undef],
	['packet_pre/sell_result',\&on_sell_result, undef],
	['packet_pre/skill_used_no_damage',\&on_skill_used_no_damage, undef]
);
 
my $chooks = Commands::register(
	['createZenyLog', "Creates the zeny log", \&commandHandler]
);

my $lastZeny = 0;
my $sellZeny = 0;
my $stealCoinZeny = 0;

# onUnload
sub Unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub on_zeny_change {
	my ($self, $args) = @_;
	if ($args->{change} > 0) {
		$lastZeny = $args->{change};
	}
}

sub on_sell_result {
	my ($self, $args) = @_;
	$sellZeny += $lastZeny;
	message "[zenyLog] Zeny added to sell log: $lastZeny\n";
	message "[zenyLog] Total sell log zeny: $sellZeny\n";
	$lastZeny = 0;
}

sub on_skill_used_no_damage {
	my ($self, $args) = @_;
	if ($args->{skillID} = 211) {
		$stealCoinZeny += $lastZeny;
		message "[zenyLog] Zeny added to Steal Coin log: $lastZeny\n";
		message "[zenyLog] Total Steal Coin log zeny: $stealCoinZeny\n";
		$lastZeny = 0;
	}
}
 
sub commandHandler {
	my ($endTime_EXP, $w_sec, $sellZenyPerHour, $stealCoinZenyPerHour);
	$endTime_EXP = time;
	$w_sec = int($endTime_EXP - $startTime_EXP);
	message "[zenyLog] createZenyLog called\n";
	if ($config{'zenyLogNpcSell'}) {
		$sellZenyPerHour = int($sellZeny / $w_sec * 3600);
		message "SellZeny: $sellZeny\n".
		"SellZeny/Hour: $sellZenyPerHour\n";
	}
	if ($config{'zenyLogStealCoin'}) {
		$stealCoinZenyPerHour = int($stealCoinZeny / $w_sec * 3600);
		message "StealCoinZeny: $stealCoinZeny\n".
		"StealCoinZeny/Hour: $stealCoinZenyPerHour\n";
	}
	if ($config{'zenyLogSaveLog'}) {
		open(WRITE, ">:utf8", "$Settings::logs_folder/zenyLog.txt");
		print WRITE "[zenyLog] Log of the plugin zenyLog\n".
		"Log of the character: $char->{name}\n".
		"Botting time: ".timeConvert($w_sec)."\n";
		if ($config{'zenyLogNpcSell'}) {
			print WRITE "SellZeny: $sellZeny\n".
			"SellZeny/Hour: $sellZenyPerHour\n";
		}
		if ($config{'zenyLogStealCoin'}) {
			print WRITE "StealCoinZeny: $stealCoinZeny\n".
			"StealCoinZeny/Hour: $stealCoinZenyPerHour\n";
		}
		close(WRITE);
		message "[zenyLog] Info saved to Log File\n";
	}
	message "[zenyLog] end of log\n";
}



return 1;