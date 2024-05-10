# useradministration.pl
#
# This perl script comes with the document "Setting up an email server with Redhat Linux"
# which can be found at http://www.netikus.net/documents/Linux-Mailserver-Installation.pdf
#
# The script is part of the file Linux-Mailserver-Installation.zip which can be found in the
# downloads section at http://www.netikus.net/
#
# This script creates an interface to the linux installation described in the document. You
# can create users, modify users and their corresponding entries in the LDAP database, delete
# users and control the 4 major services configured
#
use strict 'vars';
use POSIX;
use Term::Cap;
use Term::ReadKey;
use Term::ANSIColor;
use Passwd::Linux qw(modpwinfo rmpwnam setpwinfo mgetpwnam);
use Net::LDAP;

# This part simply clears the screen
my $termios = POSIX::Termios->new();
$termios->getattr;
my $speed = $termios->getospeed;

my $termcap = Term::Cap->Tgetent({TERM => undef,OSPEED => $speed });

MAINMENU: $termcap->Tputs('cl',1,STDOUT);
# This part simply clears the screen




# THIS CONSTANTS CAN BE EDITED BY YOU AND MIGHT EVEN HAVE TO #

my $ldap_admin = "cn=Manager, o=OrganicBrownSugar, c=US";
my $ldap_organ = "Organic Brown Sugar";
my $ldap_count = "US";
my $ldap_pwd   = "secret";
my @locations  = ("Blackwood");
my $alias_file = "/etc/aliases";

# THIS CONSTANTS CAN BE EDITED BY YOU AND MIGHT EVEN HAVE TO #




# Initializing all variables used throughout the script
my $username = "";
my $password = "";
my @fullname = "";
my $fullname = "";
my $fullname2 = "";
my $lastname = "";
my $description = "";
my $location = "";
my $telephonenumber = "";
my $groups = "";
my $user_exists = 1;
my $email = "";
my $new_value = "";
my @change_attribute = "";

my $choice = "";
my $killfiles = "";
my $input_ok = 0;
my $change_value = 0;
my $verify = 0;
my $temp = "";
my @temp = "";
my $counter = 0;
my $output = "";
my $u_string = "";
my $l_string = "";
my $m_string = "";
my $e_string = "";
my $d_string = "";
my $ldap;
my $msg;
my $entry;
my $temp_fullname;

my $nil = "";
my $uid = "";
my $gid = "";
my $home = "";
my $shell = "";
my $dn = "";
my $result;

my $path = "";
my @servicenames = "";
my @services = "";
my @action = "";
# Initializing all variables used throughout the script

sub CreateNames
{
	# Create a username by adding the first 4 letters of the lastname and the first
	# 4 letters of the firstname 
	# Please note that this is not very flexibel, e.g. if  either first or lastname
	# are shorter than 4 letters
	# useradd will report an error later if the user already exists
	my ($fullname) = @_;
	my @name;

	my @fullname = split(/ /,$fullname);	# Put the names into an array
	my $a = substr($fullname[0],0,4);
	my $b = substr($fullname[$#fullname],0,4);
	$name[0] = lc($b.$a);
	$name[1] = $fullname[$#fullname]." ".$fullname[0];
	$name[2] = $fullname[$#fullname];
	
	return @name;
}

# The user wants a list of all locations
sub ViewLocations
{
	for (@locations)
		{ print "$_ " }
	print "\n";
}

# Check if the location that was entered by the user actually exists!
sub CheckLocation
{
	my ($location) = @_;
	my $input = 0;	

	for (@locations)
	{
	    if ($_ eq uc($location))
		{ $input = 1 }
	}
	print "\t\t\t\tUnknown location entered\n" if $input == 0;
	return $input;
}

sub Alias
{
	my ($action,$username,$email_alias,$email_alias_new) = @_;
	$action = lc($action);
	$username = lc($username);
	$email_alias = lc($email_alias);
	$email_alias_new = lc($email_alias_new);
	my @aliases_current = "";
	my @aliases_new = "";

	# READ ALIAS FILE
	if ($action eq "modify" || $action eq "modify_user" || $action eq "delete")
	{
	    open (ALIASES,"<$alias_file");
		@aliases_current = <ALIASES>;
	    close(ALIASES);
	}
	
	# MODIFY ALIASES DATABASE (ALIAS)
	if ($action eq "modify")
	{
	    for(@aliases_current)
		{ $_ =~ s/^$email_alias/$email_alias_new/ if /^$email_alias:/ }
	
	    open (ALIASES,">$alias_file");
	    for(@aliases_current)
		{ print ALIASES $_ }
	    close(ALIASES);
	}
	
	# MODIFY ALIASES DATABASE (USERNAME)
	if ($action eq "modify_user")
	{
	    for(@aliases_current)
		{ $_ =~ s/$username/$email_alias/ if /$username$/ }
	
	    open (ALIASES,">$alias_file");
	    for(@aliases_current)
		{ print ALIASES $_ }
	    close(ALIASES);
	}

	# REMOVE FROM ALIASES DATABASE
	if ($action eq "delete")
	{
	    for(@aliases_current)
		{ push(@aliases_new,$_) if !/$username$/ }

	    open (ALIASES,">$alias_file");
	    for(@aliases_new)
		{ print ALIASES $_ }
	    close(ALIASES);
	}
	
	# APPEND TO ALIASES DATABASE
        if ($action eq "add")
	{
    	    open (ALIASES,">>$alias_file");
		    print ALIASES $email_alias.":\t$username\n";
		close(ALIASES);
	}

	# UPDATE ALIASES DATABASE
	my $nil = system("/usr/bin/newaliases");

	return 1;
}

print color("blue");
print "\n             WELCOME TO THE USER MANAGMENT APPLICATION\n\n\n\n";
print color("reset");
print "                        Choose an option\n\n";
print "                         (C)reate User\n";
print "                         (M)odify User\n";
print "                         (D)elete User\n";
print "                         (L)ist  Users\n\n";
print "                      (1) Control DNS\n";
print "                      (2) Control SENDMAIL\n";
print "                      (3) Control POP3 and IMAP\n";
print "                      (4) Control LDAP\n\n\n";
print color("green"),"                             (E)xit\n\n\n\n";
print color("reset");

ReadMode('cbreak');			# Set readmode to only one key
$choice = ReadKey(0);			# Read one key

$termcap->Tputs('cl',1,STDOUT);		# Clear screen
ReadMode('normal');			# Set readmode to normal (more keys!)

$choice = uc($choice);

# CREATE NEW USER
if ($choice eq "C")
{
	print "CREATE USER\n\n";

	$user_exists = 1;
	# Do this until the a username is entered that does not exist
	while ($user_exists == 1)
	{
		print "Username (ENTER for default) : ";
		$username = <STDIN>;
		chomp($username);
		$username = lc($username);

		$user_exists = 0;
		my @temp = getpwnam($username);			# Look if user exists
		if (defined($temp[0])) { $user_exists = 1 }
		undef(@temp);

		print "\t\t\t\tUser already exists !\n" if $user_exists == 1 && $username ne "";
		$user_exists = 0 if $username eq "";
	}

	# Don't show password typed. This is just for show as the password is being
	# displayed later on anyways haha
	ReadMode('noecho');
	print "Password (ENTER for default) : ";
	$password = ReadLine(0);
	print "\n";
	ReadMode('normal');

	print "Fullname (First Last)        : ";
	$fullname = <STDIN>;
	chomp ($fullname);

	print "Description                  : ";
	$description = <STDIN>;
	chomp ($description);

	$input_ok = 0;
	until ($location ne "" && $input_ok == 1)
	{
		print "Location (ENTER for list)    : ";
		$location = <STDIN>;
		chomp ($location);
		$location = uc($location);

		# The user wants a list of all locations
		if ($location eq "")
			{ ViewLocations() }
		else
			{ $input_ok = CheckLocation($location) }
	}

	print "Telephone Number             : ";
	$telephonenumber = <STDIN>;
	chomp ($telephonenumber);

	print "Groups (separate with \",\")   : ";
	$groups = <STDIN>;
	chomp ($groups);

	print "\n\nIS THE INFORMATION ENTERED ABOVE CORRECT ? [y/n]";
	ReadMode('cbreak');
	$verify = ReadKey(0);
	ReadMode('normal');

	# Go back to the start if the user changed his mind
	goto MAINMENU if uc($verify) eq "N";

	# CORRECT STRINGS
	# Make the first letter of every word uppercase
	for (split(' ',$fullname))
		{ $temp .= " ".ucfirst($_) }
	$temp =~ s/^\s//;		# Remove the leading space character
	$fullname = $temp;

	# Use function to create the username and reverse the fullname
	($username,$fullname2,$lastname) = CreateNames($fullname);
	$location = ucfirst(lc($location));
	
	# Set the password if it was not entered before, will look like "aj3#dIE)d"
	if ($password eq "\n")
	{
		$password = "";
		# The characters for our password are in the following ascii range: 33-90,97-122
		for ($i=1;$i<=9;$i++)
		{
			$r = int(rand(122))+1;
			if ($r < 33 || $r == 39 || ($r > 90 && $r < 97)) { redo }
			else { $password .= chr $r }
		}
		$password .= "\n";
	}

	$termcap->Tputs('cl',1,STDOUT);
	
	# This will be executed in a minute
	$u_string = "/usr/sbin/useradd $username -m -n -c \"$fullname ($location)\"";
	
	if ($groups ne "")
		{ $u_string .= " -G $groups" }

	# Now do it!
	$output = system($u_string);

	# Now we copy the quota settings from our template user
	$u_string = "edquota -p template $username";
	system($u_string);

	print "USER: ";
	if ($output == 0) 	{ print "CREATE OK\n" }
	else			{ print "CREATE ERROR\n" }
	
	# Configure a password if the user has been created
	if ($output == 0)
	{
		open (PASSWD,"|passwd $username --stdin");
			print PASSWD $password;
		close(PASSWD);
	}

	print "\nUSERNAME: $username";
	print "\nPASSWORD: $password\n";

	my $dn = "cn=$fullname, ou=".ucfirst(lc($location)).", o=$ldap_organ, c=$ldap_count";

	# Now we add the userdata into the LDAP database
	$ldap = Net::LDAP->new('localhost') or die "$@";
	$ldap->bind ( 	dn 	 => $ldap_admin,
			password => $ldap_pwd 	);

	my $result = $ldap->add (
	dn	=> $dn,
	attr	=> [	'objectclass' 	=> 	"person",
			'cn' 		=>	[$fullname, $fullname2],
			'sn' 		=>	$lastname,
			'mail'		=>	"$username\@".lc($location).".organicbrownsugar.com",
			'telephonenumber' =>	$telephonenumber,
			'description'	=>	$description,
			'uid'		=>	$username,
			'ou'		=>	$location
		   ]
	);
	
	print "LDAP: ";
        if ($result->error eq "Success")	{ print "CREATE OK\n" }
	else 		{ print "CREATE ERROR: ",$result->error,"\n" }
	
	# ADD "NICE" EMAIL ADDRESS TO THE ALIAS DATABASE
	my ($alias) = $fullname;
	$alias =~ s/ /\./g;
	Alias("add","$username","$alias","");
		
	print "\n... press any key ...\n";
	ReadMode('cbreak');
	$choice = ReadKey(0);
	ReadMode('normal');
	goto MAINMENU;
}
# DELETE A USER
elsif ($choice eq "D")
{
	print "DELETE USER\n\n";

	# Check if the user to delete exists
	$user_exists = 0;
	until ($user_exists == 1)
	{
		print "Username                          : ";
		$username = <STDIN>;
		chomp($username);
		@temp = getpwnam($username);		# Get the user data
		if (!defined($temp[0]))
		{ 
			$user_exists = 0;
			print "\t\t\t\tUser $username does not exist!\n";
		}
		else
			{ $user_exists = 1 }
	}

	# Extract the location from the description field
	# The location is always in brackets
	($location) = ($temp[6] =~ /.+\((.+)\)/);
	($fullname) = ($temp[6] =~ /(.+)\(.+\)/);

	print "Full Name                         : $fullname\n";
	print "Location                          : $location\n";
	ReadMode('cbreak');

	print "Remove entire homedirectory [y/n] : ";
	$killfiles = ReadKey(0);
	$killfiles = uc($killfiles);
	print $killfiles;
	ReadMode('normal');

	# Add the "-f" string to delete all the users data
	if ($killfiles eq "Y") { $d_string = "/usr/sbin/userdel -f $username" }
	else { $d_string = "/usr/sbin/userdel $username" }

	print "\n\nIS THE INFORMATION ENTERED ABOVE CORRECT ? [y/n]";
	ReadMode('cbreak');
	$verify = ReadKey(0);
	ReadMode('normal');

	goto MAINMENU if uc($verify) eq "N";

	$termcap->Tputs('cl',1,STDOUT);
	$output = system($d_string);
	
	print "USER: ";
	if ($output == 0) 
		{ print "DELETE OK\n" }
	else
		{ print "DELETE ERROR\n" }

	# Now we delete the user from the LDAP database
	$ldap = Net::LDAP->new('localhost') or die "$@";
	$ldap->bind ( 	dn 	 => $ldap_admin,
			password => $ldap_pwd 	);

	$dn = "cn=$fullname,ou=$location,o=$ldap_organ,c=$ldap_count";
	$result = $ldap->delete($dn);
	
	print "LDAP: ";
        if ($result->error eq "Success") { print "DELETE OK\n" }
	else { print "DELETE ERROR: ",$result->error,"\n" }

	# REMOVE FROM ALIAS DATABASE
	Alias("delete",$username,"","");

	print "\n... press any key ...\n";
	ReadMode('cbreak');
	$choice = ReadKey(0);
	ReadMode('normal');
	goto MAINMENU;
}
# LIST USERS
elsif ($choice eq "L")
{
# This defines a nice output that lists our users when used with "write"

format STDOUT_TOP=
Username   Description             Home directory         Shell
===========================================================================
.
format STDOUT=
@<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<<<<<<<@<<<<<<<<<<<<<<<<
$username  $description            $home                  $shell
.

	$termcap->Tputs('cl',1,STDOUT);
	$counter = 0;

	# READ ALL USERS
	open (USERS,"</etc/passwd");
	for (<USERS>)
	{
		chomp($_);
		$counter++;	
		($username,$nil,$uid,$gid,$description,$home,$shell) = split (/:/,$_);
		write;
			if ($counter == 21)
			{
				print "... press any key ...\n";
				ReadMode('cbreak');
				$choice = ReadKey(0);
				ReadMode('normal');
				$counter = 0;
			}
	}
	close(USERS);

	print "... Done ...\n";
	ReadMode('cbreak');
	$choice = ReadKey(0);
	ReadMode('normal');
	goto MAINMENU;
}
# MODIFY A USER
elsif ($choice eq "M")
{
	until ($change_value == 9)
	{
		print "MODIFY USER\n\n";

		# Once again check if the user really exists
		$user_exists = 0;
		if (!$username)
		{
			until ($user_exists == 1)
			{
				print "Username                          : ";
				$username = <STDIN>;
				chomp($username);
				my @temp = getpwnam($username);
				if (!defined($temp[0]))
				{ 
					$user_exists = 0;
					print "\t\t\t\tUser $username does not exist!\n";
				}
				else
					{ $user_exists = 1 }
			}
		}

		my @userdata = getpwnam($username);

		($fullname) = ($userdata[6] =~ /(.+)\(.+\)/);
		($location) = ($userdata[6] =~ /.+\((.+)\)/);

		# Now we connect to the ldap server to retrieve some userdata
		$ldap = Net::LDAP->new('localhost') or die "$@";
		$ldap->bind ( 	dn 	 => $ldap_admin,
				password => $ldap_pwd 	);

		# Let's make a search in the ldap database
		$msg = $ldap->search (
		base	=>	"o=$ldap_organ,c=$ldap_count",
		filter	=>	"(uid=$username)" );
		
		# Now we want two entries that only exist in the ldap database
		$entry = $msg->pop_entry();
		($email) = $entry->get("mail");
		($telephonenumber) = $entry->get("telephonenumber");
		($description) = $entry->get("description");
		my $dn = $entry->dn();
		
		# Do until the user entered something useful
		until ($change_value > 0 && $change_value < 10)
		{
			print "\n";
			print "Username       [1] : $userdata[0]\n";
			print "Full name      [2] : $fullname\n";
			print "Location       [2] : $location\n";
			print "Home Directory [3] : $userdata[7]\n";
			print "Shell          [4] : $userdata[8]\n";
			print "Email address  [5] : $email\n";
			print "Telephone Nr.: [6] : $telephonenumber\n";
			print "Description    [7] : $description\n";
			print "\n-> MAIN MENU   [9]\n\n";
	
			ReadMode('cbreak');
			print "Which value would you like to change [1..9] : ";
			$change_value = ReadKey(0);
			print $change_value;
			ReadMode('normal');
		}

		goto MAINMENU if $change_value == 9;

		if ($change_value ne 2)
		{
			print "\nEnter new value                             : ";
			$new_value = <STDIN>;
			chomp ($new_value);
			
			Alias("modify_user",$username,$new_value,"") if $change_value eq 1;
		}
		else
		{
			print "\nEnter Fullname (First Last) or ENTER        : ";
			$temp_fullname = <STDIN>;
			chomp ($temp_fullname);
			if ($temp_fullname eq "")
			{
			    $temp_fullname = $fullname;
			    print "$temp_fullname\n";
			}
			$input_ok = 0;
			until ($input_ok == 1 && $location ne "")
			{
				print "Enter location (ENTER for list)             : ";
				$location = <STDIN>;
				chomp ($location);
				ViewLocations() if $location eq "";
				$input_ok = CheckLocation($location) if $location ne "";
				$location = ucfirst(lc($location));
			}
			$new_value = "$temp_fullname ($location)";
			
			# MODIFY ALIAS
			if ($fullname ne $temp_fullname)
			{
				my $alias_old = $fullname;
				my $alias_new = $temp_fullname;
				$alias_old =~ s/ /\./g; $alias_old =~ s/\.$//;
				$alias_new =~ s/ /\./g; $alias_new =~ s/\.$//;
				
				Alias("modify",$userdata[0],$alias_old,$alias_new);
			}			
		}

		if ($change_value < 5)
		{
    			# Assing the corresponding switch to the action desired
			@change_attribute = ("","-l","-c","-d","-s");
		
			# Execute the usermod executable
			$m_string = "/usr/sbin/usermod ".$change_attribute[$change_value]." \"".$new_value."\" ".$username;

			$output = system($m_string);
			print "\nUSER: ";
			if ($output == 0) 	{ print "MODIFY OK\n" }
			else			{ print "MODIFY ERROR\n" }
			
			# Remove the ldap entry and create a new one (to change the dn as well)
			if ($change_value < 3)
			{
			    if ($change_value == 1) { $username = $new_value }
			
			    $result = $ldap->delete($dn);
			    print "LDAP: ";
			    if ($result->error eq "Success")	{ print "DELETE OK\n" }
			    else				{ print "DELETE ERROR: ",$result->error }

			    $dn = "cn=$fullname,ou=$location,o=$ldap_organ,c=$ldap_count";

			    $fullname = $temp_fullname if ($temp_fullname ne "");
			    my ($nil,$fullname2,$lastname) = CreateNames($fullname);

			    my $result = $ldap->add (
				dn	=> $dn,
				attr	=> [	'objectclass' 	=> 	"person",
						'cn' 		=>	[$fullname, $fullname2],
						'sn' 		=>	$lastname,
	    					'mail'		=>	"$username\@".lc($location).".organicbrownsugar.com",
						'telephonenumber' =>	$telephonenumber,
						'description'	=>	$description,
						'uid'		=>	$username,
						'ou'		=>	$location
					    ]
			    );

			    print "LDAP: ";
			    if ($result->error eq "Success")	{ print "CREATE OK\n\n" }
			    else				{ print "CREATE ERROR: ",$result->error,"\n\n" }
			}
		}
		else
		{
		    $change_attribute[5] = "mail";
		    $change_attribute[6] = "telephonenumber";
		    $change_attribute[7] = "description";
		    
		    my $result = $ldap->modify ( $dn, replace => { $change_attribute[$change_value] => $new_value } );

		    print "\nLDAP: ";
		    if ($result->error eq "Success")	{ print "MODIFY OK\n\n" }
		    else				{ print "MODIFY ERROR: ",$result->error,"\n\n" }
		}

		$change_value = 0;

		print "\n... press any key ...\n";
		ReadMode('cbreak');
		$choice = ReadKey(0);
		ReadMode('normal');
		$termcap->Tputs('cl',1,STDOUT);
	}
}
# CONTROL SERVICES
elsif ($choice eq "1" || $choice eq "2" || $choice eq "3" || $choice eq "4")
{
	# Define the services and their corresponding values
	$path = "/etc/rc.d/init.d/";
	@servicenames = ("","DNS","Sendmail","Pop3 and Imap","Ldap");
	@services = ("","named","sendmail","xinetd","ldap");
	@action = ("","start","stop","restart","status");

	until ($change_value >0 && $change_value < 6)
	{
		print "\nCONTROL $servicenames[$choice]\n\n";
		print "\t[1] Start Service\n";
		print "\t[2] Stop Service\n";
		print "\t[3] Restart Service\n";
		print "\t[4] Status of Service\n";
		print "\t[5] Main Menu\n\n";

		ReadMode('cbreak');
		print "What would you like to do [1..5] : ";
		$change_value = ReadKey(0);
		print $change_value;
		ReadMode('normal');
	}

	goto MAINMENU if $change_value == 5;

	# Run the correct script with the correct option
	$e_string = $path.$services[$choice]." ".$action[$change_value];
	print "\n\n";
	$output = system($e_string);

	print "\n... press any key ...\n";
	ReadMode('cbreak');
	$choice = ReadKey(0);
	ReadMode('normal');
	goto MAINMENU;
}
print "\n";
