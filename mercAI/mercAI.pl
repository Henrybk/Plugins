#############
# plugin mercAI - v1.1
# Created by Flamer in 13/06/2016
# Adapted by Henrybk in 30/04/2017
#############
package mercAI;

use strict;
no warnings qw(redefine uninitialized);
use Time::HiRes qw(time);
use encoding 'utf8';
use Plugins;
use Utils qw( timeOut );
use Log qw (warning message debug error);
use Commands;
use Settings;
use Plugins;
use Skill;
use Utils;
use Utils::Exceptions;
use AI;
use Misc qw(itemNameSimple);
use Globals;

#Hash para colocar os pesos dos itens que você vai recolocar para vender!
my %items_weight = (
	"Erva Branca" => 7,
);

my $config_key = 'vendorAi';

my $total;
my $end;
my ($startTime, $refresh);

#-----------------
# Plugin: settings
#-----------------
Plugins::register("mercAI", "AI for Vendor", \&on_unload, \&on_reload);
my $hook = Plugins::addHooks(
	["AI_pre", \&mainOut],
);

#---------------
# Plugin: on_unload
#---------------
sub on_unload {
	Plugins::delHooks($hook);
}

sub on_reload {
	&on_unload;
}

sub mainOut {
	my $timeout = 400;
	if (timeOut($startTime, $timeout)) {
		my $list_len = check_param();
		warning ("[mercAi] - Plugin is now working\n");
		AI::clear("move", "route", "autoBuy", "autoStorage");
		$startTime = time;
		$refresh = time;
	}
}

#---------------
# Plugin: Main Code
#---------------

sub check_param {
	my $retn = check_config_enabled();
	return $retn;
}

sub check_config_enabled {
	my ($item, $min_amount, $max_amount, $storage_get, $cart_add, $straight, $limit, $end, $amount, $inventory_check, $storage_check);
	$min_amount = 0;
	for (my $i = 0; exists $config{$config_key.'_'.$i}; $i++) {
		if (!$config{$config_key.'_'.$i} || $config{$config_key.'_'.$i.'_disabled'}) {
			$total += 1;
			next;
		}
		
		$item            = $config{$config_key.'_'.$i};
		$min_amount      = $config{$config_key.'_'.$i.'_cart_min_amount'} if ($config{$config_key.'_'.$i.'_cart_min_amount'});
		$max_amount      = $config{$config_key.'_'.$i.'_cart_max_amount'} if ($config{$config_key.'_'.$i.'_cart_max_amount'});
		$storage_get     = $config{$config_key.'_'.$i.'_storage_get'}     if ($config{$config_key.'_'.$i.'_storage_get'});
		$cart_add        = $config{$config_key.'_'.$i.'_cart_add'}        if ($config{$config_key.'_'.$i.'_cart_add'});
		$straight        = $config{$config_key.'_'.$i.'_straight'}        if ($config{$config_key.'_'.$i.'_straight'});
		$limit           = $config{$config_key.'_'.$i.'_limit'}           if ($config{$config_key.'_'.$i.'_limit'});
		$amount          = cart_check($item, $min_amount, $max_amount, $storage_get, $cart_add, $straight);
		if ($limit) {
			$inventory_check = inventory_check($item, $min_amount, $limit, $max_amount, $config{$config_key.'_'.$i}, $cart_add);
		} else {
			$inventory_check = inventory_check($item, $min_amount, $amount, $max_amount, $config{$config_key.'_'.$i}, $cart_add);
		}
		$storage_check   = storage_get($item, $amount, $straight) if ($amount <= $min_amount & $inventory_check && $storage_get eq 1 );
		$end = $i;
	}
	return eval($end - $total);
}

#---------------
#Plugin : Subs
#---------------

sub cart_check {
	my ($item, $min_amount, $max_amount, $storage_get, $cart_add, $straight) = @_;
	my ($limit, $cart_weight, $amount, $cart_weight_max);
	$cart_weight = $char->cart->{weight};
	$cart_weight_max = $char->cart->{weight_max};
	foreach my $item (@{$char->cart->getItems()}) {
		if ($item eq $item->{name}) {
			$limit = int(eval(($cart_weight_max - $cart_weight) / $items_weight{$item}));
			return $limit;
		}
	}
	return -1;
}

sub inventory_check {
	my ($needed, $min_amount, $limit, $max_amount, $perm, $cart_add) = @_;
	my ($limited, $char_weight, $name, $amount, $char_weight_max);
	my $startTime = time;
	next unless ($limit >= 0);
	$char_weight = $char->{'weight'};
	$char_weight_max = $char->{'weight_max'};
	$limited = int(eval(($char_weight_max - $char_weight) / $items_weight{$needed}));
	foreach my $item (@{$char->inventory->getItems()}) {
		if ($item->{name} eq $needed && $limit <= $min_amount) {
			cart_add($item, $amount) if ($amount <= $max_amount && $cart_add eq 1);
			cart_add($item, $max_amount) if ($amount >= $max_amount && $cart_add eq 1);
			return $item->{amount};
		}
	}
}

sub close_session {
	if ($total eq $end && $total != 0 && $end != 0) {
		#warning "Fechando o plugin mercAi\n";
		on_unload();
	}
}

sub gotoProntera {
my ($prontera, $tourx, $toury, $savepoint);
		$savepoint = "prontera 151 29";
		$savepoint =~ /(\w+) (\d+) (\d+)/ig;
		$prontera = $1;
		$tourx = $2 - int(rand(5));
		$toury = $3 - int(rand(5));
		if ("$char->{pos}{x} $char->{pos}{y}" ne "$tourx $toury") {	
			Commands::run("move $prontera $tourx $toury");
			$refresh = time;
			return 0;
		}
	return 1;
}

sub storage_get {
	my ($name, $amount, $straight) = @_;
	AI::queue("storageAuto");
	foreach my $item (@{$char->storage->getItems()}) {
			if ($item->{name} eq $name) {
				if ($straight eq 1) {
					Commands::run("storage gettocart $name $amount");
				} else {
					Commands::run("storage get $name $amount");
					cart_add($name, $amount);
					return 1;
				}
			} else {
				return 2;
			}
		return 0;
	}
} 

sub cart_add {
	my ($name, $amount) = @_;
	my $item = Match::inventoryItem($name);
	my $index = $item->{invIndex};
	Commands::run("cart add $index $amount");
}

return 1;