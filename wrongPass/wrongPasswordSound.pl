package wrongPasswordSound;

use Plugins;
use Globals;
use Utils;
use Log qw(message);
use Network::Send;
use Utils::Win32;
use Data::Dumper;
my $plugin_folder = $Plugins::current_plugin_folder;
my $path = $plugin_folder.'\wrongPasswordSound\password.wav';

Plugins::register('wrongPasswordSound', 'playes an alert sound when your kore inputs the wrong password', \&Unload);

my $hooks = Plugins::addHooks(
	['packet_pre/login_error', \&checkError, undef],
);


# onUnload
sub Unload {
	message "Plugin wrongPasswordSound unloading\n", 'success';
	Plugins::delHooks($hooks);
}

sub checkError {
	my ($self, $args) = @_;
	if ($args->{type} == 1) {
		Utils::Win32::playSound($path);
	}
}

return 1;