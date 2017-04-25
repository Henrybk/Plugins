##########################
# =======================
# teleToLocation v1.3
# =======================
# This plugin is licensed under the GNU GPL
# Created by Henrybk
#
# What it does: Uses teleport to try to get to a location in a map
#
#
# Example (put in config.txt):
#	
#	Config example:
#	   teleToLocation_on 1                # Boolean active/inactive
#      teleToLocation_map pay_fild10      # Map in which you want to use the plugin
#      teleToLocation_xy 100 150          # X and Y coordinates which you want to get near to by teleporting with the plugin
#      teleToLocation_distance 10         # Distance to the coordinate set in teleToLocation_xy with which the plugin will stop teleporting and decide it reached the destination
#      teleToLocation_type steps   # Type of distance to be used in teleToLocation_distance, you can use steps or radius, steps will be the distance the character has to walk to get to teleToLocation_xy and radius will be the arithmetic distance to teleToLocation_xy
#
##########################
package teleToLocation;

use strict;
use warnings;
use Settings;
use Plugins;
use Misc;
use Globals qw($char %config $net %timeout %maps_lut $field);
use Log qw(message error debug);
use Utils;

Plugins::register("teleToLocation", "teleToLocation", \&on_unload, \&on_unload);

use constant {
	INACTIVE => 0,
	ACTIVE => 1,
	TELEPORTING => 2
};

my $base_hooks = Plugins::addHooks(
	['postloadfiles', \&checkConfig],
	['configModify',  \&on_configModify]
);

my $plugin_name = "teleToLocation";

my $status = INACTIVE;
my $coordinate_x;
my $coordinate_y;
my $mapchange_hook;
my $teleporting_hook;
my $timeout = { time => 0, timeout => 1 };

sub on_unload {
   Plugins::delHook($base_hooks);
   changeStatus(INACTIVE);
   message "[$plugin_name] Plugin unloading or reloading.\n", 'success';
}

sub checkConfig {
	return changeStatus(ACTIVE) if (validate_config() && $config{teleToLocation_on});
	return changeStatus(INACTIVE);
}

sub on_configModify {
	my (undef, $args) = @_;
	return unless ($args->{key} eq 'teleToLocation_on' || $args->{key} eq 'teleToLocation_map' || $args->{key} eq 'teleToLocation_xy' || $args->{key} eq 'teleToLocation_distance' || $args->{key} eq 'teleToLocation_type');
	return changeStatus(ACTIVE) if (validate_config($args->{key}, $args->{val}) && ($args->{key} eq 'teleToLocation_on' ? $args->{val} : $config{teleToLocation_on}));
	return changeStatus(INACTIVE);
}

sub validate_config {
	my ($key, $val) = @_;

	if ((!defined $config{teleToLocation_on} || !defined $config{teleToLocation_map} || !defined $config{teleToLocation_xy} || !defined $config{teleToLocation_distance} || !defined $config{teleToLocation_type}) || (defined $key && !defined $val)) {
		message "[$plugin_name] There are config keys not defined, plugin won't be activated.\n","system";
		return 0;
	}
	
	return 0 unless ( validate_teleToLocation_on( defined $key && $key eq 'teleToLocation_on' ? $val : $config{teleToLocation_on} ) );
	
	return 0 unless ( validate_teleToLocation_map( defined $key && $key eq 'teleToLocation_map' ? $val : $config{teleToLocation_map} ) );
	
	return 0 unless ( validate_teleToLocation_xy( defined $key && $key eq 'teleToLocation_xy' ? $val : $config{teleToLocation_xy} ) );
	
	return 0 unless ( validate_teleToLocation_distance( defined $key && $key eq 'teleToLocation_distance' ? $val : $config{teleToLocation_distance} ) );
	
	return 0 unless ( validate_teleToLocation_type( defined $key && $key eq 'teleToLocation_type' ? $val : $config{teleToLocation_type} ) );
	
	return 1;
}

sub validate_teleToLocation_on {
	my ($val) = @_;
	if ($val !~ /[01]/) {
		message "[$plugin_name] Value of key 'teleToLocation_on' must be 0 or 1, plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub validate_teleToLocation_map {
	my ($val) = @_;
	my $map_name = $val;
	$map_name =~ s/^(\w{3})?(\d@.*)/$2/;
	my $file = $map_name.'.fld';
	$file = File::Spec->catfile($Settings::fields_folder, $file) if ($Settings::fields_folder);
	$file .= ".gz" if (! -f $file); # compressed file
	unless ($maps_lut{"${map_name}.rsw"} || -f $file) {
		message "[$plugin_name] Map '".$val."' does not exist, plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub validate_teleToLocation_xy {
	my ($val) = @_;
	if ($val =~ /(\d+)\s+(\d+)/) {
		$coordinate_x = $1;
		$coordinate_y = $2;
	} else {
		message "[$plugin_name] Value of key 'teleToLocation_xy' is not a valid coordinate ('".$val."'), plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub validate_teleToLocation_distance{
	my ($val) = @_;
	if ($val !~ /\d+/) {
		message "[$plugin_name] Value of key 'teleToLocation_distance' is not a valid number ('".$val."'), plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub validate_teleToLocation_type {
	my ($val) = @_;
	if ($val !~ /(radius|steps)/) {
		message "[$plugin_name] Value of key 'teleToLocation_type' is not a valid method ('".$val."'), plugin won't be activated.\n","system";
		return 0;
	}
	return 1;
}

sub changeStatus {
	my $new_status = shift;
	my $old_status = $status;
	if ($new_status == INACTIVE) {
		Plugins::delHook($mapchange_hook) if ($status == ACTIVE || $status == TELEPORTING);
		Plugins::delHook($teleporting_hook) if ($status == TELEPORTING);
		undef $coordinate_x;
		undef $coordinate_y;
		debug "[$plugin_name] Plugin stage changed to 'INACTIVE'\n";
	} elsif ($new_status == ACTIVE) {
		Plugins::delHook($teleporting_hook) if ($status == TELEPORTING);
		$mapchange_hook = Plugins::addHooks(
			['packet/sendMapLoaded', \&on_map_loaded]
		);
		debug "[$plugin_name] Plugin stage changed to 'ACTIVE'\n";
	} elsif ($new_status == TELEPORTING) {
		$teleporting_hook = Plugins::addHooks(
			['AI_pre',            \&on_ai_pre]
		);
		debug "[$plugin_name] Plugin stage changed to 'TELEPORTING'\n";
	}
	
	$status = $new_status;
	
	if ($new_status == ACTIVE && $old_status == INACTIVE && $char && $net->getState == Network::IN_GAME && ($config{'teleToLocation_map'} eq $field->baseName || $config{'teleToLocation_map'} eq $field->name)) {
		if ($field->width < $coordinate_x) {
			message "[$plugin_name] Value of key 'teleToLocation_xy' is not a valid coordinate, teleToLocation disabled.\n","system";
			configModify('teleToLocation_on', 0);
		} elsif ($field->height < $coordinate_y) {
			message "[$plugin_name] Value of key 'teleToLocation_xy' is not a valid coordinate, teleToLocation disabled.\n","system";
			configModify('teleToLocation_on', 0);
		} else {
			changeStatus(TELEPORTING);
		}
	}
}

sub on_map_loaded {
	if ($status == TELEPORTING) {
		if (($config{'teleToLocation_map'} eq $field->baseName || $config{'teleToLocation_map'} eq $field->name)) {
			debug "[$plugin_name] Character is still inside goal map.\n";
		} else {
			debug "[$plugin_name] Character for some reason left the goal map, changing plugin stage.\n";
			changeStatus(ACTIVE);
		}
	} else {
		if (($config{'teleToLocation_map'} eq $field->baseName || $config{'teleToLocation_map'} eq $field->name)) {
			if ($field->width < $coordinate_x) {
				message "[$plugin_name] Value of key 'teleToLocation_xy' is not a valid coordinate, teleToLocation disabled.\n","system";
				configModify('teleToLocation_on', 0);
			} elsif ($field->height < $coordinate_y) {
				message "[$plugin_name] Value of key 'teleToLocation_xy' is not a valid coordinate, teleToLocation disabled.\n","system";
				configModify('teleToLocation_on', 0);
			} else {
				debug "[$plugin_name] Character got to goal map, changing plugin stage.\n";
				changeStatus(TELEPORTING);
			}
		} else {
			debug "[$plugin_name] Character is still not inside goal map.\n";
		}
	}
}



sub on_ai_pre {
	return if !$char;
	return if $net->getState != Network::IN_GAME;
	return if !timeOut( $timeout );
	$timeout->{time} = time;
	if (check_distance()) {
		message "[$plugin_name] Using teleport.\n", "info";
		if (useTeleport(1)) {
			message "[$plugin_name] Teleport sent.\n", "info";
		} else {
			message "[$plugin_name] Cannot use teleport; teleToLocation disabled.\n", "info";
			configModify('teleToLocation_on', 0);
		}
	} else {
		message "[$plugin_name] Destination reached; teleToLocation disabled.\n", "info";
		configModify('teleToLocation_on', 0);
	}
}

sub check_distance {
	my $dist;
	if ($config{'teleToLocation_type'} eq 'radius') {
		$dist = round(distance($char->{pos_to}, { x => $coordinate_x, y => $coordinate_y }));
	} elsif ($config{'teleToLocation_type'} eq 'steps') {
		my $pathfinding = new PathFinding;
		my $myPos = $char->{pos_to};
		my $myDest = { x => $coordinate_x, y => $coordinate_y };
		$pathfinding->reset(
			start => $myPos,
			dest  => $myDest,
			field => $field
			);
		$dist = $pathfinding->runcount;
	}
	return 1 if ($dist > $config{teleToLocation_distance});
	return 0;
}

return 1;