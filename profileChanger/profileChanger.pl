############################################################
#
# profileChanger
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
# What id does: Enables the change of profiles during execution
#
# How to use: 
# 1 - Create a folder on your control folder and name it 'profiles'.
# 2 - Inside the profile folder create your profiles, one folder for each.
# 3 - Create also inside this folder a text file named profileConf.txt.
# 4 - Open this file and add a line 'startingProfile profile'
# 5 - Change the 'profile' in the line to whichever profile you want to be loaded when openkore starts.
# 6 - Save and close the file.
# 7 - End.
#
# How it works: When openkore starts it will load all the config files it finds inside the profile folder you provided, the rest will be loaded from the original control folder.
#
# Commands:
# changeProfile 'profilename' => changes the current profile to the one provided, unloads the current files inside the old profile folder and load new ones from the new profile.
# changeStartingProfile 'profilename' => changes the profile name inside profileConf.txt to whichever profile name you provided, next time kore starts it will use this profile to load.
# 
# By Henrybk
#
############################################################
package profileChanger;

use strict;
use File::Spec;
use Plugins;
use Globals qw($interface $quit);
use Log qw(debug message warning error);
use Settings;
use Misc;

Plugins::register('profileChanger', 'profileChanger', \&Unload);

my $hooks = Plugins::addHooks(
      ['start', \&onStart]
   );

my $chooks = Commands::register(
	['changeProfile', "Changes profile", \&commandHandler],
	['changeStartingProfile', "Changes the starting profile", \&changeStartingProfile]
);

my $baseControlFolder;
my $pluginFolderInControl;
my $pluginConfigFile;

my $startingProfile;

my %profileList;

my $currentProfile;

# onUnload
sub Unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub onStart {
	$baseControlFolder = $Settings::controlFolders[0];
	$pluginFolderInControl = File::Spec->catdir($baseControlFolder, 'profiles');
	$pluginConfigFile = File::Spec->catfile($pluginFolderInControl, 'profileConf.txt');
	
	open my $conf, "<:utf8", $pluginConfigFile;
	while (<$conf>) {
		$. == 1 && s/^\x{FEFF}//;
			s/(.*)[\s\t]+#.*$/$1/;
			s/^\s*#.*$//;
			s/^\s*//;
			s/\s*[\r\n]?$//g;
			s/  +/ /g;
			next unless ($_);
			if (/^startingProfile\s+(\w+)$/i) {
				$startingProfile = $1;
			}
	}
	close($conf);
	
	unless (defined $startingProfile) {
		 $quit = 1;
		 return;
	}
	
	opendir my $d, $pluginFolderInControl;
	my @fileList = readdir($d);
	closedir $d;
	
	foreach (@fileList) {
		next unless -d File::Spec->catdir($pluginFolderInControl, $_);
		next if ($_ =~ /^\./);
		$profileList{$_} = 1;
	}
	
	unless (exists $profileList{$startingProfile}) {
		$quit = 1;
		return;
	}
	
	loadProfile($startingProfile, 1);
}

sub changeStartingProfile {
	my (undef, $profile) = @_;
	if (exists $profileList{$profile}) {
		open my $conf, ">:utf8", $pluginConfigFile;
		print $conf "startingProfile ".$profile."";
		close($conf);
		message "[PC] Starting profile changed from '".$startingProfile."' to '".$profile."' \n", "system";
		$startingProfile = $profile;
	} else {
		error "[PC] The profile you provided is not valid\n";
	}
}

sub commandHandler {
	if ($_[1] && exists $profileList{$_[1]}) {
		loadProfile($_[1], 0);
	} else {
		error "[PC] The profile you provided is not valid\n";
	}
}

sub loadProfile {
	my ($newProfile, $load) = @_;
	my $newProfileFolder = File::Spec->catdir($pluginFolderInControl, $newProfile);
	message "[PC] Preparing to load new profile '".$newProfile."' at '".$newProfileFolder."' \n", "system";
	if ($load) {
		unshift @Settings::controlFolders, $newProfileFolder;
	} else {
		my $oldProfile = $currentProfile;
		my %reloadFiles;
		message "[PC] Looking for loaded files in old profile '".$oldProfile."' to unload \n";
		foreach my $file (@{$Settings::files->getItems}) {
			next if ($file->{'type'} != 0);
			my $filepath;
			if ($file->{'autoSearch'} == 1) {
				$filepath = Settings::_findFileFromFolders($file->{'name'}, \@Settings::controlFolders);
			} else {
				$filepath = $file->{'name'};
			}
			my (undef,$directories,$filename) = File::Spec->splitpath($filepath);
			my @dirs = File::Spec->splitdir($directories);
			
			if ($dirs[-2] eq $oldProfile) {
				message "[PC] Unloading '".$filename."' from '".$oldProfile."'\n", "system";
				$reloadFiles{$file->{'index'}} = $filename;
			}
		}
		
		opendir my $d, $newProfileFolder;
		my @newProfileFiles = readdir($d);
		closedir $d;
		
		message "[PC] Looking for files in new profile '".$newProfile."'\n";
		foreach my $filename (@newProfileFiles) {
			next unless -f File::Spec->catdir($newProfileFolder, $filename);
			next if ($filename =~ /^\./);
			foreach my $file (@{$Settings::files->getItems}) {
				next if ($file->{'type'} != 0);
				next if (exists $reloadFiles{$file->{'index'}});
				if ($file->{'autoSearch'} == 1) {
					if ($file->{'name'} eq $filename) {
						$reloadFiles{$file->{'index'}} = $filename;
						message "[PC] Unloading '".$filename."' from '".$baseControlFolder."'\n", "system";
					}
				} else {
					my (undef,undef,$testFileName) = File::Spec->splitpath($file->{'name'});
					if ($testFileName eq $filename) {
						$reloadFiles{$file->{'index'}} = $filename;
						message "[PC] Unloading '".$filename."' from '".$baseControlFolder."'\n", "system";
					}
				}
			}
		}
		
		shift @Settings::controlFolders;
		unshift @Settings::controlFolders, $newProfileFolder;
		
		message "[PC] Loading necessary files\n";
		foreach my $relodingFileIndex (keys %reloadFiles) {
			my $reloadingFile = $Settings::files->get($relodingFileIndex);
			my $filename = $reloadFiles{$relodingFileIndex};
			my $newFilePath = Settings::_findFileFromFolders($filename, \@Settings::controlFolders);
			if ($reloadingFile->{'autoSearch'} == 0) {
				$reloadingFile->{'name'} = $newFilePath;
			}
			
			my (undef,$directories,undef) = File::Spec->splitpath($newFilePath);
			my @dirs = File::Spec->splitdir($directories);
			
			if ($dirs[-2] eq $newProfile) {
				message "[PC] Loading '".$filename."' from '".$newProfile."'\n", "system";
			} else {
				message "[PC] Loading '".$filename."' from '".$baseControlFolder."'\n", "system";
			}
			
			if (ref($reloadingFile->{loader}) eq 'ARRAY') {
				my @array = @{$reloadingFile->{loader}};
				my $loader = shift @array;
				$loader->($newFilePath, @array);
			} else {
				$reloadingFile->{loader}->($newFilePath);
			}
			
		}
		message "[PC] Loading ended, enjoy.\n", "system";
	}
	$currentProfile = $newProfile;
}

return 1;
