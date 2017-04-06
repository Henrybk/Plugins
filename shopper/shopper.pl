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
use I18N qw(bytesToString stringToBytes);

Plugins::register('shopper', 'automatically buy items from merchant vendors', \&Unload);

my $base_hooks = Plugins::addHooks(
	['postloadfiles', \&checkConfig],
	['configModify',  \&on_configModify]
);

use constant {
	INACTIVE => 0,
	ACTIVE => 1
};

my $delay = 1;
my $time = time;

my %recently_checked;
my %in_AI_queue;

my $recheck_timeout = 300;

my $shopping_hooks;

my $status = INACTIVE;

sub Unload {
	Plugins::delHook($base_hooks);
	changeStatus(INACTIVE);
	message "[shopper] Plugin unloading or reloading.\n", 'success';
}

sub checkConfig {
	if (exists $config{shopper_on} && $config{shopper_on} == 1) {
		message "[shopper] Config set to 'on' shopper will be active.\n", 'success';
		return changeStatus(ACTIVE);
	} else {
		message "[shopper] Config set to 'off' shopper will be inactive.\n", 'success';
		return changeStatus(INACTIVE);
	}
}

sub on_configModify {
	my (undef, $args) = @_;
	return unless ($args->{key} eq 'shopper_on');
	return if ($args->{val} eq $config{shopper_on});
	if ($args->{val} == 1) {
		message "[shopper] Config set to 'on' shopper will be active.\n", 'success';
		return changeStatus(ACTIVE);
	} else {
		message "[shopper] Config set to 'on' shopper will be active.\n", 'success';
		return changeStatus(INACTIVE);
	}
}

sub changeStatus {
	my $new_status = shift;
	
	return if ($new_status == $status);
	
	if ($new_status == INACTIVE) {
		Plugins::delHook($shopping_hooks);
		debug "[shopper] Plugin stage changed to 'INACTIVE'\n", "shopper", 1;
		AI::clear('checkShop');
		undef %recently_checked;
		undef %in_AI_queue;
		
	} elsif ($new_status == ACTIVE) {
		$shopping_hooks = Plugins::addHooks(
			['AI_pre', \&AI_pre],
			['packet_vender', \&encounter],
			['packet_vender_store', \&storeList],
			['packet_mapChange', \&mapchange],
			['player_disappeared', \&player_disappeared]
		);
		debug "[shopper] Plugin stage changed to 'ACTIVE'\n", "shopper", 1;
		
		foreach my $vender_index (0..$#venderListsID) {
			my $venderID = $venderListsID[$vender_index];
			next unless (defined $venderID);
			my $vender = $venderLists{$venderID};
			
			debug "[shopper] Adding shop '".$vender->{'title'}."' of player '".get_player_name($venderID)."' to AI queue check list.\n", "shopper", 1;
			AI::queue('checkShop', {vendorID => $venderID});
		}
	}
	
	$status = $new_status;
}

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
		my $vender = $venderLists{$vendorID};
		if (defined $vender && grep { $vendorID eq $_ } @venderListsID) {
			debug "[shopper] Openning shop '".$vender->{'title'}."' of player ".get_player_name($vendorID).".\n", "shopper", 1;
			$messageSender->sendEnteringVender($vendorID);
		}
		delete $in_AI_queue{$vendorID};
		AI::dequeue;
	}
	$time = time;
}

# we encounter a vend shop
sub encounter {
	my ($packet, $args) = @_;
	my $ID = $args->{ID};
	my $title = bytesToString($args->{title});
	
	if (!exists $in_AI_queue{$ID}) {
		if ( !exists $recently_checked{$ID} || ( exists $recently_checked{$ID} && main::timeOut($recently_checked{$ID}, $recheck_timeout) ) ) {
			$in_AI_queue{$ID} = 1;
			debug "[shopper] Adding shop '".$title."' of player ".get_player_name($ID)." to AI queue check list.\n", "shopper", 1;
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

