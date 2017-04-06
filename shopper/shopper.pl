package shopper;

#
# This plugin is licensed under the GNU GPL
# Copyright 2006 by kaliwanagan
# --------------------------------------------------
#

use strict;
use Plugins;
use Globals;
use Log qw(message warning error debug);
use AI;
use Misc;
use Network;
use Network::Send;
use POSIX;

Plugins::register('shopper', 'automatically buy items from merchant vendors', \&Unload);
my $AI_pre = Plugins::addHook('AI_pre', \&AI_pre);
my $encounter = Plugins::addHook('packet_vender', \&encounter);
my $lost = Plugins::addHook('packet/vender_lost', \&lost);
my $storeList = Plugins::addHook('packet_vender_store', \&storeList);
my $mapchange = Plugins::addHook('packet_mapChange', \&mapchange);
my $player_disappeared = Plugins::addHook('player_disappeared', \&player_disappeared);

my @vendorList;

sub Unload {
	Plugins::delHook('AI_pre', $AI_pre);
	Plugins::delHook('packet_vender', $encounter);
	Plugins::delHook('packet/vender_lost', $lost);
	Plugins::delHook('packet_vender_store', $storeList);
	Plugins::delHook('packet_mapChange', $mapchange);
	Plugins::delHook('player_disappeared', $player_disappeared);
}

my $delay = 1;
my $time = time;

my %recently_checked;
my %in_AI_queue;

my $recheck_timeout = 300;

sub mapchange {
	if (AI::inQueue('checkShop')) {
		debug "[shopper] Clearing all 'checkShop' instances from AI queue because of a mapchange.\n", "shopper", 1;
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
	if (AI::is('checkShop') && main::timeOut($time, $delay)) {
		my $vendorID = AI::args->{vendorID};
		
		debug "[shopper] Openning shopp of player ".get_player_name($vendorID).".\n", "shopper", 1;
		
		$messageSender->sendEnteringVender($vendorID) if (grep { $vendorID eq $_ } @venderListsID);
		delete $in_AI_queue{$vendorID};
		AI::dequeue;
	}
	$time = time;
}

# we encounter a vend shop
sub encounter {
	my ($packet, $args) = @_;
	my $ID = $args->{ID};
	
	if (!exists $in_AI_queue{$ID}) {
		if ( !exists $recently_checked{$ID} || ( exists $recently_checked{$ID} && main::timeOut($recently_checked{$ID}, $recheck_timeout) ) ) {
			$in_AI_queue{$ID} = 1;
			debug "[shopper] Adding player ".get_player_name($ID)." to AI queue check list.\n", "shopper", 1;
			AI::queue('checkShop', {vendorID => $ID});
		}
	}
}

sub lost {
	my ($packet, $args) = @_;
	my $ID = $args->{ID};
	if (exists $in_AI_queue{$ID}) {
		foreach my $seq_index (0..$#AI::ai_seq) {
			my $seq = @AI::ai_seq[$seq_index];
			my $seq_args = @AI::ai_seq_args[$seq_index];
			next unless ($seq eq 'checkShop');
			next unless ($seq_args->{vendorID} eq $ID);
			debug "[shopper] Removing player ".get_player_name($ID)." from AI queue check list because shop disappeared.\n", "shopper", 1;
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
			debug "[shopper] Removing player ".get_player_name($ID)." from AI queue check list because player disappeared.\n", "shopper", 1;
			splice(@AI::ai_seq, $seq_index, 1);
			splice(@AI::ai_seq_args, $seq_index, 1);
			last;
		}
	}
}

# we're currently inside a store if we receive this packet
sub storeList {
	my ($packet, $args) = @_;
	my $venderID = $args->{venderID};
	my $price = $args->{price};
	my $name = $args->{name};
	my $number = $args->{number};
	my $amount = $args->{amount};
	
	$recently_checked{$venderID} = time;

	my $prefix = "shopper_";
	my $i = 0;
	while (exists $config{$prefix.$i}) {
		my $maxPrice = $config{$prefix.$i."_maxPrice"};
		my $maxAmount = $config{$prefix.$i."_maxAmount"};

		if (
			main::checkSelfCondition($prefix.$i) &&
			($price <= $maxPrice) &&
			(lc($name) eq lc($config{$prefix.$i}))
		) {
			my $max_can_buy = floor($char->{zeny} / $price);
			my $max_possible = $amount >= $max_can_buy ? $max_can_buy : $amount;
			my $will_buy = $max_possible >= $maxAmount ? $maxAmount : $max_possible;
			
			message "Found item $name with good price! Price is $price, max price for it is $maxPrice! We want $maxAmount, the store has $amount and we can buy $max_possible! Buying $will_buy of it!\n";
			
			$messageSender->sendBuyBulkVender($venderID, [{itemIndex => $number, amount => $will_buy}], $venderCID);
			
			if ($will_buy == $maxAmount) {
				configModify($prefix.$i."_disabled", 1);
			} else {
				configModify($prefix.$i."_maxAmount", ($maxAmount - $will_buy));
			}
		}
		$i++;
	}
}

return 1;

