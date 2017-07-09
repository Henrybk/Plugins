################################################################################
# This plugin was created as an idea of what a great answer plugin would be
# but because of my lack of time I'm releasing it now hopping that the community
# will fix it and put it to good use.
#
# Features: It is able to recognize some patterns in players sentences, like players
# asking for zeny/items, greetings, goodbyes, bot accusations and many others, it also
# has a "anger" counter, each time the script recognizes that the player has said the same
# thing more than one time in a row it will get a little angrier, it also has answers based
# on how many times the bot has been talked to, and has a block setting that blocks a player
# after it gets angry or has just talked too much. It also saves all the player info in a .txt
# for later use. It has a function of time recognition to know when was the last time
# a player has talked to you, but nothing implemented about it. It also can make little "errors"
# while typing to simulate a player possible errors, and it will then send the classic
# "word*" in the next sentence with the correct version of the words he got wrong.
#
# Known bugs: The Regex are all poorly made, there is no use for the time recognition feature,
# it sends the "word*" at the same time it sends the actual sentence.
#
# Features I would like to see implemented: A sql based database.
#
# Sorry for the poorly released version, once i get time i'll try to translate all comments to
# portuguese, i only happened to have this header here.
#
# ------------------
# Plugin by Henry from Openkore Brasil
#
# Example (put in config.txt):
#	
#	Config example:
#      AnswerChat_Pm 1
#      AnswerChat_Pub 1
#      AnswerChat_PubMax 1
#      AnswerChat_file AnswerChat.txt
#      AnswerChat_Error 1
#      AnswerChat_ErrorChance 5
#################################################################################
package AnswerChat;

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
use Match;
use Translation;
use I18N qw(stringToBytes);
use Network::PacketParser qw(STATUS_STR STATUS_AGI STATUS_VIT STATUS_INT STATUS_DEX STATUS_LUK);

use AnswerDatabse;

use File::Spec;
use JSON::Tiny qw(from_json to_json);

Plugins::register("AnswerChat", "AnswerChat", \&on_unload);
my $hooks = Plugins::addHooks(
	['packet_privMsg', \&on_PM],
	['packet_pubMsg', \&on_Pub],
	['configModify', \&on_configModify, undef],
	['start3', \&on_start3, undef]
);

my $file_handle;
my $answerPm_file;
my %playerRegs;

my $plugin_name = 'AnswerChat';

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
	$answerPm_file = (defined $config{$plugin_name.'_file'})? $config{$plugin_name.'_file'} : "AnswerChat.txt";
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
	Commands::run("reload $answerPm_file")
}

sub on_PM {
	return 0 unless ($config{$plugin_name.'_Pm'});
	my ($Type, $Args) = @_;
	my $player = $Args->{'MsgUser'};
	my $recievedMessage = $Args->{'Msg'};
	Main($recievedMessage,$player, "pm");
}

sub on_Pub {
	return 0 unless ($config{$plugin_name.'_Pub'});
	return 0 unless (!$field->isCity() && @{$playersList->getItems()} <= $config{$plugin_name.'_PubMax'});
	my ($Type, $Args) = @_;
	my $player = $Args->{'MsgUser'};
	my $recievedMessage = $Args->{'Msg'};
	Main($recievedMessage,$player, "c");
}

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
	my %playerInfo;
	if (exists($playerRegs{$player})) {
		%playerInfo = %{$playerRegs{$player}};
	}
	
	return if (exists($playerInfo{blocked}));
	
	##########
	#Answer Database
	##########
	my $finalMessage;
	$playerInfo{all}++;
	($finalMessage, %playerInfo) = AnswerDatabase($recievedMessage, %playerInfo);
	%{$playerRegs{$player}} = %playerInfo;
	
	##########
	#Get some errors
	##########
	my $correctMessage;
	if ($config{$plugin_name.'_Error'}) {
		($finalMessage, $correctMessage) = GetErrors($finalMessage);
	}
	
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
	
	
	if ($correctMessage) {
		my $correctTypeSpeed = writtingTime($finalMessage);
		my %correctHash = (
				timeout => $correctTypeSpeed+1,
				time => time,
				message => $correctMessage,
				type => $Type,
				user => $player
		);
		sendAnswer(\%correctHash);
	}
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

sub GetErrors {
	my $finalMessage = $_[0];
	my (@changes, $newCharacter, $errortype, $characterIndex, $changeNext, $correctMessage);
	my @characters = split(//,$finalMessage);
	foreach my $character (@characters) {
		if ($changeNext) {
			$changes[$characterIndex] = $changeNext;
			$changeNext = 0;
			next;
		}
		
		if (int(rand($config{$plugin_name.'_ErrorChance'})) == 0) {
			$errortype = int(rand(4));
				
			#Change a character
			if ($errortype == 0) {
				$newCharacter = changeCharacter($character);
				$changes[$characterIndex] = $newCharacter;
					
			#Exchange 2 character places
			} elsif ($errortype == 1) {
				$changes[$characterIndex] = $characters[$characterIndex+1];
				$changeNext = $character;
					
			#Delete a character
			} elsif ($errortype == 2) {
				$changes[$characterIndex] = "";
					
			#Put one more character
			} elsif ($errortype == 3) {
				$newCharacter = changeCharacter($character);
				$changes[$characterIndex] = $newCharacter;
				$changeNext = $character;
			}	
			
		} else {
			$changes[$characterIndex] = $character;
		}
	} continue {
		$characterIndex++;
	}	
	my @oldwords = split(/ /,$finalMessage);
	my $newMessage = join('',@changes);
	my @newwords = split(/ /,$newMessage);
	$finalMessage = $newMessage;
	my @diferentWords;
	foreach (0..@oldwords) {
		if ($oldwords[$_] ne $newwords[$_]) {
			push @diferentWords, $oldwords[$_];
		}
	}
	foreach (@diferentWords) { $_ = $_."*"; }
	$correctMessage = join(' ', @diferentWords);
	return ($finalMessage, $correctMessage);
}

sub changeCharacter {
	my $character = lc($_[0]);
	my $newCharacter;
	my %exchange = (
		q => ['a', 's', 'w'],
		w => ['q', 'a', 's', 'd', 'e'],
		e => ['w', 's', 'd', 'f', 'r'],
		r => ['e', 'd', 'f', 'g', 't'],
		t => ['r', 'f', 'g', 'h', 'y'],
		y => ['t', 'g', 'h', 'j', 'u'],
		u => ['y', 'h', 'j', 'k', 'i'],
		i => ['u', 'j', 'k', 'l', 'o'],
		o => ['i', 'k', 'l', 'p'],
		p => ['o', 'l'],
		a => ['q', 'w', 's', 'z'],
		s => ['a', 'q', 'w', 'e', 'd', 'x', 'z'],
		d => ['s', 'e', 'r', 'f', 'c', 'x'],
		f => ['d', 'r', 't', 'g', 'v', 'c'],
		g => ['f', 't', 'y', 'h', 'b', 'v'],
		h => ['y', 'u', 'j', 'n', 'b', 'g'],
		j => ['u', 'i', 'k', 'm', 'n', 'h'],
		k => ['j', 'i', 'o', 'l', 'm'],
		l => ['p', 'o', 'k'],
		z => ['a', 's', 'x'],
		x => ['z', 's', 'd', 'c'],
		c => ['x', 'd', 'f', 'v'],
		v => ['c', 'f', 'g', 'b'],
		b => ['v', 'g', 'h', 'n'],
		n => ['b', 'h', 'j', 'm'],
		m => ['n', 'j', 'k'],
		1 => ['4', '5', '2'],
		2 => ['1', '4', '5', '6', '3'],
		3 => ['2', '5', '6'],
		4 => ['1', '2', '5', '8', '7'],
		5 => ['4', '7', '8', '9', '6', '3', '2', '1'],
		6 => ['3', '2', '5', '8', '9'],
		7 => ['4', '5', '8'],
		8 => ['7', '4', '5', '6', '9'],
		9 => ['8', '5', '6'],
		0 => ['9', '1', '2', '3']
	);
	if (exists($exchange{$character})) {
		return $exchange{$character}[rand @{$exchange{$character}}];
	} else {
		return $character;
	}
}

1;