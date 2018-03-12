#########################################################################
# AnswerEliza v1.0 alpha
# Made by Henrybk from openkorebrasil
# 
# Config to be put into npc_resps.txt
# 
# How to use:
# Just copy the damn files and folders as they are to your plugins folder and be sure it is active in your sys.txt (if you don't know how to do that just look at openkore's wiki)
#
# Also put these keys in tour config.txt
#   AnswerEliza_file AnswerEliza.txt
#   AnswerEliza_Pm 1
#
#########################################################################
package AnswerEliza;

use lib $Plugins::current_plugin_folder;

use strict;
use Actor;
use Modules 'register';
use Globals;
use Log qw(message debug error warning);
use Misc;
use Network;
use Network::Send ();
use Settings;
use Plugins;
use Skill;
use Utils;
use Utils::Exceptions;
use AI;
use Task;
use Task::ErrorReport;
use I18N qw(stringToBytes);

use Chatbot::Eliza;

use File::Spec;
use JSON::Tiny qw(from_json to_json);

Plugins::register("AnswerEliza", "AnswerEliza", \&on_unload);
my $hooks = Plugins::addHooks(
	['packet_privMsg', \&on_PM],
	['configModify', \&on_configModify, undef],
	['start3', \&on_start3, undef]
);

my $file_handle;
my $answerPm_file;
my %playerRegs;

my $plugin_name = 'AnswerEliza';

sub on_unload {
	Plugins::delHooks($hooks);
}

sub on_configModify {
	my (undef, $args) = @_;
	if ($args->{key} eq ($plugin_name.'_file')) {
		$answerPm_file = $args->{val};
		Settings::removeFile($file_handle);
		$file_handle = Settings::addControlFile($answerPm_file, loader => [ \&parsePlayersTalk, undef], mustExist => 0);
		Settings::loadByHandle($file_handle);
	}
}

sub on_start3 {
	$answerPm_file = (defined $config{$plugin_name.'_file'})? $config{$plugin_name.'_file'} : "AnswerEliza.txt";
	Settings::removeFile($file_handle) if ($file_handle);
	$file_handle = Settings::addControlFile($answerPm_file, loader => [ \&parsePlayersTalk, undef], mustExist => 0);
	Settings::loadByHandle($file_handle);
}

sub parsePlayersTalk {
	my $file = shift;
	
	undef %playerRegs;
	
	if (open FILE, "<:utf8", $file) {
		my @lines = <FILE>;
		close(FILE);
		chomp @lines;
		my $jsonString = join('',@lines);
		%playerRegs = %{from_json($jsonString, { utf8  => 1 } )};
		
	} else {
		error "[AnswerPM] Could not load players file.\n";
	}
}

sub FileWrite {
	my ($player, %regs) = @_;
	my ($Found, $StepsIndex, $StartStepIndex, $EndStepIndex);
	my $controlfile = Settings::getControlFilename($answerPm_file);
	if (!defined $controlfile) {
		$controlfile = File::Spec->catdir($Settings::controlFolders[0],$answerPm_file);
	}
	
	open(REWRITE, ">:utf8", $controlfile);
	print REWRITE to_json(\%playerRegs, {utf8 => 1, pretty => 1});
	close(REWRITE);
}

sub on_PM {
	return 0 unless ($config{$plugin_name.'_Pm'});
	my ($Type, $Args) = @_;
	my $player = $Args->{'MsgUser'};
	my $recievedMessage = $Args->{'Msg'};
	Main($recievedMessage,$player, "pm");
}

my %answering_hash;

sub Main {
	my ($recievedMessage, $player, $Type) = @_;
	##########
	#Clean Message
	##########
	$recievedMessage = lc($recievedMessage);
	$recievedMessage =~ s/\n//g;  # remove newlines
	$recievedMessage =~ s/\r//g;  # remove cariage returns;
	$recievedMessage =~ s/^_*//;  #remove leading underscores
	$recievedMessage =~ s/_*$//;  #remove trailing underscores
	$recievedMessage =~ s/^\s*//; #remove leading spaces
	$recievedMessage =~ s/\s*$//; #remove trailing spaces
	#$recievedMessage =~ s/[^0-9a-z]*$//;
	#$recievedMessage =~ s/^[^0-9a-z]*//;
	
	my $eliza;
	if (!exists $answering_hash{$player}) {
		$answering_hash{$player} = new Chatbot::Eliza;
	}
	$eliza = $answering_hash{$player};
	
	my $finalMessage = $eliza->transform( $recievedMessage );
	
	##########
	#Write File
	##########
	FileWrite();

	##########
	#Calculate answer time
	##########
	my $typeSpeed = writtingTime($finalMessage);
	
	##########
	#Organize answering hash
	##########
	my %answeringHash = (
			timeout => $typeSpeed,
			time => time,
			message => $finalMessage,
			type => $Type,
			user => $player
	);
	sendAnswer(\%answeringHash);
}

sub sendAnswer {
	my %args = %{$_[0]};
	my $task = new Task::Chained(
		tasks => [
			new Task::Wait(seconds => $args{timeout}),
			new Task::Function(function => sub {
				my ($task) = @_;
				if ($args{type} eq "c") {
					foreach my $player (@{$playersList->getItems()}) {
						next unless ($player->name eq $args{user});
						sendMessage($messageSender, "c", $args{message});
						goto End;
					}
				}
				sendMessage($messageSender, "pm", $args{message}, $args{user});
				End:
				$task->setDone();
			})
		]
	 );
	$taskManager->add($task);
}

sub writtingTime {
	my $string = $_[0];
	my @words = split (/\s+/, $string);
	my $time = (@words*(1.5));
	return $time;
}

1;