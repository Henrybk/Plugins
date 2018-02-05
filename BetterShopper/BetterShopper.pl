##############################
# =======================
# BetterShopper v1.8
# =======================
# This plugin is licensed under the GNU GPL
# Created by Henrybk from openkorebrasil
# Based on the shopper plugin made by kaliwanagan on 2006 which was also licensed under the GNU GPL
#
# What it does: Opens vending shops and buys desired items.
#
# Config keys (put in config.txt):
#	BetterShopper_on 1/0  # Activates the plugin
#
#
# Config blocks: (used to buy items)
###############################################
#
# BetterShopper = Name of the item you want to buy.
# maxPrice = Maximum price of the item you want to buy.
# maxAmount = Amount of the item that you want to buy.
# disabled = Disables the blocks (this is set by default after a successful buying session)
#
# Example:
###############################################
#  BetterShopper Bow [4] {
#      maxPrice 1000
#      maxAmount 1
#      disabled 0
#  }
###############################################
package BetterShopper;

use strict;
use Plugins;
use Globals;
use Log qw(message warning error debug);
use AI;
use Misc;
use Utils qw(getFormattedDate);
use Network;
use Network::Send;
use POSIX;
use I18N qw(bytesToString stringToBytes);

Plugins::register('BetterShopper', 'automatically buy items from merchant vendors', \&Unload);

my $base_hooks = Plugins::addHooks(
	['postloadfiles', \&checkConfig],
	['configModify',  \&on_configModify]
);

use constant {
	PLUGIN_NAME => 'BetterShopper',
	RECHECK_TIMEOUT => 30,
	OPENSHOP_DELAY => 1,
	INACTIVE => 0,
	ACTIVE => 1
};

my $time = time;
my %recently_checked;
my %in_AI_queue;
my $shopping_hooks;
my $status = INACTIVE;

sub Unload {
	Plugins::delHook($base_hooks);
	changeStatus(INACTIVE);
	message "[".PLUGIN_NAME."] Plugin unloading or reloading.\n", 'success';
}

sub checkConfig {
	if (exists $config{PLUGIN_NAME.'_on'} && $config{PLUGIN_NAME.'_on'} == 1) {
		message "[".PLUGIN_NAME."] Config set to 'on' shopper will be active.\n", 'success';
		return changeStatus(ACTIVE);
	} else {
		return changeStatus(INACTIVE);
	}
}

sub on_configModify {
	my (undef, $args) = @_;
	return unless ($args->{key} eq (PLUGIN_NAME.'_on'));
	return if ($args->{val} eq $config{PLUGIN_NAME.'_on'});
	if ($args->{val} == 1) {
		message "[".PLUGIN_NAME."] Config set to 'on' shopper will be active.\n", 'success';
		return changeStatus(ACTIVE);
	} else {
		message "[".PLUGIN_NAME."] Config set to 'on' shopper will be active.\n", 'success';
		return changeStatus(INACTIVE);
	}
}

sub changeStatus {
	my $new_status = shift;
	
	return if ($new_status == $status);
	
	if ($new_status == INACTIVE) {
		Plugins::delHook($shopping_hooks);
		debug "[".PLUGIN_NAME."] Plugin stage changed to 'INACTIVE'\n", "shopper", 1;
		AI::clear('checkShop');
		undef %recently_checked;
		undef %in_AI_queue;
		
	} elsif ($new_status == ACTIVE) {
		$shopping_hooks = Plugins::addHooks(
			['AI_pre',              \&AI_pre],
			['packet_vender',       \&encounter],
			['packet_vender_store2',\&storeList],
			['packet_mapChange',    \&mapchange],
			['player_disappeared',  \&player_disappeared],
			['packet/vender_lost',  \&shop_closed],
		);
		debug "[".PLUGIN_NAME."] Plugin stage changed to 'ACTIVE'\n", "shopper", 1;
		
		foreach my $vender_index (0..$#venderListsID) {
			my $venderID = $venderListsID[$vender_index];
			next unless (defined $venderID);
			my $vender = $venderLists{$venderID};
			
			debug "[".PLUGIN_NAME."] Adding shop '".$vender->{'title'}."' of player '".get_player_name($venderID)."' to AI queue check list.\n", "shopper", 1;
			AI::queue('checkShop', {vendorID => $venderID});
		}
	}
	
	$status = $new_status;
}

sub mapchange {
	if (AI::inQueue('checkShop')) {
		debug "[".PLUGIN_NAME."] Clearing all 'checkShop' instances from AI queue because of a mapchange.\n", "shopper", 1;
		AI::clear('checkShop');
	}
}

sub get_player_name {
	my ($ID) = @_;
	my $player = Actor::get($ID);
	my $name = $player->nameIdx;
	return $name;
}

sub AI_pre {
	if (AI::is('checkShop') && main::timeOut($time, OPENSHOP_DELAY)) {
		$time = time;
		my $vendorID = AI::args->{vendorID};
		my $vender = $venderLists{$vendorID};
		if (defined $vender && grep { $vendorID eq $_ } @venderListsID) {
			debug "[".PLUGIN_NAME."] Openning shop '".$vender->{'title'}."' of player ".get_player_name($vendorID).".\n", "shopper", 1;
			$messageSender->sendEnteringVender($vendorID);
		}
		delete $in_AI_queue{$vendorID};
		AI::dequeue;
	}
}

# we encounter a vend shop
sub encounter {
	my ($packet, $args) = @_;
	my $ID = $args->{ID};
	my $title = $args->{title};
	
	if (!exists $in_AI_queue{$ID}) {
		if ( !exists $recently_checked{$ID} || ( exists $recently_checked{$ID} && main::timeOut($recently_checked{$ID}, RECHECK_TIMEOUT) ) ) {
			$in_AI_queue{$ID} = 1;
			debug "[".PLUGIN_NAME."] Adding shop '".$title."' of player ".get_player_name($ID)." to AI queue check list.\n", "shopper", 1;
			AI::queue('checkShop', {vendorID => $ID});
		}
	}
}

sub shop_closed {
	my ($packet, $args) = @_;
	my $ID = $args->{ID};
	if (exists $in_AI_queue{$ID}) {
		foreach my $seq_index (0..$#AI::ai_seq) {
			my $seq = @AI::ai_seq[$seq_index];
			my $seq_args = @AI::ai_seq_args[$seq_index];
			next unless ($seq eq 'checkShop');
			next unless ($seq_args->{vendorID} eq $ID);
			debug "[".PLUGIN_NAME."] Removing player ".get_player_name($ID)." from AI queue check list because shop disappeared.\n", "shopper", 1;
			splice(@AI::ai_seq, $seq_index, 1);
			splice(@AI::ai_seq_args, $seq_index, 1);
			last;
		}
	}
}

sub player_disappeared {
	my ($packet, $args) = @_;
	my $player = $args->{player};
	my $ID = $player->{ID};
	if (exists $in_AI_queue{$ID}) {
		foreach my $seq_index (0..$#AI::ai_seq) {
			my $seq = @AI::ai_seq[$seq_index];
			my $seq_args = @AI::ai_seq_args[$seq_index];
			next unless ($seq eq 'checkShop');
			next unless ($seq_args->{vendorID} eq $ID);
			debug "[".PLUGIN_NAME."] Removing player ".get_player_name($ID)." from AI queue check list because player disappeared.\n", "shopper", 1;
			splice(@AI::ai_seq, $seq_index, 1);
			splice(@AI::ai_seq_args, $seq_index, 1);
			last;
		}
	}
}

# we're currently inside a store if we receive this packet
sub storeList {
	my ($packet, $args) = @_;
	
	$recently_checked{$venderID} = time;	
	my @buyList;	
	my $current_zeny = $char->{zeny};	
	my %bought;
	
	foreach my $item (@{$args->{itemList}->getItems}) {
		my $price = $item->{price};
		my $name = $item->{name};
		
		my $prefix = PLUGIN_NAME.'_';
		my $current = 0;
		my $definitive;
		while (exists $config{$prefix.$current}) {
			next unless (lc($name) eq lc($config{$prefix.$current}));
			next unless ($price <= $config{$prefix.$current."_maxPrice"});
			next unless (main::checkSelfCondition($prefix.$current));
			$definitive = $current;
			last;
		} continue {
			$current++;
		}
		
		next unless (defined $definitive);
		
		my $config = $prefix.$definitive;		
		my $maxPrice = $config{$config."_maxPrice"};
		my $maxAmount = $config{$config."_maxAmount"};		
		my $index = $item->{ID};
		my $amount = $item->{amount};		
		my $inv_amount = $char->inventory->sumByName($name);		
		my $buy_amount = (exists $bought{$name} ? $bought{$name} : 0);		
		my $total = $inv_amount + $buy_amount;		
		next unless ($total < $maxAmount);		
		my $max_wanted = $maxAmount - $total;		
		my $max_can_buy = floor($current_zeny / $price);
		my $max_possible = $amount >= $max_can_buy ? $max_can_buy : $amount;		
		my $will_buy = $max_possible >= $max_wanted ? $max_wanted : $max_possible;		
		next if ($will_buy == 0);
		
		writter("Found item $name with good price! Price is $price, max price for it is $maxPrice! The store has $amount of it, with our zeny we can buy $max_possible! Buying $will_buy of it!");
		my $zeny_wasted = $will_buy * $price;		
		$bought{$name} += $will_buy;		
		$current_zeny -= $zeny_wasted;
		
		my %buy = (
			itemIndex => $index,
			amount    => $will_buy,
		);
		
		push(@buyList, \%buy);
	}
	
	return unless (@buyList);
	
	$messageSender->sendBuyBulkVender($venderID, \@buyList, $venderCID);
}
sub writter {
	my ($args, $self) = @_;
	my $tmp = "$Settings::logs_folder/Shopper.txt";
	
	open my $out, '>>:utf8', $tmp or die "Erro ao Abrir Arquivo";
	print $out "[".getFormattedDate(int(time))."] $args  \n";
	warning "$args \n";
	close $out;
	}
	


return 1;

