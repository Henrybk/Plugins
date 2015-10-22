sub CheckRecieved {
	my ($recievedMessage, %playerInfo) = @_;
	my %hash;
	$hash{1} = {
					name => 'introduction',
					pattern => qr/(hi|hello|hey)/i
	};
	$hash{2} = {
					name => 'goodbyes',
					pattern => qr/(bye|sya|adios)/i
	};
	$hash{3} = {
					name => 'thanks',
					pattern => qr/(thanks|thx|god bless you)/i
	};
	$playerInfo{all}++;
	foreach my $iteration (sort keys %hash) {
		next unless ($recievedMessage =~ $hash{$iteration}{pattern});
		$playerInfo{$hash{$iteration}{name}}++;
		$playerInfo{lastrecived} = $hash{$iteration}{name};
		return (%playerInfo);
	}
	$playerInfo{unknown}++;
	$playerInfo{lastrecived} = 'unknown';
	return (%playerInfo);
}

sub AnswerDatabase {
	my %playerInfo = %{$_[0]};
	my %answers;
	$answers{introduction} = {
					1 => {
							condition => (($playerInfo{goodbyes} > 0)? 1 : 0),
							answers => [
											"Why are you introducing yourself you you has already said goodbye?",
											"I thought the conversation was over",
											"When you said bye i thought it was for real"
										]
					},
					2 => {
							condition => (($playerInfo{introduction} == 1)? 1 : 0),
							answers => [
											"Hi",
											"Hey man",
											"How you doing",
											"Cool",
											"Hello"
										]
					},
					3 => {
							condition => (($playerInfo{introduction} == 2)? 1 : 0),
							answers => [
											"I think we have already met",
											"Hi again",
											"we have already been introduced",
											"hello again"
										]
					}
	};
	$answers{goodbyes} = {
					1 => {
							condition => (($playerInfo{thanks} > 0)? 1 : 0),
							answers => [
											"Good I was able to help, goodbye",
											"Good i helped",
											"Call whenever you need",
										]
					},
					2 => {
							condition => (($playerInfo{goodbyes} == 1)? 1 : 0),
							answers => [
											"Bye",
											"Bye Bye",
											"See ya",
											"So long",
											"Adios"
										]
					},
					3 => {
							condition => (($playerInfo{goodbyes} == 2)? 1 : 0),
							answers => [
											"Bye Again",
											"Bye Bye Bye",
											"Hasta again"
										]
					}
	};
	$answers{thanks} = {
					1 => {
							condition => (($playerInfo{thanks} == 1)? 1 : 0),
							answers => [
											"You're welcome",
											"My pleasure",
											"No worries"
										]
					},
					2 => {
							condition => (($playerInfo{thanks} == 2)? 1 : 0),
							answers => [
											"Good to help again",
											"You're welcome again",
											"No worries at all"
										]
					}
	};
	$answers{unknown} = {
					1 => {
							condition => (($playerInfo{unknown} == 1)? 1 : 0),
							answers => [
											"WHAT DID YOU SAY TO MY FACE BITCH ASS?",
											"I'M GONNA WHOP YO ASS BITCH"
										]
					},
					2 => {
							condition => (($playerInfo{unknown} == 2)? 1 : 0),
							answers => [
											"YOU HERE AGAIN IN MA YARD BOY?",
											"AAAMAAA WHOOOOP THEEEM ASSESSS"
										]
					}
	};
	foreach my $iteration (sort keys %{$answers{$playerInfo{lastrecived}}}) {
		next unless ($answers{$playerInfo{lastrecived}}{$iteration}{condition} == 1);
		return ($answers{$playerInfo{lastrecived}}{$iteration}{answers}[rand @{$answers{$playerInfo{lastrecived}}{$iteration}{answers}}]);
	}
	return 'Nope';
}