package Reconnect;

# Perl includes
use strict;

# Kore includes
use Settings;
use Plugins;
use Network;
use Globals;
use Log qw(message);


our $reconnect ||=
{
    'timeout' =>
    [
		30,     # 30 seconds
        30,     # 30 seconds
        60,     # 1 minute
        60,     # 1 minute
        180,    # 3 minutes
        180,    # 3 minutes
        300,    # 5 minutes
        300,    # 5 minutes
        900,    # 15 minutes
        900,    # 15 minutes
        1800,   # 30 minutes
        3600    # 1 hour
    ],

    'random'        => 20,
    'counter'       => 0
};

Plugins::register("Reconnect", "Version 0.1 r8", \&unload);

my $hooks = Plugins::addHooks(
    ['Network::connectTo', \&trying_to_connect],
    ['in_game', \&connected]
);

sub unload {
	Plugins::delHooks($hooks);
}

sub trying_to_connect {
	if ($reconnect->{counter} == 0) {
		my $reconnectTime = @{$reconnect->{timeout}}[$reconnect->{counter}];

		if($reconnect->{random}) {
			$reconnectTime += int(rand($reconnect->{random}));
		}

		$timeout{reconnect} = {'timeout' => $reconnectTime};
		
		$reconnect->{counter}++;
		
		return;
	}
	
	my $reconnectTime = @{$reconnect->{timeout}}[$reconnect->{counter}];
	
	message "[Reconnect] Login retry number '".$reconnect->{counter}."', setting reconnect timeout to ".$reconnectTime." seconds.\n", 'success';

	if ($reconnect->{random}) {
		$reconnectTime += int(rand($reconnect->{random}));
	}
	
	$timeout{reconnect} = {'timeout' => $reconnectTime};

	if ($reconnect->{counter} < $#{$reconnect->{timeout}}) {
		$reconnect->{counter}++;
	}
}

sub connected {
    $reconnect->{counter} = 0;

    my $reconnectTime = @{$reconnect->{timeout}}[$reconnect->{counter}];

    if ($reconnect->{random})  {
        $reconnectTime += int(rand($reconnect->{random}));
    }

    $timeout{reconnect} = {'timeout' => $reconnectTime};
}

1;