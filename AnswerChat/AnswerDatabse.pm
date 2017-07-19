package AnswerDatabse;

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

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(@template %params AnswerDatabase);

our @template = ('Use', 'all', 'stress', 'stressed', 'time', 'lastrecived', 'yes', 'no', 'bot', 'despedida', 'perguntapessoa', 'dinheiro', 'vcter', 'confirmation', 'pedido', 'atributos', 'agradecimento', 'crupoguild', 'ofensa', 'perguntaboa', 'perguntaondeup', 'perguntacomofaz', 'level', 'skill', 'cumprimento', 'emoticon', 'unkown', 'Blocked');
our %params = map { $_ => 1 } @template;

sub AnswerDatabase {
	my ($recievedMessage, %playerInfo) = @_;
	my @answersArray;
	my $info;
	if ($recievedMessage =~ /(flw+|falo[uw]*|ate|xau|tchau|chau|bye|to indo|to ino|abra[cs]+o*)/i) {
		$info = "despedida";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("flw ae","vlw, flw","flw mano","abrass","flw ae","xau","bye","bye bye","abraco");
			$playerInfo{stress} += 1;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("acho q ja te dei tchau","flw [2]","tchau denovo","flw²","ate²","abraco²","bye bye [2]","bye bye²","falow²");
			$playerInfo{stress} += 5;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("ta ne","as coisas q eu tenho q aguentar","ainda me presto",".-.","'-'","flw flw flw","bye bye [3]","bye bye³","falow³");
			$playerInfo{stress} += 20;
		} elsif ($playerInfo{$info} == 4) {
			$playerInfo{Block} += 1;
		}
	
	
	} elsif ($recievedMessage =~ /(^(obrigad[ao]|valeu|valew|vlw|obg|obrig)|^(muit(o|u|[ií]s+imo)|mt|muit)\s+(obrigad[ao]|valeu|valew|vlw|obg|obrig))/i) {
		$info = "agradecimento";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		@answersArray = ("denada","de nada","^^","deboa","nem se preocupa","as ordens",":D",":)","xD","fica zen");



	} elsif ($recievedMessage =~ /([^a-z]*(tu|t|vc|voc[ee]|se)\s+[ee]\s+)|([^a-z]+[ee]\s+(tu|t|vc|voc[ee]|se)[^a-z]+)/i) {
		$info = "perguntapessoa";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("so eu n","Nao so eu n","n so n","Nao so eu, malz","Eu so novo no server, so eu n","Acho q n","Acho q tu se enganou","Nope","nao");
			$playerInfo{stress} += 3;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("Cara vc n me conhece","Cara eu so novo aqui, n so eu","Tambem n sou eu","tb n sou eu","sqn","Nem conheco","Acho q tu se enganou denovo","Nope","nao");
			$playerInfo{stress} += 15;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("tu n canca?","Acho q tu ganha vai arranjando algo pra fazer","tu n me conhece mesmo","ERO","Ninguem acerto","Sqn denovo");
			$playerInfo{stress} += 25;
		} elsif ($playerInfo{$info} == 4) {
			$playerInfo{Block} += 1;
		}


	} elsif ($recievedMessage =~ /(aspd|(atk|ataque|atq|atak).*(speed|sped|spiid)|(velocidade|vel|velo).*(atk|ataque|atq|atak))|(critical|cr[íi]tico|crit|cri)|(atributos|stats|atributs|build)|((qnt|quanto|cuanto|qanto|qunto)).*(((str|for[cc]a|streng(ht|th)|for)|(vit|vitality|viti|vitalidade)|(agi|agilidade|agility|agiliti)|(dex|dez|des|dextre[zs]+a)|(int|intelig[ee]ncia|inti)|(luc|luk|sort[ei]?)).*)/i) {
		$info = "atributos";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		my $str = $char->{str};
		my $agi = $char->{agi};
		my $vit = $char->{vit};
		my $int = $char->{int};
		my $dex = $char->{dex};
		my $luk = $char->{luk};
		my $crit = $char->{critical};
		my $aspd = $char->{attack_speed};
		my $stat;
		if ($recievedMessage =~ /(str|for[cc]a|streng(ht|th)|for)/i) {
			$stat = $str;
		}
		if ($recievedMessage =~ /(agi|agilidade|agility|agiliti)/i) {
			$stat = $agi;
		}
		if ($recievedMessage =~ /(vit|vitality|viti|vitalidade)/i) {
			$stat = $vit;
		}
		if ($recievedMessage =~ /(int|intelig[ee]ncia|inti)/i) {
			$stat = $int;
		}
		if ($recievedMessage =~ /(dex|dez|des|dextre[zs]+a)/i) {
			$stat = $dex;
		}
		if ($recievedMessage =~ /(luc|luk|sort[ei]?)/i) {
			$stat = $luk;
		}
		if ($recievedMessage =~ /(critical|cr[íi]tico|crit|cri)/i) {
			$stat = $crit;
		}
		if ($recievedMessage =~ /(aspd|(atk|ataque|atq|atak).*(speed|sped|spied)|(velocidade|vel|velo).*(atk|ataque|atq|atak))/i) {
			$stat = $aspd;
		}
		if ($playerInfo{$info} == 1) {
			@answersArray = ("to com $stat","tenho $stat","to com uns $stat","uns $stat","coloquei $stat","$stat por enquanto");
			$playerInfo{stress} += 4;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("$stat ...","$stat","esse eu tenho $stat","Disso $stat");
			$playerInfo{stress} += 6;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("Ja n deu?","Cara quero voltar a upar","cara vai ler um guia q tu ganha mais","Acho q ja deu ne?");
			$playerInfo{stress} += 20;
		} elsif ($playerInfo{$info} == 4) {
			$playerInfo{Block} += 1;
		}



	} elsif ($recievedMessage =~ /((mi|me|mim)\s+(da|dar|consegu[ei])|(te[mr]|como)\s+(faz|da|dar|peg(ar|a|assa|assar))|(faz|da|dar|peg(ar|a|assa|assar))\s+.*(zen+[iy]+|grana|di[mn]di[mn]|pila+s*|dinheir[uo]|money))|(t[ee][rm]\s+zen+[iy]+)/i) {
		$info = "dinheiro";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("Tenho n cara, malz","N tenho n fera","tenho naum","Tenho n pra mim","malz, tenho nao","N tenho cara, desculpa");
			$playerInfo{stress} += 10;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("ja falei q eu n tenho cara","Ta complicado em","Tu n se canca?","ja falei q eu n tenho nada");
			$playerInfo{stress} += 25;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("rapa, assim tu me estressa","chega disso","na prox te block","prox eu te ignoro");
			$playerInfo{stress} += 50;
		} elsif ($playerInfo{$info} == 4) {
			$playerInfo{Block} += 1;
		}



	} elsif ($recievedMessage =~ /((tu|t|vc|voc[ee]|se)\s+(tem|ten|ter)\s*\??)/i) {
		$info = "vcter";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("Tenho n cara, malz","N tenho n fera","tenho naum","Nem tenho","malz, tenho nao","N tenho cara","N tenho amigo");
			$playerInfo{stress} += 5;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("ja falei q eu n tenho nada amigo","Ta complicado em?","Tu n se canca nao?","ja falei q eu n tenho quase nada cara");
			$playerInfo{stress} += 20;
		} elsif ($playerInfo{$info} == 3) {
			$playerInfo{Block} += 1;
		}



	} elsif ($recievedMessage =~ /(s[ee]rio|verdad[ie]|certe[sz]a|jura).*\?*/i) {
		$info = "confirmation";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		@answersArray = ("Aham","sim.","yep","e mesmo","sem duvida","uhum");


	} elsif ($recievedMessage =~ /(^(b[uo]+t+|b[uo]+t+(er|i|eator|e))$)|(\s+(b[uo]+t+|b[uo]+t+(er|i|eator|e))$)|(((tu|t|vc|voc[ee]|se|seu)\s+[ee]?h?\s*(b[uo]+t+|b[uo]+t+(er|i|eator|e))\s*\?*)$)|(macr[ou])/i) {
		$info = "bot";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("lol... nao ","nem vei","nao so","-.-' =P parece?","nem viaja","hu3hu3brbr","aham, claro","claro claro","yep, so memo");
			$playerInfo{stress} += 15;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("Tu gosta de me encher o saco ne?","de novo?","tu tem problem?","kkkkkk","hu3hu3 vc e bot brbr","de novo tu?","xispa rapa");
			$playerInfo{stress} += 20;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("proxima e block","prox te blocko","jaja te ignoro","ultima vez q do bola pra ti","depois dessa n te aguento mais");
			$playerInfo{stress} += 25;
		} elsif ($playerInfo{$info} == 4) {
			$playerInfo{Block} += 1;
		}



	} elsif ($recievedMessage =~ /(d[uu]vida|pergunta|m[ei]\s+respond[ei]|poderia|fazer.*favor|sab[ei]\s+m[ei]\s+(diz(e|er)|fal(a|ar)|explic(a|ar)|cont(a|ar))|(tu|t|vc|voc[ee]|se)\s+sab[ei])/i) {
		$info = "pedido";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		@answersArray = ("oi?","fala ae","pode repetir?","malz, nem vi pode repetir?","?","que?","pode explicar melhor?");



	} elsif ($recievedMessage =~ /((q|quer|invite|invita|da|passa|convida|chama)(gr(ou|u)upo*|cl[aa]a*|guilda*)|gr(ou|u)po*|cl[aa]|guilda*|(que*r*|q)\s+upa*r*|upa*\s+(comig[uo]|junto|together|conosc[uo]|com n[o|o]i?s|(co[nm])?\s*a\s*gent[ie]))/i) {
		$info = "crupoguild";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("nao vlw","n vlw","nao obrigado");
			$playerInfo{stress} += 5;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("vc denovo...","quero nao","affz");
			$playerInfo{stress} += 10;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("nem vem","aff que coisa");
			$playerInfo{stress} += 20;
		} elsif ($playerInfo{$info} == 4) {
			@answersArray = ("de novo!!","que droga para com isso");
			$playerInfo{stress} += 25;
		} elsif ($playerInfo{$info} == 5) {
			@answersArray = ("kct ja disse q n","nem vo fala nada");
			$playerInfo{stress} += 25;
		} elsif ($playerInfo{$info} == 6) {
			$playerInfo{Block} += 1;
		}



	} elsif ($recievedMessage =~ /(tom(a|ar)\s+n[uo]\s+c[uu]|cu[sz][aa]o|viadinho|cotoco|chapado|sem dedo|retardado|[ts]e\s+fod(a|e|er)|cal(a|ar)\s+a\s+b(o|ou)ca|vtnc|repor(t|tado|ted)|pnc|idiota|(i|in)gnorante|i(n|m)becil|imundo|i(n|m)seto|invertebrado|in[uu]til|gay+|f[ou]did[ou]|escrot[ou]|desgracad[ou]|drogad[uo]|dement[ie]|est[uu]pid[uo]|enfia\s+no|cacet[ie]|c[uu]\s+d(a|o|e)\s+rola|arrombad[oa]|arrega[cc]ado|an[ei]mal\s+de\s+teta|buceta|burro|foder|babaca|bund[aa]o|caralho|(filh[uo]|fi+)\s+d(e|a|uma)\s?([ee]gua|puta|gorda|cadela|cachorra)?|gord[ao]|jumento|lix([ao]|os[ao])|lepros[ao]|lazarent[ao]|lezad[ao]|nazista|facista|fdp|palhaco|otari[ao]|piroca|porra|prostituta|puta|bost(a|ao|inha)|quenga|retartad[ao]|tapad[ao]|travesti|troglodita|tr(o|ou)xa|vaca|vadia|viado|verme|vagabundo)/i) {
		$info = "ofensa";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("Pra que usar palavrao cara","que vocabulario ein","eu n venho jogar pra ser essas coisas","pra que ser mal educado?","pra que isso?","uq eu te fiz pra falar comigo assim?");
			$playerInfo{stress} += 15;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("acho q ja deu de falar comigo assim ne?","chega disso","cara se continuar falando assim vo te ignorar","cara, cuida uq tu fala");
			$playerInfo{stress} += 20;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("na prox vo te mutar","proxima eu te bloqueio","proxima ja era","proxima nem leio mais");
			$playerInfo{stress} += 30;
		} elsif ($playerInfo{$info} == 4) {
			$playerInfo{Block} += 1;
		}



	} elsif ($recievedMessage =~ /((tudo|td)\s+(deboa|bom|bem|massa|legal|lgl|blz)\?+|como\s+(tu|vc|voc[ee])\s+(vai|t[aa]|anda|est[aa])\?+|como\s+(vai|t[aa]|anda|est[aa])\s+(tu|vc|voc[ee])\?+)/i) {
		$info = "perguntaboa";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		@answersArray = ("tudo bem","tudo massa","blz","tudo em cima","bacana","^^","td bem","tudo lgl");
		$playerInfo{stress} += 3;



	} elsif ($recievedMessage =~ /((ond[ei]*|com[ou])*\s?(tu|t|vc|voc[ee]|se)?\s+up(o|ou|a|ar)?)/i) {
		OndUpQuestion:
		$info = "perguntaondeup";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		my $maxlevel = 0;
		my $rando = int(rand(2));
		my @placearray;
		if ($recievedMessage =~ /(^(1[36][0-9])$|^(17[0-4])$)|(1[36][0-9][^0-9]+|17[0-4][^0-9]+)|(\s+1[36][0-9]$|\s+17[0-4]$)|((([nl]vl?|level|n[íi]vel)1[36][0-9]\?*)$|(([nl]vl?|level|n[íi]vel)17[0-4]\?*)$)|(1[2-7]x)|((at[ee])\s*(o|um|uns|a)?\s*([nl]vl?|level|n[íi]vel)?\s+175)/i) {
			@answersArray = ("Apartir dai e praticamente so mvp amigo","do 130 ao 175 e so mvp","dai pra frente e mvp","mvp","mata mvp");
			$maxlevel = 1
		}
		if ($recievedMessage =~ /175/i) {
			@answersArray = ("...","lgl em","massa fera","lgl upar com aura ne","zoa mais");
			$maxlevel = 1
		}
		if ($recievedMessage =~ /(^(1[0-5])$|^([1-9])$)|(1[0-5][^0-9]+|[1-9][^0-9]+)|(\s+1[0-5]$|\s+[1-9]$)|((([nl]vl?|level|n[íi]vel)1[0-5]\?*)$|(([nl]vl?|level|n[íi]vel)[1-9]\?*)$)|((1x))/i) {
			if ($rando == 1) {
				@placearray = ("pay_fild03","pay_fild04","anthell","Esgotos","gef_fild07","moc_fild07","moc_fild12");
			} else {
				@placearray = ("pupa","picky","ovo de andre","ovo de besouro","fabre","chon chon");
			}
		}
		if ($recievedMessage =~ /(^(1[6-9])$|^(2[1-9])$)|(1[6-9][^0-9]+|2[1-9][^0-9]+)|(\s+1[6-9]$|\s+2[1-9]$)|((([nl]vl?|level|n[íi]vel)1[6-9]\?*)$|(([nl]vl?|level|n[íi]vel)2[1-9]\?*)$)|(2x)/i) {
			if ($rando == 1) {
				@placearray = ("pay_fild08","esgotos","formigueiro","esgotos lvl 2");
			} else {
				@placearray = ("esporo","besouros","andre","familiar");
			}
		}
		if ($recievedMessage =~ /(^([43][0-9])$)|([43][0-9][^0-9]+)|(\s+[43][0-9]$)|((([nl]vl?|level|n[íi]vel)[43][0-9]\?*)$)|((3x)|(4x))/i) {
			if ($rando == 1) {
				@placearray = ("moc_fild03","esgotos lvl 3","vila dos orcs","orc dun","gef_fild10");
			} else {
				@placearray = ("lobo","talo de verme","orc","orc zumbi");
			}
		}
		if ($recievedMessage =~ /(^([56][0-9])$|^(7[0-2])$)|([56][0-9][^0-9]+|7[0-2][^0-9]+)|(\s+[56][0-9]$|\s+7[0-2]]$)|((([nl]vl?|level|n[íi]vel)[56][0-9]\?*)$|(([nl]vl?|level|n[íi]vel)7[0-2]\?*)$)|((5x)|(6x))/i) {
			if ($rando == 1) {
				@placearray = ("moc_fild17","moc_fild16","prt_fild09","orc dun 2");
			} else {
				@placearray = ("hode","arenoso","magnolia","zenorc");
			}
		}
		if ($recievedMessage =~ /(^(7[3-9])$|^(8[0-5])$)|(7[3-9][^0-9]+|8[0-5][^0-9]+)|(\s+7[3-9]$|\s+8[0-5]$)|((([nl]vl?|level|n[íi]vel)7[3-9]\?*)$|(([nl]vl?|level|n[íi]vel)8[0-5]\?*)$)|((7x)|(8x))/i) {
			if ($rando == 1) {
				@placearray = ("gef_fild06","gef_fild08","yuno_fild04");
			} else {
				@placearray = ("petite","arenoso","harpia");
			}
		}
		if ($recievedMessage =~ /(^(8[6-9])$|^(9[0-4])$)|(8[6-9][^0-9]+|9[0-4][^0-9]+)|(\s+8[6-9]$|\s+9[0-4]$)|((([nl]vl?|level|n[íi]vel)8[6-9]\?*)$|(([nl]vl?|level|n[íi]vel)9[0-4]\?*)$)|(9x)/i) {
			if ($rando == 1) {
				@placearray = ("ve_fild07","caverna de gelo","ice dun lvl 1","ra_fild12");
			} else {
				@placearray = ("stapo","siroma","roween");
			}
		}
		if ($recievedMessage =~ /(^(9[5-9])$|^(10[0-9])$)|(9[5-9][^0-9]+|10[0-9][^0-9]+)|(\s+9[5-9]$|\s+10[0-9]$)|((([nl]vl?|level|n[íi]vel)9[5-9]\?*)$|(([nl]vl?|level|n[íi]vel)10[0-9]\?*)$)|(10x)/i) {
			if ($rando == 1) {
				@placearray = ("ve_fild03","magmarings","ice dun lvl 1","ra_fild12");
			} else {
				@placearray = ("magmaring","siroma","roween");
			}
		}
		if ($recievedMessage =~ /(^(11[0-9])$|^(12[0-9])$)|(11[0-9][^0-9]+|12[0-9][^0-9]+)|(\s+11[0-9]$|\s+12[0-9]$)|((([nl]vl?|level|n[íi]vel)11[0-9]\?*)$|(([nl]vl?|level|n[íi]vel)12[0-9]\?*)$)|(11x)/i) {
			if ($rando == 1) {
				@placearray = ("Santuario de rachel lvl 1","juperos lvl 1","ice dun lvl 2");
			} else {
				@placearray = ("isila e vanberk","venatu","yeti");
			}
		}
		if ($maxlevel == 0) {
			my $sizeplacearray = @placearray;
			my $takeplace = $placearray[rand $sizeplacearray];
			if ($rando == 1) {
				@answersArray = ("vai $takeplace","vai la em $takeplace","em $takeplace","upa em $takeplace","vai pra $takeplace","$takeplace");
			} else {
				@answersArray = ("vai matar $takeplace","mata $takeplace","upa em $takeplace", "$takeplace");
			}
		}
		if (@placearray == 0) {
			@answersArray = ("em qual lvl?","em q lvl?","qnd?","q lvl?","qual lvl?","em q lvls?");
		}
		$playerInfo{stress} += 5;

	} elsif ($recievedMessage =~ /(ond[ei]*\s+vend[ei]*.\?*|quest|com[ou]+\s+(fa[sz]|se fa[sz]|fazer?|faser?|pegar?|dropa?r?)|ond[ei]*\s+drop(a|aste|ou|o|u)?)/i) {
		$info = "perguntacomofaz";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		@answersArray = ('sei nao cara', 'sei n malz', 'sei n', 'n sei n', 'n faço ideia cara');
		$playerInfo{stress} += 7;



	} elsif ($recievedMessage =~ /([nl]vl?|level|n[íi]vel)/i) {
		my $skilllevel = 0;
		for my $handle (@skillsID) {
			my $skillhandle = new Skill(handle => $handle);
			my $namehandle = $skillhandle->getName();
			my @skillarray = split /\s/,$namehandle;
			foreach (@skillarray) {
				if ($_ =~ /^(da|de|com|do|flechas)$/i) {
					next;
				}
				if ($recievedMessage =~ /$_/i) {
					$skilllevel = $char->getSkillLevel($skillhandle);
				}
			}
		}

		if ($skilllevel != 0) {
			$info = "skill";
			unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
			$playerInfo{lastrecived} = $info;
			if ($playerInfo{$info} == 1) {
				@answersArray = ("la lvl $skilllevel","acho q ta $skilllevel","coloquei $skilllevel","ta uns $skilllevel");
				$playerInfo{stress} += 5;
			} elsif ($playerInfo{$info} == 2) {
				@answersArray = ("... $skilllevel","$skilllevel...","e $skilllevel cara","ta $skilllevel");
				$playerInfo{stress} += 10;
			} elsif ($playerInfo{$info} == 3) {
				@answersArray = ("acho q ta bom de querer saber das minhas skills ne?","cara, vai ler um database","acho q tu devia ir ler um guia","tu devia me encher menos o saco");
				$playerInfo{stress} += 25;
			} elsif ($playerInfo{$info} == 4) {
				$playerInfo{Block} += 1;
			}
		} else {
			$info = "level";
			unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
			$playerInfo{lastrecived} = $info;
			my $lvl = $char->{lv};
			my $joblvl = $char->{lv_job};
			if ($playerInfo{$info} == 1) {
				@answersArray = ("so $lvl-$joblvl","$lvl-$joblvl","meu level e $lvl","$lvl");
				$playerInfo{stress} += 5;
			} elsif ($playerInfo{$info} == 2) {
				@answersArray = ("acho q eu ja disse q so $lvl-$joblvl","$lvl-$joblvl ja falei","ja disse q e $lvl","$lvl");
				$playerInfo{stress} += 15;
			} elsif ($playerInfo{$info} == 3) {
				@answersArray = ("ta complicado em?","ja disse q e $lvl-$joblvl pqp","qnts vezes ja disse q e $lvl","$lvl");
				$playerInfo{stress} += 25;
			} elsif ($playerInfo{$info} == 4) {
				$playerInfo{Block} += 1;
			}
		}


	} elsif ($recievedMessage =~ /(^(oi+e*|ea[ew]|oe+|ow|uow|iow|ol[aa])\s*.*)|(^(oi+e*|ea[ew]|oe+|ow|uow|iow|(td|tudo)\s+(bem|deboa|lgl|massa|bom|blz|beleza)|blz|cara|mano|parceiro|amig(o|ao)|parca|colega)$)|(ta[ie]*\s*(e|ae|a[ií]|[ií]|aew|ew|aiw|iw)*\s*(cara|mano|parceiro|amig(o|ao)|parca|colega)?)/i) {
		$info = "cumprimento";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("eae","ioi","eaw","oi","oie","falae","iei","hola","ola","ola","oe","ioio","oioi","ieie");
			$playerInfo{stress} += 2;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("err, oi","hmn, oi","... oi","ta, oi","oi...","fala.","uq tu quer?","ok..","fala logo","oi, denovo","ola, outra vez","oi[2]","ola[2]");
			$playerInfo{stress} += 10;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("uq tu quer cara?","fala logo","ta me enchendo ja","diz logo","ta me estressando","ta me cansando","vo perder a paciencia");
			$playerInfo{stress} += 25;
		} elsif ($playerInfo{$info} == 4) {
			$playerInfo{Block} += 1;
		}




	} elsif ($recievedMessage =~ /(\^(\.|_|o|0)?\^|:(D|\(|\)|3|p|\\|\/|c)|(D|\(|\)|3|p|\\|\/|c):|('|")(\.|_|o|0)('|")|q(\.|_|o|0)q|t(\.|_|o|0)t|p(\.|_|o|0)p|~\\[a-z]+)/i) {
		$info = "emoticon";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		@answersArray = (".-.","-.-","xD","=p","^^","e.e","q.q");
		$playerInfo{stress} += 5;



	} else {
		$info = "unkown";
		unless (exists($playerInfo{$info})) { $playerInfo{$info} = 1; } else { $playerInfo{$info}++; }
		$playerInfo{lastrecived} = $info;
		if ($playerInfo{$info} == 1) {
			@answersArray = ("oi?","lol?","wtf","nem entendi uq tu quiz dizer","tendi nao","me confundi lgl","fala direito cara","fala certo","fala q eu possa entender");
			$playerInfo{stress} += 5;
		} elsif ($playerInfo{$info} == 2) {
			@answersArray = ("ta complicado mesmo","??","what?","fala certo q eu respondo","nao converso com analfabetos bem","complicado","malz cara, nao consegui entender","tendi denovo nao","uq tu quis dizer?");
			$playerInfo{stress} += 10;
		} elsif ($playerInfo{$info} == 3) {
			@answersArray = ("to sem paciencia pra ti cara","cansei de ti","chega disso","ja eras, cansei","nem vo tentar entender mais","complicado demais pra mim","nao e pra mim mesmo","nao vai rolar mesmo");
			$playerInfo{stress} += 15;
		} elsif ($playerInfo{$info} == 4) {
			$playerInfo{Block} += 1;
		}
	}
	
	##########
	#Stress Counter
	##########
	if ($playerInfo{stress} < 100 && $playerInfo{stress} >= 50 && $playerInfo{stressed} != 1) {
		@answersArray = ("Se ta me estressando cara","Tu ta me estressando","To ficando estressado","ficando estressado*","ta me incomodando","Tu ta me incomodando cara");
		$playerInfo{stressed} = 1;
	}

	if ($playerInfo{all} == 7) {
		@answersArray = ("Se n acha n q essa conversa ta demorando muito?","essa conversa ta demorada","isso vai demorar muito?","ta demorando esse papo","papo longo esse em?","ta chato esse papo ja");
	}

	if ($playerInfo{Block} == 1 || $playerInfo{stress} >= 100 || $playerInfo{all} == 12) {
		@answersArray = ("Parabens, ta block","blocked","ignorado","ignored","te block","block bjs");
		$playerInfo{blocked} = 1;
	}

	##########
	#Select answer
	##########
	my $finalMessage = $answersArray[rand @answersArray];
	return ($finalMessage, %playerInfo);
}

1;
