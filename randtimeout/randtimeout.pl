#########################################################################
# This software is open source, licensed under the GNU General Public
# License, version 2.
# Basically, this means that you're allowed to modify and distribute
# this software. However, if you distribute modified versions, you MUST
# also distribute the source code.
# See http://www.gnu.org/licenses/gpl.html for the full license.
#########################################################################
# Random Reconnnect Timeout (fixed)
# d3fc0n 1/12/2007
#
# What it does: Makes your reconnect time not regular
#
# Config keys (put in config.txt):
#	reconnect 50 # Change to the minimum amount of seconds you want to wait before reconnecting
#	reconnectSeed 30 # Change to the value of the maximum variation you want to add to reconnect
#########################################################################
package randtimeout;
 
use strict;
use Plugins;
use Globals qw(%config $masterServer %timeout);
use Log qw(message);
 
Plugins::register('randtimeout', 'Random Reconnnect Timeout', \&on_unload);
 
my $hooks = Plugins::addHooks(
      ['Network::connectTo', \&onConnectTo]
   );
 
sub on_unload {
   Plugins::delHooks($hooks);
}
 
sub onConnectTo {
   my (undef, $args) = @_;
 
   if ($args->{host} eq $masterServer->{ip} && $args->{port} eq $masterServer->{port}) {
 
      if ($config{'reconnect'}) {
         my $reconnect = $config{'reconnect'} + int(rand $config{'reconnectSeed'});
         message("[randtimeout] Reconnect timeout has been change to $reconnect second.\n", "system");
         $timeout{'reconnect'}{'timeout'} = $reconnect;
      }
   }
}
 
return 1;