#########################################################################
# autoTalkDatabase v1.0
# Made by Henrybk from openkorebrasil
# 
# Config to be put into npc_resps.txt
# 
# autoTalkDatabase {
# 	message => /msg regex/;
# 	name => /name regex/; (optional)
# 	answer => 'talk steps';
# 	actor_type => 'npc | monster | portal'; (optional)
# 	only_in_map => 'mpa name'; (optional)
# }
#
#########################################################################

package autoTalkDatabase; 
  
use strict; 
use Globals; 
use Plugins; 
use Utils; 
use Log qw(debug message warning error); 
use Misc;

use File::Spec;

use constant {
	PLUGIN_NAME => 'autoTalkDatabase',
	PLUGIN_DESC => 'database of answers for all auto talk npcs',
	DATABASE_FILE => 'npc_resps.txt',
};

our $folder = $Plugins::current_plugin_folder;

my $database;
my $current_task;
my $current_msg;
my $clear_to_answer;
  
Plugins::register(PLUGIN_NAME, PLUGIN_DESC, \&onUnload); 

my $hooks = Plugins::addHooks(
	['start3',                     \&on_start3        ],
	['npc_autotalk',               \&on_npc_autotalk  ],
	['npc_talk',                   \&on_npc_talk      ],
	['AI_pre',                     \&on_AI_pre        ],
);

my $clear_hooks = Plugins::addHooks(
	['packet/npc_talk_continue',  \&set_clear         ],
	['npc_talk_done',             \&set_clear         ],
	['npc_talk_responses',        \&set_clear         ],
	['packet/npc_talk_number',    \&set_clear         ],
	['packet/npc_talk_text',      \&set_clear         ],
);

sub onUnload { 
	Plugins::delHooks($hooks); 
	Plugins::delHooks($clear_hooks); 
}

sub on_start3 {
    $database = loadFile(File::Spec->catdir($folder,DATABASE_FILE));
	if (!defined $database) {
		error "[".PLUGIN_NAME."] Could not load database due to a file loading problem.\n";
	}
}

sub loadFile {
    my $file = shift;

	unless (open FILE, "<:utf8", $file) {
		error "[".PLUGIN_NAME."] Could not load file $file.\n";
		return;
	}
	my @lines = <FILE>;
	close(FILE);
	chomp @lines;

	my @database;
	
	my $in_block = 0;
	my $line_counter = 1;
	my %current_block;
	foreach my $line (@lines) {
		$line =~ s/^\x{FEFF}//;
		$line =~ s/(.*)[\s\t]+#.*$/$1/;
		$line =~ s/^\s*#.*$//;
		$line =~ s/^\s*//;
		$line =~ s/\s*[\r\n]?$//g;
		$line =~ s/  +/ /g;
		next unless ($line);

		if ($in_block) {
			if ($line =~ /^}$/) {
				if (!exists $current_block{message}) {
					error "[".PLUGIN_NAME."] No message specified for block ending in line ".$line_counter." (Ignoring block)\n";
					
				} elsif (!exists $current_block{answer}) {
					error "[".PLUGIN_NAME."] No answer specified for block ending in line ".$line_counter." (Ignoring block)\n";
					
				} else {
					my $last = $#database;
					foreach my $key (keys %current_block) {
						$database[($last+1)]{$key} = $current_block{$key};
					}
				}
				undef %current_block;
				$in_block = 0;
				
			} elsif ($line =~ /^(answer|actor_type|only_in_map)\s*=>\s*'(.+)'\s*;$/i) {
				my $type = $1;
				my $answer = $2;
				
				if (defined $answer) {
					$current_block{$type} = $answer;
				} else {
					$in_block = 0;
					undef %current_block;
					error "[".PLUGIN_NAME."] Unkown sintax at '".$type."' at line ".$line_counter." (Ignoring block)\n";
				}
				
			} elsif ($line =~ /^(message|name)\s*=>\s*\/(.*?)\/(i?)\s*;$/i) {
				my $type = $1;
				my $original_regex = $2;
				my $case_insensitive = !!$3;
				
				$original_regex = quotemeta($original_regex);

				if (defined $original_regex) {
					$current_block{$type} = $original_regex;
					$current_block{$type."_case_insensitive"} = $case_insensitive;
					
				} else {
					$in_block = 0;
					undef %current_block;
					error "[".PLUGIN_NAME."] Unkown sintax at '".$type."' at line ".$line_counter." (Ignoring block)\n";
				}
				
			} else {
				$in_block = 0;
				undef %current_block;
				error "[".PLUGIN_NAME."] Unkown sintax at line ".$line_counter." (Ignoring block)\n";
			}
			
		} elsif ($line =~ /^autoTalkDatabase\s*{$/i) {
			undef %current_block;
			$in_block = 1;
		}
		
	} continue {
		$line_counter++;
	}
	
	return \@database;
}

sub set_clear {
	return unless (defined $current_task);
	$clear_to_answer = 1;
}

sub on_npc_autotalk {
	my (undef, $args) = @_;
	$current_task = $args->{task};
	$clear_to_answer = 0;
}

sub on_npc_talk {
	my (undef, $args) = @_;
	$current_msg = $args->{msg};
	$clear_to_answer = 0;
}

sub on_AI_pre {
	return unless (defined $current_task);
	if (!AI::is("NPC")) {
		#Talk ended
		undef $current_task;
		undef $current_msg;
		undef $clear_to_answer;
		return;
	}
	
	return unless ($clear_to_answer);
	return unless ($current_task->{stage} == Task::TalkNPC::TALKING_TO_NPC);
	
	my $answer = get_answer();
	if (defined $answer) {
		warning "[".PLUGIN_NAME."] Found answer for current autoTalk in database, it is '".$answer."'.\n";
		$current_task->addSteps($answer);
	} else {
		warning "[".PLUGIN_NAME."] Could not find answer for current autoTalk in database.\n";
	}
	undef $current_task;
	undef $current_msg;
	undef $clear_to_answer;
}

sub get_answer {
	my $target = Actor::get($talk{ID});
	my $type = (UNIVERSAL::isa($target, 'Actor::NPC')) ? ('npc') : ((UNIVERSAL::isa($target, 'Actor::Portal')) ? ('portal') : ((UNIVERSAL::isa($target, 'Actor::Monster')) ? ('monster') : ('none')));
	my $name = $target->name();
	my $message = $current_msg;
	foreach my $answer_block (@{$database}) {
		if (exists $answer_block->{actor_type}) {
			next unless ($answer_block->{actor_type} eq $type);
		}
		if (exists $answer_block->{only_in_map}) {
			next unless ($answer_block->{only_in_map} eq $field->baseName);
		}
		if (exists $answer_block->{name}) {
			if ($answer_block->{name_case_insensitive}) {
				next unless ($name =~ /$answer_block->{name}/i);
			} else {
				next unless ($name =~ /$answer_block->{name}/);
			}
		}
		if (exists $answer_block->{message}) {
			if ($answer_block->{message_case_insensitive}) {
				next unless ($message =~ /$answer_block->{message}/i);
			} else {
				next unless ($message =~ /$answer_block->{message}/);
			}
		}
		return $answer_block->{answer};
	}
}

return 1;
