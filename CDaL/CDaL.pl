##############################
# =======================
# CDaL v3.0
# =======================
# This plugin is licensed under the GNU GPL
# Created by Henrybk from openkorebrasil
#
# What it does: It is a plugin that is able to create, delete and change characters during play time.
#
# Config keys (put in config.txt):
#	CDaL_characterToLogin
#	CDaL_characterToDelete
#	CDaL_characterToCreate
#	CDaL_characterToCreateInfo
#	CDaL_account_email
#	CDaL_maxTries
#	CDaL_activateOnStart
#
##############################
package CDaL;

use strict;
use Plugins;
use Globals;
use Log qw(message warning error debug);
use AI;
use Misc;
use Network;
use Network::Send;
use Utils;

use constant {
	NOT_SET => 0,
	START => 1,
	DELETE => 2,
	CREATE => 3,
	LOGIN => 4,
	RETURN_LOGIN => 1,
	RETURN_CREATEDELETE => 2
};

Plugins::register('CDaL', 'Creates, deletes and logins characters', \&on_unload);
my $hooks = Plugins::addHooks(
	['charSelectScreen', \&charSelectScreenHook],
	['packet_pre/character_creation_successful', \&creation_successfulHook],
	['packet_pre/character_creation_failed', \&creation_failedHook],
	['packet_pre/character_deletion_successful', \&deletion_successfulHook],
	['packet_pre/character_deletion_failed', \&deletion_failedHook],
	['packet_pre/received_character_ID_and_Map', \&login_successfulHook]
);

my $chooks = Commands::register(
	['activateCDaL', 'activates Plugin', \&pluginCommand]
);

my $status = NOT_SET;
my $tries = 0;

my $plugin_name = 'CDaL';

sub on_unload {
	Plugins::delHooks($hooks);
	Commands::unregister($chooks);
}

sub deletion_successfulHook {
	if ($status == DELETE) {
		message "[$plugin_name] Deletion successful\n", "system";
		if (defined $config{$plugin_name.'_characterToCreate'}) {
			$status = CREATE;
			message "[$plugin_name] Plugin set for creation\n", "system";
		} elsif (defined $config{$plugin_name.'_characterToLogin'}) {
			$status = LOGIN;
			message "[$plugin_name] Plugin set for login\n", "system";
		} else {
			$status = NOT_SET;
			message "[$plugin_name] End of configuration\n", "system";
		}
		$tries = 0;
	}
}

sub deletion_failedHook {
	if ($status == DELETE) {
		$tries++;
		if ($tries == $config{$plugin_name.'_maxTries'}) {
			message "[$plugin_name] Deletion failed, deactivating plugin\n", "system";
			$status = NOT_SET;
		} else {
			message "[$plugin_name] Deletion failed, trying again\n", "system";
		}
	}
}

sub creation_successfulHook {
	if ($status == CREATE) {
		message "[$plugin_name] Creation successful\n", "system";
		if (defined $config{$plugin_name.'_characterToLogin'}) {
			$status = LOGIN;
			message "[$plugin_name] Plugin set for login\n", "system";
		} else {
			$status = NOT_SET;
			message "[$plugin_name] End of configuration\n", "system";
		}
		$tries = 0;
	}
}

sub creation_failedHook {
	if ($status == CREATE) {
		$tries++;
		if ($tries == $config{$plugin_name.'_maxTries'}) {
			message "[$plugin_name] Creation failed, deactivating plugin\n", "system";
			$status = NOT_SET;
		} else {
			message "[$plugin_name] Creation failed, trying again\n", "system";
		}
	}
}

sub login_successfulHook {
	if ($status == LOGIN) {
		message "[$plugin_name] Login successful\n", "system";
		message "[$plugin_name] End of configuration\n", "system";
		$status = NOT_SET;
		$tries = 0;
	}
}

sub charSelectScreenHook {
    my ($self, $args) = @_;
	message "[$plugin_name] we are at the character selection screen\n", "system";
	if ($status == START || ($config{$plugin_name.'_activateOnStart'} && $status == NOT_SET)) {
		if ($config{$plugin_name.'_activateOnStart'}) {
			configModify($plugin_name.'_activateOnStart', 0);
			message "[$plugin_name] Plugin set to activate on Startup\n", "system";
			return unless (checkConfig());
			message "[$plugin_name] Configuration accepted\n", "system";
			print_actions();
		}
		if (defined $config{$plugin_name.'_characterToDelete'}) {
			message "[$plugin_name] Plugin set for deletion\n", "system";
			$status = DELETE;
		} elsif (defined $config{$plugin_name.'_characterToCreate'}) {
			message "[$plugin_name] Plugin set for creation\n", "system";
			$status = CREATE;
		} else {
			message "[$plugin_name] Plugin set for login\n", "system";
			$status = LOGIN;
		}
	}
	
	return if ($status == NOT_SET);
	
	message "[$plugin_name] Plugin is active\n", "system";
	
    if ($status == DELETE) {
        message "[$plugin_name] Deleting ".$config{$plugin_name.'_characterToDelete'}.": ".$chars[$config{$plugin_name.'_characterToDelete'}]{name}.", ".$config{$plugin_name.'_account_email'}."\n", "system";
        $messageSender->sendBanCheck($charID);
        $messageSender->sendCharDelete($chars[$config{$plugin_name.'_characterToDelete'}]{charID}, $config{$plugin_name.'_account_email'});
        $timeout{'charlogin'}{'time'} = time;
        $args->{return} = RETURN_CREATEDELETE;
        
    } elsif ($status == CREATE) {
		my $newCharName = generateName();
        message "[$plugin_name] Creating ".$config{$plugin_name.'_characterToCreate'}.": $newCharName\n", "system";

		my @args = split(/\s+/, parseArgs($config{$plugin_name.'_characterToCreateInfo'}));
		
		unless (createCharacter($config{$plugin_name.'_characterToCreate'}, $newCharName, @args)) {
			message "[$plugin_name] Invalid char creation config setting, please fix CDaL_characterToCreateInfo in config.txt\n", "system";
			$status = NOT_SET;
			return;
		}
		
        $timeout{'charlogin'}{'time'} = time;
        $args->{return} = RETURN_CREATEDELETE;
        
    } elsif ($status == LOGIN) {
		$tries++;
		if ($tries == $config{$plugin_name.'_maxTries'}) {
			message "[$plugin_name] Too many login tries, deactivating plugin\n", "system";
			$status = NOT_SET;
		}
		message "[$plugin_name] Login ".$config{$plugin_name.'_characterToLogin'}.": ".$chars[$config{$plugin_name.'_characterToLogin'}]{name}."\n", "system";
        $messageSender->sendCharLogin($config{$plugin_name.'_characterToLogin'});
        $timeout{'charlogin'}{'time'} = time;
        $args->{return} = RETURN_LOGIN;
        configModify("char", $config{$plugin_name.'_characterToLogin'});
    }
}

sub print_actions {
	message "[$plugin_name] Actions to be performed: .\n", "system";
	my $counter = 1;
	if (defined $config{$plugin_name.'_characterToDelete'}) {
		message $counter++." - Character in slot ".$config{$plugin_name.'_characterToDelete'}." will be deleted.\n", "system";
	}
	if (defined $config{$plugin_name.'_characterToCreate'}) {
		message  $counter++." - Character will be created in slot ".$config{$plugin_name.'_characterToCreate'}.".\n", "system";
	}
	if (defined $config{$plugin_name.'_characterToLogin'}) {
		message  $counter++." - Character in slot ".$config{$plugin_name.'_characterToLogin'}." will used to log in game.\n", "system";
	}
}

sub pluginCommand {
	if (checkConfig()) {
		message "[$plugin_name] Configuration accepted.\n", "system";
		print_actions();
		$status = START;
		$messageSender->sendQuitToCharSelect();
	}
}

sub checkConfig {
	if (!defined $config{$plugin_name.'_characterToDelete'} && !defined $config{$plugin_name.'_characterToCreate'} && !defined $config{$plugin_name.'_characterToLogin'}) {
		error "[$plugin_name] Config isn't set for creation, deletion or login.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToDelete'} && !defined $config{$plugin_name.'_account_email'}) {
		error "[$plugin_name] Set to delete character but not email set.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToDelete'} && !defined $chars[$config{$plugin_name.'_characterToDelete'}]) {
		error "[$plugin_name] Set to delete character but there is no character in the provided slot.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToCreate'} && !defined $config{$plugin_name.'_characterToCreateInfo'}) {
		error "[$plugin_name] Set to create character but not set it's info (stats, hair and hair color, sex, race, etc).\n";
		
	} elsif (defined $config{$plugin_name.'_characterToCreate'} && $config{$plugin_name.'_characterToCreate'} !~ /\d+/) {
		error "[$plugin_name] Set to create character but value is invalid ($config{$plugin_name.'_characterToCreate'}), must be a number.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToLogin'} && $config{$plugin_name.'_characterToLogin'} !~ /\d+/) {
		error "[$plugin_name] Set to login on character but value is invalid ($config{$plugin_name.'_characterToLogin'}), must be a number.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToDelete'} && $config{$plugin_name.'_characterToDelete'} !~ /\d+/) {
		error "[$plugin_name] Set to delete character but value is invalid ($config{$plugin_name.'_characterToDelete'}), must be a number.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToCreate'} && defined $chars[$config{$plugin_name.'_characterToCreate'}] && !defined $config{$plugin_name.'_characterToDelete'}) {
		error "[$plugin_name] Set to create a character in full slot, and no character will be deleted.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToCreate'} && defined $chars[$config{$plugin_name.'_characterToCreate'}] && defined $config{$plugin_name.'_characterToDelete'} && $config{$plugin_name.'_characterToCreate'} != $config{$plugin_name.'_characterToDelete'}) {
		error "[$plugin_name] Set to create a character in full slot, and the character that will be deleted isn't in the same slot.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToLogin'} && !$chars[$config{$plugin_name.'_characterToLogin'}] && !defined $config{$plugin_name.'_characterToCreate'}) {
		error "[$plugin_name] Set to login on empty slot and no character will be created.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToLogin'} && !$chars[$config{$plugin_name.'_characterToLogin'}] && defined $config{$plugin_name.'_characterToCreate'} && $config{$plugin_name.'_characterToCreate'} != $config{$plugin_name.'_characterToLogin'}) {
		error "[$plugin_name] Set to login on empty slot and the created character will on another slot.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToLogin'} && $chars[$config{$plugin_name.'_characterToLogin'}] && defined $config{$plugin_name.'_characterToDelete'} && $config{$plugin_name.'_characterToDelete'} == $config{$plugin_name.'_characterToLogin'} && !defined $config{$plugin_name.'_characterToCreate'}) {
		error "[$plugin_name] Set to login on a full slot but the same slot will be deleted, and no character will be created.\n";
		
	} elsif (defined $config{$plugin_name.'_characterToLogin'} && $chars[$config{$plugin_name.'_characterToLogin'}] && defined $config{$plugin_name.'_characterToDelete'} && $config{$plugin_name.'_characterToDelete'} == $config{$plugin_name.'_characterToLogin'} && defined $config{$plugin_name.'_characterToCreate'} && $config{$plugin_name.'_characterToCreate'} != $config{$plugin_name.'_characterToLogin'}) {
		error "[$plugin_name] Set to login on a full slot but the same slot will be deleted, and the created character will be on another slot.\n";
		
	} else {
		return 1;
	}
	return 0;
}

my @biblicNames = ("Aarat", "Aaron", "Abba", "Abaddon", "Abagtha", "Abana", "Abarim", "Abda", "Abdeel", "Abdi", "Abdiel", "Abdon", "Abednego", "Abel", "Abez", "Abi", "Abiah", "Abiasaph", "Abiathar", "Abib", "Abidah", "Abidan", "Abiel", "Abiezer", "Abigail", "Abihail", "Abihu", "Abihud", "Abijah", "Abijam", "Abilene", "Abimael", "Abimelech", "Abinadab", "Abinoam", "Abiram", "Abishag", "Abishai", "Abishalom", "Abishua", "Abishur", "Abital", "Abitub", "Abiud", "Abner", "Abram", "Abraham", "Absalom", "Accad", "Accho", "Aceldama", "Achab", "Achaia", "Achaicus", "Achan", "Achaz", "Achbor", "Achim", "Achish", "Achmetha", "Achor", "Achsah", "Achshaph", "Achzib", "Adadah", "Adah", "Adaiah", "Adaliah", "Adam", "Adamah", "Adami", "Adar", "Adbeel", "Addi", "Addin", "Addon", "Adiel", "Adin", "Adithaim", "Adlai", "Admah", "Admatha", "Adna", "Adnah", "Adonijah", "Adonikam", "Adoniram", "Adoraim", "Adoram", "Adrammelech", "Adramyttium", "Adriel", "Adullam", "Adummim", "Aeneas", "Aenon", "Agabus", "Agag", "Agar", "Agee", "Agrippa", "Agur", "Ahab", "Aharah", "Aharhel", "Ahasbai", "Ahasuerus", "Ahava", "Ahaz", "Ahaziah", "Ahi", "Ahiah", "Ahiam", "Ahian", "Ahiezer", "Ahihud", "Ahijah", "Ahikam", "Ahilud", "Ahimaaz", "Ahiman", "Ahimelech", "Ahimoth", "Ahinadab", "Ahinoam", "Ahio", "Ahira", "Ahiram", "Ahisamach", "Ahishahur", "Ahishar", "Ahithophel", "Ahitub", "Ahlab", "Ahlai", "Ahoah", "Aholah", "Aholiab", "Aholibah", "Aholibamah", "Ahumai", "Ahuzam", "Ahuzzah", "Ai", "Aiah", "Aiath", "Ain", "Ajalon", "Akkub", "Akrabbim", "Alammelech", "Alemeth", "Alian", "Alleluia", "Allon", "Almodad", "Almon", "Alpheus", "Alush", "Alvah", "Amad", "Amalek", "Aman", "Amana", "Amariah", "Amasa", "Amasai", "Amashai", "Ami", "Amaziah", "Aminadab", "Amittai", "Ammah", "Ammi", "Ammiel", "Ammihud", "Amminadab", "Ammishaddai", "Ammizabad", "Ammon", "Amnon", "Amok", "Amon", "Amorite", "Amos", "Amoz", "Amplias", "Amram", "Amraphel", "Amzi", "Anab", "Anah", "Anaharath", "Anaiah", "Anak", "Anamim", "Anammelech", "Anani", "Ananias", "Anathema", "Anathoth", "Andrew", "Andronicus", "Anem", "Aner", "Aniam", "Anim", "Anna", "Annas", "Antichrist", "Antioch", "Antipas", "8", "Antipatris", "Antothijah", "Anub", "Apelles", "Apharsathchites", "Aphek", "Aphekah", "Aphik", "Aphiah", "Apocalypse", "Apocrypha", "Apollonia", "Apollonius", "Apollos", "Apollyon", "Appaim", "Apphia", "Aquila", "Ar", "Ara", "Arab", "Arabia", "Arad", "Arah", "Aram", "Aran", "Ararat", "Araunah", "Arba", "Archelaus", "Archippus", "Arcturus", "Ard", "Ardon", "Areli", "Areopagus", "Aretas", "Argob", "Ariel", "Arimathea", "Arioch", "Aristarchus", "Aristobulus", "Armageddon", "Arnon", "Aroer", "Árpád", "Arphaxad", "Artaxerxes", "Artemas", "Arumah", "Asa", "Asahel", "Asaiah", "Asaph", "Asareel", "Asenath", "Ashan", "Ashbel", "Ashdod", "Asher", "Asherah", "Ashima", "Ashkenaz", "Ashnah", "Ashriel", "Ashtaroth", "Ashur", "Asia", "Asiel", "Askelon", "Asnapper", "Asriel", "Assir", "Asshurim", "Assos", "Assur", "Assyria", "Asuppim", "Asyncritus", "Atad", "Atarah", "Ataroth", "Ater", "Athach", "Athaiah", "Athaliah", "Athlai", "Attai", "Attalia", "Augustus", "Avim", "Avith", "Azaliah", "Azaniah", "Azariah", "Azaz", "Azazel", "Azaziah", "Azekah", "Azgad", "Azmaveth", "Azmon", "Azor", "Azotus", "Azrael", "Azrikam", "Azubah", "Azzan", "Azzur", "Baal", "Baalah", "Baalath", "Baale", "Baali", "Baalim", "Baalis", "Baana", "Baanah", "Baara", "Baaseiah", "Baasha", "Babel", "Babylon", "Baca", "Bahurim", "Bajith", "Bakbakkar", "Bakbuk", "Bakbukiah", "Balaam", "Baladan", "Balak", "Bamah", "Barabbas", "Barachel", "Barachias", "Barak", "Barjesus", "Barjona", "Barnabas", "Barsabas", "Bartholomew", "Bartimeus", "Baruch", "Barzillai", "Bashan", "Bashemath", "Bathsheba", "Bathsuha", "Bealiah", "Bealoth", "Bebai", "Becher", "Bechorath", "Bedad", "Bedaiah", "Bedan", "Beeliada", "Beelzebub", "Beer", "Beera", "Beerelim", "Beeri", "Beeroth", "Beersheba", "Behemoth", "Bekah", "Belah", "Belial", "Belshazzar", "Belteshazzar", "Ben", "Benaiah", "Beneberak", "Benhadad", "Benhail", "Benhanan", "Benjamin", "Benimi", "Beno", "Benoni", "Benzoheth", "Beon", "Beor", "Bera", "Berachah", "Berachiah", "Beraiah", "Berea", "Bered", "Beri", "Beriah", "Berith", "Bernice", "Berothai", "Berothath", "Besai", "Besodeiah", "Besor", "Betah", "Beten", "Bethabara", "Bethanath", "Bethany", "Betharabah", "Bethel", "Bethemek", "Bether", "Bethesda", "Bethsaida", "Bethshan", "Bethuel", "Betonim", "Beulah", "Bezai", "Bezaleel", "Bezek", "Bezer", "Bichri", "Bidkar", "Bigthan", "Bigvai", "Bildad", "Bileam", "Bilgah", "Bilhah", "Bilshan", "Binea", "Binnui", "Birsha", "Bishlam", "Bithiah", "Bithron", "Bithynia", "Bizjothjah", "Blastus", "Boanerges", "Boaz", "Bocheru", "Bochim", "Bohan", "Boskath", "Boson", "Bozez", "Bozrah", "Bukki", "Bukkiah", "Bul", "Bunah", "Bunni", "Buz", "Buzi", "Cabbon", "Cabul", "Caesar", "Caiphas", "Cain", "Cainan", "Calah", "Calcol", "Caleb", "Calneh", "Calno", "Calvary", "Camon", "Cana", "Canaan", "Candace", "Capernaum", "Caphtor", "Cappadocia", "Carcas", "Charchemish", "Careah", "Carmel", "Carmi", "Carpus", "Carshena", "Casiphia", "Casluhim", "Cedron", "Cenchrea", "Cephas", "Cesar", "Chalcol", "Chaldea", "Charran", "Chebar", "Chedorlaomer", "Chelal", "Chelub", "Chelluh", "Chelubai", "Chemarims", "Chemosh", "Chenaanah", "Chenani", "Chenaniah", "Chephirah", "Cheran", "Cherith", "Chesed", "Chesil", "Chesulloth", "Chidon", "Chiliab", "Chilion", "Chilmad", "Chimham", "Chios", "Chisleu", "Chislon", "Chittem", "Chloe", "Chorazin", "Chozeba", "Christ", "Christian", "Chun", "Chuza", "Cilicia", "Cis", "Clauda", "Claudia", "Clement", "Cleophas", "Cnidus", "Colhozeh", "Colosse", "Coniah", "Coos", "Corinth", "Cornelius", "Cosam", "Coz", "Cozbi", "Crescens", "Crete", "Crispus", "Cush", "Cuth", "Cyprus", "Cyrene", "Cyrenius", "Cyrus", "Dabareh", "Dabbasheth", "Daberath", "Dagon", "Dalaiah", "Dalmanutha", "Dalmatia", "Dalphon", "Damaris", "Damascus", "Dan", "Daniel", "Dannah", "Darah", "Darda", "Darius", "Darkon", "Dathan", "David", "Debir", "Deborah", "Decapolis", "Dedan", "Dedanim", "Dekar", "Delaiah", "Delilah", "Demas", "Demetrius", "Derbe", "Deuel", "Deuteronomy", "Diana", "Diblaim", "Diblath", "Dibon", "Dibri", "Dibzahab", "Didymus", "Diklah", "Dilean", "Dimon", "Dimonah", "Dinah", "Dinhabah", "Dionysius", "Diotrephes", "Dishan", "Dishon", "Dodai", "Dodavah", "Dodo", "Doeg", "Dophkah", "Dor", "Dorcas", "Dothan", "Drusilla", "Dumali", "Dura", "Eagle", "Earing", "Earnest", "East", "Ebal", "Ebed", "Eber", "Ebiasaph", "Ebronah", "Ecclesiastes", "Ecclesiasticus", "Ed", "Eden", "Eder", "Edom", "Edrei", "Eglah", "Eglaim", "Eglon", "Egypt", "Felix", "Festus", "Fortunatus", "Gaal", "Gaash", "Gabbai", "Gabbatha", "Gabriel", "Gad", "Gadarenes", "Gaddi", "Gaddiel", "Gaius", "Galal", "Galatia", "Galeed", "Galilee", "Gallim", "Gallio", "Gamaliel", "Gammadims", "Gamul", "Gareb", "Garmites", "Gatam", "Gath", "Gaza", "Gazabar", "Gazer", "Gazez", "Gazzam", "Geba", "Gebal", "Geber", "Gebim", "Gedaliah", "Geder", "Gederothaim", "Gehazi", "Geliloth", "Gemalli", "Gemariah", "Gennesaret", "Genesis", "Genubath", "Gera", "Gerar", "Gergesenes", "Gerizim", "Gershom", "Gershon", "Geshur", "Gether", "Gethsemane", "Geuel", "Gezer", "Giah", "Gibbar", "Gibbethon", "Gibeah", "Gibeon", "Giddel", "Gideon", "Gideoni", "Gihon", "Gilalai", "Gilboa", "Gilead", "Gilgal", "Giloh", "Gimzo", "Ginath", "Girgashite", "Gispa", "Gittaim", "Gittites", "Goath", "Gob", "Gog", "Golan", "Golgotha", "Goliath", "Gomer", "Gomorrah", "Goshen", "Gozan", "Gudgodah", "Guni", "Gur", "Haahashtari", "Habaiah", "Habakkuk", "Habazinaiah", "Habor", "Hachaliah", "Hachilah", "Hachmoni", "Hadad", "Hadadezer", "Hadadrimmon", "Hadar", "Hadarezer", "Hadashah", "Hadassah", "Hadattah", "Hades", "Hadlai", "Hadoram", "Hadrach", "Hagab", "Hagar", "Haggai", "Haggeri", "Haggiah", "Haggith", "Hai", "Hakkatan", "Hakkoz", "Hakupha", "Halah", "Halak", "Halhul", "Hali", "Hallelujah", "Halloesh", "Ham", "Haman", "Hamath", "Hammedatha", "Hammelech", "Hammoleketh", "Hammon", "Hamonah", "Hamor", "Hamoth", "Hamul", "Hamutal", "Hanameel", "Hanan", "Hananeel", "Hanani", "Hananiah", "Hanes", "Haniel", "Hannah", "Hannathon", "Hanniel", "Hanoch", "Hanun", "Hapharaim", "Hara", "Haradah", "Haran", "Harran", "Harbonah", "Hareph", "Harhas", "Harhaiah", "Harhur", "Harim", "Harnepher", "Harod", "Harosheth", "Harsha", "Harum", "Harumaph", "Haruphite", "Haruz", "Hasadiah", "Hashabiah", "Hashabnah", "Hashem", "Hashub", "Hashubah", "Hashum", "Hashupha", "Hasrah", "Hatach", "Hathath", "Hatita", "Hattil", "Hattipha", "Hattush", "Hauran", "Havilah", "Hazael", "Hazaiah", "Hazarenan", "Hazargaddah", "Hazarmaveth", "Hazelelponi", "Hazeroth", "Hazo", "Hazor", "Heber", "Hebrews", "Hebron", "Hegai", "Helam", "Helbah", "Heldai", "Helek", "Helem", "Heleph", "Helez", "Heli", "Helkai", "Helon", "Heman", "Hen", "Hena", "Henadad", "Henoch", "Hepher", "Hephzibah", "Heres", "Heresh", "Hermas", "Hermogenes", "Hermon", "Herod", "Herodion", "Heshbon", "Heshmon", "Heth", "Hethlon", "Hezekiah", "Hezer", "Hezrai", "Hezron", "Hiddai", "Hiel", "Hierapolis", "Higgaion", "Hilen", "Hilkiah", "Hillel", "Hinnom", "Hirah", "Hiram", "Hittite", "Hivites", "Hizkijah", "Hobab", "Hobah", "Hod", "Hodaiah", "Hodaviah", "Hodesh", "Hoglah", "Hoham", "Holon", "Homam", "Hophin", "Hophra", "Hor", "Horeb", "Horem", "Hori", "Horims", "Hormah", "Horonaim", "Horonites", "Hosah", "Hosanna", "Hosea", "Hoshaiah", "Hoshama", "Hothir", "Hukkok", "Hul", "Huldah", "Hupham", "Huppim", "Hur", "Huram", "Huri", "Hushah", "Hushai", "Hushathite", "Huz", "Huzoth", "Huzzab", "Hymeneus", "Ibhar", "Ibleam", "Ibneiah", "Ibnijah", "Ibri", "Ibsam", "Ibzan", "Ichabod", "Iconium", "Idalah", "Idbash", "Iddo", "Idumea", "Igal", "Igeal", "Igdaliah", "Iim", "Ikkesh", "Ilai", "Illyricum", "Imlah", "Imla", "Immanuel", "Immer", "Imna", "Imnah", "Imrah", "Imri", "India", "Iphedeiah", "Ir", "Ira", "Irad", "Iram", "Iri", "Irijah", "Irpeel", "Iru", "Isaac", "Isaiah", "Iscah", "Iscariot", "Ishbah", "Ishbak", "Ishbosheth", "Ishi", "Ishiah", "Ishma", "Ishmael", "Ishmaiah", "Ishmerai", "Ishod", "Ishtob", "Ishua", "Ishuah", "Ishui", "Ishvah", "Ishvi", "Ishmachiah", "Ismaiah", "Ispah", "Israel", "Issachar", "Isshiah", "Isshijah", "Isui", "Ithai", "Italy", "Ithamar", "Ithiel", "Ithmah", "Ithra", "Ithran", "Ithream", "Ittai", "Iturea", "Ivah", "Izehar", "Izhar", "Izrahiah", "Izri", "Izziah", "Jaakan", "Jaakobah", "Jaala", "Jaalam", "Jaanai", "Jaasau", "Jaasiel", "Jaasu", "Jaazaniah", "Jaazah", "Jaaziah", "Jaaziel", "Jabal", "Jabbok", "Jabesh", "Jabez", "Jabin", "Jabneel", "Jachan", "Jachin", "Jacob", "Jada", "Jadau", "Jadon", "Jaddua", "Jael", "Jagur", "Jah", "Jahaleel", "Jahath", "Jahaz", "Jahaziah", "Jahaziel", "Jahdai", "Jahdiel", "Jahdo", "Jahleel", "Jahmai", "Jahzeel", "Jahzerah", "Jair", "Jairus", "Jakan", "Jakeh", "Jakim", "Jalon", "Jambres", "James", "Jamin", "Jamlech", "Janna", "Janoah", "Janum", "Japhet", "Japheth", "Japhia", "Japhlet", "Japho", "Jarah", "Jareb", "Jared", "Jaresiah", "Jarib", "Jarmuth", "Jarvah", "Jashem", "Jasher", "Jashobeam", "Jashub", "Jasiel", "Jason", "Jathniel", "Jattir", "Javan", "Jazeel", "Jazer", "Jaziz", "Jearim", "Jeaterai", "Jeberechiah", "Jebus", "Jebusi", "Jecamiah", "Jecoliah", "Jeconiah", "Jedaiah", "Jedeiah", "Jediael", "Jedidah", "Jedidiah", "Jediel", "Jeduthun", "Jeezer", "Jehaleleel", "Jehaziel", "Jehdeiah", "Jeheiel", "Jehezekel", "Jehiah", "Jehiskiah", "Jehoadah", "Jehoaddan", "Jehoahaz", "Jehoash", "Jehohanan", "Jehoiachin", "Jehoiada", "Jehoiakim", "Jehoiarib", "Jehonadab", "Jehonathan", "Jehoram", "Jehoshaphat", "Jehosheba", "Jehoshua", "Jehovah", "Jehozabad", "Jehozadak", "Jehu", "Jehubbah", "Jehucal", "Jehud", "Jehudijah", "Jehush", "Jekabzeel", "Jekamean", "Jekamiah", "Jekuthiel", "Jemima", "Jemuel", "Jephthah", "Jephunneh", "Jerah", "Jerahmeel", "Jered", "Jeremai", "Jeremiah", "Jeremoth", "Jeriah", "Jerebai", "Jericho", "Jeriel", "Jerijah", "Jerimoth", "Jerioth", "Jeroboam", "Jeroham", "Jerubbaal", "Jerubbesheth", "Jeruel", "Jerusalem", "Jerusha", "Jesaiah", "Jeshebeab", "Jesher", "Jeshimon", "Jeshishai", "Jeshohaia", "Jeshua", "Jesiah", "Jesimiel", "Jesse", "Jesui", "Jesus", "Jether", "Jetheth", "Jethlah", "Jethro", "Jetur", "Jeuel", "Jeush", "Jew", "Jezaniah", "Jezebel", "Jezer", "Jeziah", "Jezoar", "Jezrahiah", "Jezreel", "Jibsam", "Jidlaph", "Jimnah", "Jiphtah", "Jiphthael", "Joab", "Joachim", "Joah", "Joahaz", "Joanna", "Joash", "Joatham", "Job", "Jobab", "Jochebed", "Joed", "Joel", "Joelah", "Joezer", "Jogbehah", "Jogli", "Johanan", "John", "Joiarib", "Jokdeam", "Jokim", "Jokmeam", "Jokneam", "Jokshan", "Joktan", "Jonadab", "Jonah", "Jonan", "Jonathan", "Joppa", "Jorah", "Joram", "Jordan", "Jorim", "Josabad", "Josaphat", "Jose", "Joseph", "Joses", "Joshah", "Joshaviah", "Joshbekesha", "Joshua", "Josiah", "Josibiah", "Josiphiah", "Jotham", "Jothath", "Jozabad", "Jozachar", "Jubal", "Jucal", "Judah", "Judas", "Judaea", "Judith", "Julia", "Julius", "Junia", "Jushabhesed", "Justus", "Juttah", "Kabzeel", "Kadesh", "Kadmiel", "Kadmonites", "Kallai", "Kamon", "Kanah", "Kareah", "Karkaa", "Karkor", "Karnaim", "Kartah", "Kedar", "Kedemah", "Kedemoth", "Kehelahath", "Keiiah", "Keilah", "Kelaiah", "Kelitah", "Kemuel", "Kenah", "Kenan", "Kenaz", "Kenites", "Kenizzites", "Kerioth", "Keros", "Keturah", "Kezia", "Keziz", "Kibzaim", "Kidron", "Kinah", "Kir", "Kirioth", "Kirjath", "Kirjathaim", "Kish", "Kishi", "Kishion", "Kishon", "Kithlish", "Kitron", "Kittim", "Koa", "Kohath", "Kolaiah", "Korah", "Kushaiah", "Laadah", "Laadan", "Laban", "Labana", "Lachish", "Lael", "Lahad", "Lahairoi", "Lahmam", "Lahmi", "Laish", "Lakum", "Lamech", "Laodicea", "Lapidoth", "Lasea", "Lasha", "Lashah", "Lazarus", "Leah", "Lebanon", "Lebaoth", "Lebbeus", "Lebonah", "Lecah", "Lehabim", "Lekah", "Lemuel", "Leor", "Leshem", "Letushim", "Leummim", "Levi", "Libnah", "Libni", "Likhi", "Lilith", "Libya", "Linus", "Lior", "Lmri", "Lod", "Lois", "Lot", "Lubin", "Lucas", "Lucifer", "Lud", "Luhith", "Luke", "Luz", "Lycaonia", "Lydda", "Lysanias", "Lysias", "Lysimachus", "Lystra", "Maachah", "Maachathi", "Maadai", "Maadiah", "Maai", "Maarath", "Maaseiah", "Maasiai", "Maath", "Maaz", "Macedonia", "Machbenah", "Machi", "Machir", "Machnadebai", "Machpelah", "Madai", "Madian", "Madmannah", "Madon", "Magbish", "Magdala", "Magdalene", "Magdiel", "Magog", "Magpiash", "Mahalah", "Mahaleleel", "Mahali", "Mahanaim", "Mahanehdan", "Mahanem", "Maharai", "Mahath", "Mahavites", "Mahaz", "Mahazioth", "Mahlah", "Makas", "Makheloth", "Makkedah", "Malachi", "Malcham", "Malchijah", "Malchiel", "Malchus", "Maleleel", "Mallothi", "Malluch", "Mammon", "Mamre", "Manaen", "Manahethites", "Manasseh", "Manoah", "Maon", "Mara", "Maralah", "Maranatha", "Mareshah", "Maroth", "Marsena", "Martha", "Mary", "Mash", "Mashal", "Masrekah", "Massa", "Massah", "Matred", "Matri", "Mattan", "Mattaniah", "Mattatha", "Mattathias", "Matthan", "Matthanias", "Matthal", "Matthew", "Mazzaroth", "Meah", "Mearah", "Mebunnai", "Mecherath", "Medad", "Medan", "Medeba", "Media", "Megiddo", "Megiddon", "Mehetabel", "Mehida", "Mehir", "Mehujael", "Mehuman", "Mejarkon", "Mekonah", "Melatiah", "Melchi", "Melchiah", "Melchizedek", "Melea", "Melech", "Melita", "Mellicu", "Melzar", "Memphis", "Memucan", "Menahem", "Menan", "Mene", "Meonenim", "Mephaath", "Mephibosheth", "Merab", "Meraioth", "Merari", "Mered", "Meremoth", "Meres", "Meribah", "Meribaal", "Merodach", "Merom", "Meronothite", "Meroz", "Mesha", "Meshach", "Meshech", "Meshelemiah", "Meshezaheel", "Meshillamith", "Mesobaite", "Mesopotamia", "Messiah", "Methusael", "Methuselah", "Meunim", "Mezahab", "Miamin", "Mibhar", "Mibsam", "Mibzar", "Micah", "Micaiah", "Micha", "Michael", "Michaiah", "Michal", "Michmash", "Michmethah", "Michri", "Michtam", "Middin", "Midian", "Migdol", "Migron", "Mijamin", "Mikloth", "Minneiah", "Milalai", "Milcah", "Milcom", "Miletum", "Millo", "Miniamin", "Minni", "Minnith", "Miriam", "Mishael", "Mishal", "Misham", "Misheal", "Mishma", "Mishmannah", "Mishraites", "Mispar", "Misti", "Mithcah", "Mithnite", "Mithredath", "Mitylene", "Mizar", "Mizpah", "Mizraim", "Mizzah", "Mnason", "Moab", "Moladah", "Molech", "Molid", "Mordecai", "Moreh", "Moriah", "Moserah", "Moses", "Mozah", "Muppim", "Mushi", "Myra", "Mysia", "Naam", "Naaman", "Naamah", "Naarah", "Naaran", "Naashon", "Naasson", "Nabal", "Naboth", "Nachon", "Nachor", "Nadab", "Nagge", "Nahaliel", "Nahallal", "Naham", "Naharai", "Nahash", "Nahath", "Nahbi", "Nahor", "Nahshon", "Nahum", "Nain", "Naioth", "Naomi", "Naphish", "Naphtali", "Narcissus", "Nason", "Nathan", "Nathanael", "Naum", "Nazareth", "Nazarite", "Neah", "Neapolis", "Neariah", "Nebai", "Nebaioth", "Neballat", "Nebat", "Nebo", "Nebuchadrezzar", "Necho", "Nedabiah", "Neginoth", "Nehelamite", "Nehemiah", "Nehum", "Nehushta", "Nehushtan", "Neiel", "Nekoda", "Nemuel", "Nepheg", "Nephish", "Nephishesim", "Nephthalim", "Nephthoah", "Nephusim", "Ner", "Nereus", "Nergal", "Neri", "Neriah", "Nethaneel", "Nethaniah", "Nethinims", "Neziah", "Nezib", "Nibhaz", "Nibshan", "Nicanor", "Nicodemus", "Nicolas", "Nicolaitanes", "Nicopolis", "Niger", "Nimrah", "Nimrod", "Nimshi", "Nineveh", "Nisan", "Nisroch", "No", "Noadiah", "Noah", "Noah", "Nob", "Nobah", "Nod", "Nodab", "Noe", "Nogah", "Noha", "Non", "Noph", "Nophah", "Norah", "Nun", "Nymphas", "Obadiah", "Obal", "Obed", "Obil", "Oboth", "Ocran", "Oded", "Og", "Ohad", "Ohel", "Olympas", "Omar", "Omega", "Omri", "On", "Onan", "Onesimus", "Onesiphorus", "Ono", "Ophel", "Ophir", "Ophni", "Ophrah", "Oreb", "Oren", "Ornan", "Orpah", "Oshea", "Othni", "Othniel", "Ozem", "Ozias", "Ozni", "Paarai", "Padon", "Pagiel", "Pai", "Palal", "Palestina", "Pallu", "Palti", "Paltiel", "Pamphylia", "Paphos", "Parah", "Paran", "Parbar", "Parmashta", "Parmenas", "Parnach", "Parosh", "Parshandatha", "Paruah", "Pasach", "Pasdammin", "Paseah", "Pashur", "Patara", "Pathros", "Patmos", "Patrobas", "Pau", "Paul", "Paulus", "Pedahzur", "Pedaiah", "Pekah", "Pekahiah", "Pekod", "Pelaiah", "Pelaliah", "Pelatiah", "Peleg", "Pelethites", "Pelonite", "Peniel", "Peninnah", "Pentapolis", "Pentateuch", "Pentecost", "Penuel", "Peor", "Perazim", "Peresh", "Perez", "Perga", "Pergamos", "Perida", "Perizzites", "Persia", "Persis", "Peruda", "Peter", "Pethahiah", "Pethuel", "Peulthai", "Phalec", "Phallu", "Phanuel", "Pharaoh", "Pharez", "Pharisees", "Pharpar", "Phebe", "Phenice", "Phichol", "Philadelphia", "Philemon", "Philetus", "Philip", "Philippi", "Philistines", "Philologus", "Phinehas", "Phlegon", "Phrygia", "Phurah", "Phygellus", "Phylacteries", "Pilate", "Pinon", "Piram", "Pirathon", "Pisgah", "Pisidia", "Pison", "Pithom", "Pithon", "Pochereth", "Pontius", "Pontus", "Poratha", "Potiphar", "Potipherah", "Prisca", "Priscilla", "Prochorus", "Puah", "Publius", "Pudens", "Pul", "Punites", "Punon", "Pur", "Putiel", "Puteoli", "Quartus", "Quaternion", "Quicksands", "Quirinius", "Raamah", "Raamiah", "Rabbah", "Rabbi", "Rabbith", "Rabboni", "Rabmag", "Rabshakeh", "Raca", "Rachab", "Rachal", "Rachel", "Raddai", "Ragau", "Raguel", "Rahab", "Rahab", "Raham", "Rakem", "Rakkath", "Rakkon", "Ram", "Ramah", "Ramath", "Ramiah", "Ramoth", "Raphah", "Reaiah", "Reba", "Rebekah", "Rechab", "Reelaiah", "Regem", "Regemmelech", "Rehabiah", "Rehob", "Rehoboam", "Rehoboth", "Rehum", "Rei", "Reins", "Rekem", "Remaliah", "Remmon", "Remphan", "Rephael", "Rephaiah", "Rehpaim", "Rephidim", "Resen", "Reu", "Reuben", "Reuel", "Reumah", "Rezeph", "Rezin", "Rezon", "Rhegium", "Rhesa", "Rhoda", "Rhodoks", "Rhodes", "Ribai", "Riblah", "Rimmon", "Rinnah", "Riphath", "Rissah", "Rithmah", "Rizpah", "Rogelim", "Rohgah", "Roman", "Rome", "Rosh", "Reuben", "Rufus", "Ruhamah", "Rumah", "Ruth", "Sabaoth", "Sabeans", "Sabtah", "Sabtechah", "Sacar", "Sadducees", "Sadoc", "Salah", "Salamis", "Salathiel", "Salcah", "Salem", "Salim", "Sallai", "Salma", "Salmon", "Salome", "Samaria", "Samlah", "Samos", "Samothracia", "Samson", "Samuel", "Sanballat", "Sanhedrin", "Sansannah", "Saph", "Saphir", "Sapphira", "Sarah", "Sarai", "Sardis", "Sardites", "Sarepta", "Sargon", "Sarid", "Saron", "Sarsechim", "Saruch", "Satan", "Saul", "Sceva", "Seba", "Sebat", "Sebia", "Secacah", "Sechu", "Secundus", "Segub", "Seir", "Sela", "Selah", "Seled", "Seleucia", "Sem", "Semachiah", "Semaiah", "Semei", "Senaah", "Seneh", "Senir", "Sennacherib", "Seorim", "Sephar", "Sepharad", "Sepharvaim", "Serah", "Seraiah", "Seraphim", "Sered", "Sergius", "Serug", "Seth", "Sethur", "Shaalabbim", "Shaalbim", "Shaalbonite", "Schaaph", "Shaaraim", "Shaashgaz", "Shabbethai", "Shachia", "Shadrach", "Shage", "Shalem", "Shalim", "Shalisha", "Shallum", "Shalmai", "Shalman", "Shalmaneser", "Shamariah", "Shamayim", "Shamed", "Shamer", "Shamgar", "Shamhuth", "Shamir", "Shammah", "Shammai", "Shammoth", "Shammuah", "Shamsherai", "Shapham", "Shaphat", "Sharai", "Sharar", "Sharezer", "Sharon", "Shashai", "Shashak", "Shaul", "Shaveh", "Shealtiel", "Sheariah", "Sheba", "Shebam", "Shebaniah", "Shebarim", "Sheber", "Shebna", "Shebuel", "Shecaniah", "Shechem", "Shedeur", "Shehariah", "Shelah", "Shelemiah", "Sheleph", "Shelesh", "Shelomi", "Shelumiel", "Shem", "Shema", "Shemaiah", "Shemariah", "Shemeber", "Shemer", "Shemida", "Sheminith", "Shemiramoth", "Shemuel", "Shen", "Shenazar", "Shenir", "Shephatiah", "Shephi", "Shepho", "Shephuphan", "Sherah", "Sherebiah", "Sheshach", "Sheshai", "Sheshan", "Sheshbazzar", "Shethar", "Sheva", "Shibboleth", "Shibmah", "Shicron", "Shiggaion", "Shihon", "Shilhi", "Shillem", "Shiloah", "Shiloh", "Shilom", "Shilshah", "Shimeah", "Shimei", "Shimeon", "Shimma", "Shimon", "Shimrath", "Shimshai", "Shimri", "Shimrith", "Shinab", "Shinar", "Shiphi", "Shiphrah", "Shisha", "Shishak", "Shitrai", "Shittim", "Shiza", "Shoa", "Shobab", "Shobach", "Shobai", "Shobal", "Shobek", "Shochoh", "Shoham", "Shomer", "Shophach", "Shophan", "Shoshannim", "Shua", "Shuah", "Shual", "Shubael", "Shuham", "Shulamite", "Shunem", "Shuni", "Shuphim", "Shur", "Shushan", "Shuthelah", "Sia", "Sibbechai", "Sibmah", "Sichem", "Siddim", "Sidon", "Sigionoth", "Sihon", "Sihor", "Silas", "Silla", "Siloa", "Silvanus", "Simeon", "Simon", "Sin", "Sinai", "Sinim", "Sion", "Sippai", "Sinon", "Sisamai", "Sisera", "Sitnah", "Sivan", "Smyrna", "So", "Socoh", "Sodi", "Sodom", "Solomon", "Sopater", "Sophereth", "Sorek", "Sosthenes", "Sotai", "Spain", "Stachys", "Stephanas", "Stephen", "Suah", "Succoth", "Sud", "Sur", "Susanna", "Susi", "Sychar", "Syene", "Syntyche", "Syracuse", "Taanach", "Tabbath", "Tabbaoth", "Tabeal", "Tabelel", "Taberah", "Tabering", "Tabitha", "Tabor", "Tabrimon", "Tadmor", "Tahan", "Tahapenes", "Tahath", "Tahpenes", "Tahrea", "Talmai", "Tamah", "Tamar", "Tammuz", "Tanhumeth", "Taphath", "Tappuah", "Tarah", "Taralah", "Tarea", "Tarpelites", "Tarshish", "Tarsus", "Tartak", "Tartan", "Tatnai", "Tebah", "Tebaliah", "Tebeth", "Tehinnah", "Tekel", "Tekoa", "Telabib", "Telah", "Telassar", "Telem", "Telharsa", "Tema", "Teman", "Terah", "Teraphim", "Tertius", "Tertullus", "Tetrarch", "Thaddeus", "Thahash", "Thamah", "Thamar", "Tharah", "Thebez", "Thelasar", "Theophilus", "Thessalonica", "Theudas", "Thomas", "Thuhash", "Thummim", "Thyatira", "Tibbath", "Tiberias", "Tiberius", "Tibni", "Tidal", "Tikvah", "Tilon", "Timeus", "Timnah", "Timnath", "Timon", "Timotheus", "Tiphsah", "Tire", "Tirhakah", "Tiria", "Tirras", "Tirshatha", "Tirza", "Tirzah", "Tishbite", "Titus", "Toah", "Tob", "Tobiah", "Tochen", "Togarmah", "Tohu", "Toi", "Tola", "Tophet", "Topheth", "Trachonitis", "Troas", "Trophimus", "Tryphena", "Tryphon", "Tryphosa", "Tubal", "Tychicus", "Tyrannus", "Tyrus", "Ucal", "Uel", "Ulai", "Ulam", "Ulla", "Ummah", "Unni", "Uphaz", "Upharsin", "Ur", "Urbane", "Uri", "Uriah", "Uriel", "Urim", "Uthai", "Uz", "Uzai", "Uzal", "Uzzah", "Uzzi", "Uzziah", "Vajezatha", "Vaniah", "Vashni", "Vashti", "Vophsi", "Yakman", "Yakob", "Yehoyada", "Yahweh", "Yehezkel", "Yoav", "Yohanan", "Yonan", "Yosef", "Yuval", "Zaanaim", "Zaanannim", "Zaavan", "Zabad", "Zabbai", "Zabbud", "Zabdi", "Zabdiel", "Zaccai", "Zacchaeus", "Zaccur", "Zachariah", "Zacharias", "Zacher", "Zadok", "Zaham", "Zair", "Zalaph", "Zalmon", "Zalmonah", "Zalmunna", "Zamzummims", "Zanoah", "Zarah", "Zareathites", "Zared", "Zarephath", "Zaretan", "Zarhites", "Zartanah", "Zarthan", "Zatthu", "Zattu", "Zavan", "Zaza", "Zebadiah", "Zebah", "Zebaim", "Zebedee", "Zebina", "Zeboiim", "Zeboim", "Zebudah", "Zebul", "Zebulonite", "Zebulun", "Zebulunites", "Zechariah", "Zedad", "Zedekiah", "Zeeb", "Zelah", "Zelek", "Zelophehad", "Zelotes", "Zelzah", "Zemaraim", "Zemarite", "Zemira", "Zenan", "Zenas", "Zephaniah", "Zephath", "Zephathah", "Zephi", "Zepho", "Zephon", "Zephonites", "Zer", "Zerah", "Zerahiah", "Zered", "Zereda", "Zeredathah", "Zererath", "Zeresh", "Zereth", "Zeri", "Zeror", "Zeruah", "Zerubbabel", "Zeruiah", "Zetham", "Zethan", "Zethar", "Zia", "Ziba", "Zibeon", "Zibia", "Zibiah", "Zichri", "Ziddim", "Zidkijah", "Zidon", "Zidonians", "Zif", "Ziha", "Ziklag", "Zillah", "Zilpah", "Zilthai", "Zimmah", "Zimran", "Zimri", "Zin", "Zina", "Zion", "Zior", "Ziph", "Ziphah", "Ziphims", "Ziphion", "Ziphites", "Ziphron", "Zippor", "Zipporah", "Zithri", "Ziz", "Ziza", "Zizah", "Zoan", "Zoar", "Zoba", "Zobah", "Zobebah", "Zohar", "Zoheleth", "Zoheth", "Zophah", "Zophai", "Zophar", "Zophim", "Zorah", "Zorathites", "Zoreah", "Zorites", "Zorobabel", "Zuar", "Zuph", "Zur", "Zuriel", "Zurishaddai", "Zuzims");
my @germanNames = ("Abegg", "Abend", "Abendroth", "Abraham", "Ackermann", "Adam", "Agricola", "Ahl", "Ahle", "Ahlwardt", "Ahrens", "Aichinger", "Albrecht", "Alexander", "Alt", "Altdorf", "Altdorfer", "Alten", "Altenstein", "Alter", "Altermann", "Alterman", "Althaus", "Altheim", "Altherr", "Altmann", "Altman", "Oldman", "Amann", "Aman", "Ammann", "Amman", "Ammon", "Amonn", "Ambros", "Amer", "Ammelung", "Amsler", "Andres", "Anhauser", "Annaeus", "Anschutz", "Ernst", "Hermann", "Ottomar", "Aponius", "Apel", "Apell", "Apelt", "Apfel", "Apfelbaum", "Appel", "Arendt", "Apt", "Apter", "Arnd", "Arndt", "Arndts", "Arnold", "Aschenbach", "Aslan", "Assmann", "Au", "Auch", "Auer", "Augustin", "Auerbach", "Auerswald", "Aulbach", "B", "Bach", "Bachmann", "Bachman", "Pachmann", "Pachman", "Bahle", "Bahlo", "Ballack", "Bassmann", "Bassmann", "Balzer", "Bamberg", "Bamberger", "Bartsch", "Bartzsch", "Basch", "Basse", "Bassermann", "Bauch", "Baudissin", "Baudler", "Bauer", "Bauerle", "Bauernfeind", "Bauernfeld", "Bauersox", "Bauersachs", "Baum", "Baumgart", "Baumgartl", "Baumgarten", "Paumgarten", "Baumgartner", "Paumgartner", "Baumann", "Bauman", "Becher", "Becherer", "Bechinie", "BeckBock", "Boeck", "Becke", "Becker", "Bekker", "Beckmann", "Beckman", "Beckermann", "Beckerman", "Behn", "Behren", "Behrens", "Behrent", "Behrend", "Behrends", "Behrendt", "Bellingshausen", "Bendemann", "Bendeman", "Bender", "Berg", "Berger", "Bergner", "Bergmann", "Bergman", "Bergstraesser", "Bernhard", "Bezold", "Beyer", "Beier", "Bayer", "Baier", "Bezzenberger", "Bieber", "Biechl", "Biedermann", "Biederman", "Bier", "Bierbaum", "Biermann", "Bierman", "Beermann", "Beerman", "Binder", "Binding", "Binswanger", "Birnbaum", "Biron", "Birons", "Bitter", "Bittner", "Blacher", "Blei", "Bleibtreu", "Bloch", "Blum", "Blume", "Bloom", "Blumenberg", "Bloomberg", "Blumenfeld", "Bloomfield", "Blumentritt", "Bodendorf", "Boenk", "Boink", "Bogner", "Bohm", "Bohme", "Bohmer", "Bohn", "Boner", "Bonhoeffer", "Bonner", "Borchardt", "Borcharding", "Bossong", "Boxberg", "Brach", "Brandenburg", "Brand", "Brandt", "Brant", "Brandstetter", "Brandstadter", "Brauchitsch", "Braun", "Brown", "Braune", "Brauner", "Brehm", "Brehmer", "Bremer", "Brentano", "Brendel", "Breslau", "Breslauer", "Brentano", "Brennecke", "Brenneke", "Breid", "Breit", "Breithaupt", "Bretschneider", "Brill", "Brink", "Brinkmann", "Brinker", "Brinkmeyer", "Broch", "Brockdorf", "Brockhaus", "Brockhouse", "Brockhof", "Brodhuhn", "Broring", "Brotkopf", "Brubacher", "Bruch", "Bruck", "Bruck", "Bruhl", "Bruhlmeier", "Brunner", "Brunhoff", "Buch", "Bucher", "Buchner", "Bucker", "Buckwalter", "Buder", "Bulow", "Bultel", "Burkhard", "Busch", "Buss", "Busse", "Bussmann", "Busemann", "Buxtorf", "Claus", "Clausen", "Corper", "Crep", "Cullmann", "Cuno", "Curschmann", "Curtius", "Dasler", "Dangel", "Danneberg", "David", "Degenhardt", "Deisler", "Deissler", "Delbruck", "Delitzsch", "Delling", "Dempewolf", "Denke", "Deppe", "Derg", "Dickel", "Dieckmann", "Diet", "Diez", "Dietzel", "Donath", "Doppler", "Dorn", "Drechsler", "Dreher", "Drucker", "Duncker", "Dunkel", "Durrschnabel", "Duwensee", "Ebenberger", "Eberl", "Ebert", "Eberst", "Ebner", "Eckhoff", "Eckhardt", "Edelmann", "Edelstein", "Edmund", "Egbers", "Egner", "Ehrhardt", "Ehrlich", "Ehrlichmann", "Ehrismann", "Eich", "Eichheim", "Eichhorn", "Eichmann", "Eichrodt", "Eicke", "Eilenberg", "Einhorn", "Einstein", "Eisen", "Eisenhauer", "Eisenhuth", "Eisenmann", "Eisenstein", "Eisler", "Eisner", "Emmelmann", "Engel", "Engelhard", "Engel", "Engels", "Ernst", "Erman", "Eschenbach", "Fahrenheit", "Fahrion", "Falk", "Fassbinder", "Feierabend", "Feigel", "Feld", "Feldmann", "Feldstein", "Fehr", "Fein", "Feinberg", "Feinberger", "Feinmann", "Feinstein", "Feller", "Feuerbach", "Fichtner", "Fichthorn", "Ficker", "Fiedler", "Finck", "Fischer", "Fleischer", "Fleischmann", "Fleischhauer", "Flemming", "Florig", "Forge", "Forster", "Forkel", "Franck", "Frank", "Franz", "Franzsen", "Freckmann", "Frei", "Freitag", "Frenzel", "Freud", "Freund", "Frick", "Fried", "Friedl", "Friedberg", "Friedburg", "Friedek", "Friedheim", "Friedland", "Friedlaender", "Friedemann", "Friedmann", "Friedreich", "Friedenthal", "Friedrich", "Frimmel", "Frisch", "Fritsch", "Frohlich", "Frohlichmann", "Frohlicher", "Fromm", "Fruchtenbaum", "Fuchs", "Funkel", "Funkelstein", "Gabler", "Galanter", "Ganz", "Gantz", "Gartner", "Gardner", "Gartner", "Gehlhausen", "Geiger", "Geisel", "Geisler", "Geissler", "Geiszler", "Geister", "George", "Gerber", "Gerdes", "Gerhard", "Gerhardt", "Gerlach", "Gerrich", "Gerster", "Gesell", "Gesner", "Gessner", "Gies", "Giese", "Glauber", "Gliem", "Gluck", "Glucklich", "Gold", "Goldberg", "Goldberger", "Goldenberg", "Goldenberger", "Goldblatt", "Goldblat", "Goldblum", "Goldbloom", "Goldfeld", "Goldmann", "Goldschmied", "Goldsmith", "Goldstein", "Goldsteiner", "Goldstucker", "Goldwasser", "Goldenthal", "Goldenthaler", "Goldzieher", "Golz", "Gottfried", "Gotthard", "Gottschalk", "Gotz", "Goughnour", "Graf", "Grant", "Graumann", "Grass", "Greven", "Griesinger", "Gross", "Grossmann", "Gruber", "Guggenheim", "Guthmann", "Gysi", "Haag", "Haas", "Haar", "Haber", "Habich", "Hache", "Hackmann", "Hagen", "Haggenmacher", "Hahn", "Hahnemann", "Hain", "Hainisch", "Halbach", "Haller", "Hallgarten", "Hammerschlag", "Hammerschmidt", "Hammerstein", "Hamburg", "Homberg", "Hanf", "Hanisch", "Hankel", "Haring", "Harnack", "Hartmann", "Hasenclever", "Hastedt", "Hatzfeld", "Hauch", "Hauf", "Haugwitz", "Hauptmann", "Hauser", "Hausmann", "Houseman", "Hausner", "Hauschild", "Havenstein", "Hayek", "Heck", "Hecke", "Hecker", "Heckel", "Heffelfinger", "Hege", "Heichel", "Heilmann", "Heider", "Hiedler", "Hitler", "Heim", "Heimer", "Hein", "Heine", "Heinemann", "Heinicke", "Heinrich", "Heinz", "Heinze", "Helle", "Heller", "Heller", "Hellmann", "Helmann", "Hellmonds", "Helm", "Helms", "Helwig", "Hempel", "Henschel", "Herberg", "Herberger", "Herbst", "Herder", "Herk", "Herkomer", "Herold", "Herr", "Hertwig", "Herz", "Herzog", "Hess", "Hesse", "Hesselbarth", "Hetsch", "Hettinger", "Hildebrand", "Hillebrand", "Hilgendorf", "Hiller", "Himmel", "Hinkel", "Hintz", "Hirt", "Hyrtl", "Hiss", "Hochheimer", "Hochstetler", "Hochstetter", "Hofgen", "Hofheins", "Hofmann", "Hock", "Holpp", "Holz", "Holzappel", "Hopfes", "Huber", "Hueber", "Hubermann", "Huels", "Humbold", "Hupfeld", "Hut", "Hutter", "Jachmann", "Jager", "Jahn", "Jacobson", "Jauch", "Jellinghaus", "Jentzsch", "Jhering", "Jessel", "John", "Jost", "Jung", "Jungmann", "Jungnickel", "Just", "Kaftan", "Kanitz", "Kahl", "Kahn", "Kaiser", "Kamber", "Kapp", "Kastner", "Kaufer", "Kaufmann", "Kaun", "Keyserling", "Keller", "Kellermann", "Kerner", "Kesselring", "Kiefer", "Kienzle", "Kies", "Kiesel", "Kiesselbach", "Kiese", "Kinder", "Kirchner", "Kirsch", "Kirschbaum", "Kirst", "Kittel", "Klaproth", "Klaus", "Klein", "Klappert", "Kleinert", "Klier", "Klinger", "Klock", "Klopstock", "Kloster", "Klotz", "Klutz", "Kluck", "Kluckhohn", "Klug", "Kluge", "Klugmann", "Knab", "Knapp", "Knebel", "Knoblauch", "Knoebl", "Knoll", "Koch", "Cocceji", "Kohler", "Kolb", "Kolbe", "Kolmar", "Konig", "Konrad", "Kopfer", "Kopp", "Korner", "Kornfeld", "Kranz", "Kratt", "Kraus", "Krause", "Kramer", "Krekeler", "Krieger", "Kroll", "Krug", "Kruger", "Krummacher", "Krupp", "Kretschmer", "Kreuzer", "Kugel", "Kuhn", "Kuehn", "Kunst", "Kunz", "Kupfer", "Kupfermann", "Kurz", "Kurzmann", "Lackner", "Lahm", "Lammers", "Lamsdorf", "Landesmann", "Landmann", "Landsmann", "Landsberg", "Landsberger", "Landskron", "Landzettel", "Lang", "Langbein", "Lange", "Langnick", "Laufenberg", "Laufer", "Laugel", "Laurentius", "Laut", "Lauterbach", "Lebrecht", "Leiter", "Leitner", "Leitz", "Lechner", "Lehmann", "Lehner", "Lehr", "Lehrer", "Lehrmann", "Lenssen", "Lentzy", "Lenz", "Lerner", "Lessing", "Leutheusser", "Levetzow", "Lewald", "Lei", "Lichtenberg", "Lichtenstein", "Littmann", "Liebermann", "Lieder", "Liening", "Lind", "Lindau", "Lindemann", "Lindenbaum", "Lindenfeld", "Lindner", "Linke", "Linssen", "Lipsius", "List", "Litt", "Lobmeyer", "Lobmeyr", "Loffler", "Lohner", "Lorenz", "Losch", "Lotz", "Lochte", "Low", "Lowith", "Lorber", "Lustig", "Lubke", "Lueg", "Lucking", "Lussky", "Luttge", "Klevenow", "Mahl", "Mahle", "Mahler", "Mahlberg", "Maler", "Mahlau", "Mahr", "Maislinger", "Maltzahn", "Maltitz", "Maltz", "Mangold", "Mann", "Marg", "Markowicz", "Marr", "Martin", "Martens", "Marx", "Mathesius", "Mauersberger", "Maurenbrecher", "Mautner", "May", "Mayo", "Meibom", "Meier", "Meyer", "Meyers", "Maier", "Mayer", "Mayr", "Meir", "Meyr", "Mair", "Mayr", "Meissner", "Melzer", "Memminger", "Menninger", "Menz", "Menzel", "Menzer", "Metzelder", "Merkel", "Mertesacker", "Merz", "Metzger", "Michel", "Mickler", "Micus", "Milde", "Miller", "Minnich", "Mitscherlich", "Mohl", "Mohr", "Mohring", "Moldenhauer", "Molitor", "Mollenbeck", "Moll", "Moller", "Moltke", "Morgenrot", "Morgenstern", "Moser", "Moses", "Muhlenberg", "Muhmel", "Muller", "Moller", "Munch", "Munchow", "Munster", "Munz", "Nagtigal", "Nadelman", "Nagel", "Naumann", "Nahr", "Nerius", "Nest", "Nestle", "Neubauer", "Neubert", "Neuhoff", "Neumann", "Neurath", "Nicolai", "Nickel", "Niebuhr", "Niemeyer", "Nitzsch", "Noack", "Nordhaus", "Nordmann", "Noth", "Nothnagel", "Nurnberg", "Nuss", "Obenauer", "Obenaus", "Oelsner", "Oggenfuss", "Oliver", "Onken", "Opitz", "Osiander", "Ossege", "Oswald", "ottinger", "Otto", "Ottl", "Palm", "Pappenheim", "Pasch", "Paschek", "Pedersen", "Pelz", "Perbandt", "Perlich", "Peter", "Peters", "Petersen", "Petry", "Pfaff", "Pfaffner", "Pflucker", "Pfeiffer", "Pick", "Pilsak", "Plagemann", "Planert", "Plat", "Platt", "Platten", "Platz", "Poeschl", "Pohl", "Pohlen", "Pommer", "Pommerenke", "Pomeranz", "Popp", "Portmann", "Preus", "Preusker", "Prinz", "Brinz", "Probst", "Puderbach", "Pugner", "Purucker", "R", "Radetzky", "Radunz", "Raugal", "Rauland", "Rechter", "Rechtmann", "Redlich", "Riehl", "Reich", "Reichmann", "Reichart", "Reichenbach", "Reichenberg", "Reinach", "Reimann", "Reinhard", "Reinhardt", "Remak", "Renner", "Rentz", "Reple", "Reuss", "Reuter", "Rewald", "Rhodes", "Richter", "Richtmann", "Riedesel", "Riegel", "Riehl", "Riehm", "Riemann", "Riemer", "Riesbeck", "Rilke", "Rockmeier", "Rodenburg", "Roentgen", "Rohde", "Rohlfs", "Rohrbach", "Rolfes", "Romberg", "Ronstadt", "Rosen", "Rosenbach", "Rosenberg", "Rosenberger", "Rosenblum", "Rosenblatt", "Rosendorf", "Rosenfeld", "Rosenfelder", "Rosenheim", "Rosenheimer", "Rosenmann", "Rosenstein", "Rosenthal", "Rosenthaler", "Rosenwald", "Rosenzweig", "Rosenquist", "Rossmann", "Roth", "Rothenberg", "Rothmann", "Sachs", "Sachse", "Saxl", "Sacher", "Saggau", "Sailer", "Salinger", "Sohlinger", "Samson", "Sch", "Schacer", "Schadler", "Schafer", "Schaff", "Schalk", "Schanz", "Schatz", "Scheele", "Scheetz", "Schein", "Scheiner", "Scheler", "Schellhorn", "Schenk", "Schenker", "Scherer", "Scheu", "Schick", "Schicklegruber", "Schiff", "Schiffer", "Schilgen", "Schiller", "Schindele", "Schindler", "Schirmer", "Schl", "Schlachter", "Schlegel", "Schleicher", "Schlesier", "Schlesinger", "Schleyer", "Schlick", "Schlimper", "Schlitz", "Schlumberger", "Schm", "Schmader", "Schmale", "Schmalenbach", "Schmalz", "Schmerbeck", "Schmidt", "Schmied", "Schmitt", "Schmitz", "Schmid", "Schn", "Schnabel", "Schneemann", "Schneider", "Schneidermann", "Schnur", "Schnurre", "Schnurrer", "Schnitzer", "Schnitzler", "Scho", "Schoeller", "Scholz", "Schopenhauer", "Schr", "Schrader", "Schreck", "Schreckengost", "Schreffler", "Schreiber", "Schreiter", "Schroder", "Schu", "Schubart", "Schubert", "Schuchhardt", "Schuerman", "Schulenburg", "Schulz", "Schulze", "Schult", "Schulte", "Schulthess", "Schumacher", "Schumann", "Schupfer", "Schurmann", "Schurz", "Schussler", "Schuster", "Schutt", "Schutz", "Schw", "Schwab", "Schwabach", "Schwabenbauer", "Schwager", "Schwann", "Schwanthaler", "Schwarz", "Schwartzberg", "Schwarzeneggar", "Schwarzkopf", "Schwarzmann", "Schwarze", "Schwarzschild", "Schweizer", "Schweren", "Schwering", "Se", "Seidel", "Seydlitz", "Selbmann", "Selig", "Zelig", "Seelig", "Seliger", "Seligmann", "Semper", "Senn", "Siebert", "Siebold", "Siegl", "Siemens", "Silber", "Silbermann", "Silverman", "Simmel", "Simrock", "Singer", "Spaller", "Spark", "Spee", "Spengler", "Sperber", "Sperger", "Spiegel", "Spiegelmann", "Spiel", "Spieler", "Spielmann", "Spies", "Spiro", "Spitz", "Spitzer", "Spranger", "Sprengel", "Sprenger", "Springer", "Stadler", "Staib", "Standorf", "Stark", "Starker", "Stauben", "Stauber", "Staudinger", "Stauffer", "Hohenstauffen", "Stecher", "Steglich", "Steichen", "Steig", "Stein", "Steinbach", "Steinberg", "Steinheim", "Steinmann", "Steiner", "Stern", "Sternberg", "Steuer", "Still", "Stiller", "Stolz", "Storm", "Storch", "Storz", "Straub", "Straube", "Streiff", "Strobl", "Strohbeck", "Strecker", "Stu", "Stumpf", "Sturtz", "Suchenwirth", "Sulz", "SulzbachSultzbach", "Sumachbaum", "Snotherly", "Taaffe", "Tafel", "Tambke", "Tamm", "Taub", "Taubert", "Taubler", "Tausch", "Tegeler", "Teichmann", "Telemann", "Telgen", "Tell", "Teltschik", "Teuber", "Teubner", "Thal", "Thalberg", "Thalberger", "Dahl", "Thiele", "Thieme", "Thiersch", "Thorwald", "Tieck", "Tietz", "Timpf", "Tisch", "Trager", "Trattner", "Trausch", "Trautmann", "Trautwein", "Trier", "Troltsch", "Trimberg", "Troger", "Tschirner", "Tummler", "Ubelhack", "Uhlemann", "Uhlenhuth", "Ullmann", "Ulmer", "Umthun", "Unger", "Unterweger", "Ursprung", "Vaihinger", "Vogel", "Vogelin", "Vogler", "Vogt", "Voigt", "Volkmann", "Volland", "Voss", "Wachter", "Wachtel", "Wagenseil", "Wagner", "Wahl", "Wahlberg", "Wahle", "Wahr", "Waitz", "Wald", "Walde", "Waldmann", "Waldheim", "Waldschmidt", "Waldstein", "Walter", "Weber", "Wechsler", "Weck", "Wehlau", "Weidman", "Weigel", "Weiler", "Weinbaum", "Weinberg", "Weiner", "Weingarten", "Weinglas", "Weinstein", "Weis", "Weisbrod", "Weise", "Weisenhaus", "Weiss", "Weissenadlers", "Weizsacker", "Welcker", "Welke", "Weld", "Wellmann", "Wenger", "Wenner", "Wenzel", "Werner", "Wertheim", "Wertmuller", "Westermann", "Westheimer", "Wiegel", "Wiener", "Wiese", "Wiesen", "Wiesenthal", "Wiedau", "Wiegand", "Wieland", "Wieser", "Wiegmann", "Wild", "Wilken", "Willmann", "Wilms", "Windisch", "Windischgratz", "Winkel", "Winkelmann", "Winkler", "Winterbauer", "Wirth", "Wittig", "Wittmann", "Wohl", "Woitas", "Wolf", "Wolfe", "Wolfner", "Wolfstein", "Wolheim", "Wolflin", "Wolkenberg", "Womeldorff", "Wucherer", "Wunderlich", "Wuhr", "Wurm");
my @nobility = ("du", "des", "sir", "de", "von", "zu", "und", "of", "dom", "di", "van");
my @titles = ("Emperor", "Caesar", "Tsar", "Czar", "Csar", "Tzar", "Kaiser", "King", "Prince", "Duke", "Lord");

sub generateName {
	my $name;
	while (1) {
		my $rand = int(rand(6));
		if (!$rand) {
			$name = $biblicNames[rand @biblicNames]." ".$germanNames[rand @germanNames];
		} elsif ($rand == 1) {
			$name = $titles[rand @titles]." ".$germanNames[rand @germanNames];
		} elsif ($rand == 2) {
			$name = $germanNames[rand @germanNames]." ".$nobility[rand @nobility]." ".$germanNames[rand @germanNames];
		} elsif ($rand == 3) {
			$name = $germanNames[rand @germanNames]." ".$nobility[rand @nobility]." ".$biblicNames[rand @biblicNames];
		} elsif ($rand == 4) {
			$name = $titles[rand @titles]." ".$nobility[rand @nobility]." ".$germanNames[rand @germanNames];
		} elsif ($rand == 5) {
			$name = $biblicNames[rand @biblicNames]." ".$biblicNames[rand @biblicNames];
		}
		last if (length($name) <= 23 && length($name) >= 16);
	}
	return $name;
}

return 1;


