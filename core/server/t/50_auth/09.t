##
## AUTHENTICATION USING LDAP VALIDATION
##
## Here we can check LDAP-based authentication methods.
##
## We need running LDAP server for that
##

use strict;
use warnings;
use utf8;
use English;
use Test::More;
use XML::Simple;
use Data::Dumper;
use OpenXPKI::Exception;
use OpenXPKI::Server::Context qw( CTX );
use OpenXPKI::Server::Init;
use OpenXPKI::Server::Session;
use OpenXPKI::Server::Authentication;

use File::Spec;

#--- check permission to run test
my $test_directory = File::Spec->catfile( 't', '50_auth');
my $semaphore_file = File::Spec->catfile(
			    $test_directory,
                    	    'enable_talk_to_server',
		     );
if( !( -f $semaphore_file) ) {
    plan skip_all => "No ldap server for testing";
};


diag "OpenXPKI::Server::Authentication::LDAP\n";

# search prefix
my $search_prefix        = 'OpenXPKI User '; 

# attribute used to map to auth method
my $role_map_attr       = 'title'; 

# attribute used to map to auth method
my $auth_meth_attr       = 'uid'; 

# attribute value mapped to password authentication
# (password hash is stored in LDAP database) 
my $auth_meth_pw_value   = 'X1';

# attribute value mapped to simple bind authentication
# (password is stored in LDAP database and we try to bind using that password) 
my $auth_meth_bind_value = 'X2';


# Prepaire credentials and role maps for LDAP entries

my @credentials = (
    {
	   'login'=>'A', 
	'password'=>'Ox1',
       'role_attr'=>'manager',
	    'role'=>'User',
	    'meth'=>$auth_meth_pw_value,
	  'result'=>1,
    },
    {
	   'login'=>'B', 
	'password'=>'Ox2',
       'role_attr'=>'manager',
	    'role'=>'User',
	    'meth'=>$auth_meth_bind_value,
	  'result'=>1,
    },
    {
	   'login'=>'C', 
	'password'=>'Ox3',
       'role_attr'=>'programmer',
	    'role'=>'RA Operator',
	    'meth'=>$auth_meth_pw_value,
	  'result'=>1,
    },
    {
	   'login'=>'D', 
	'password'=>'Ox4',
       'role_attr'=>'programmer',
	    'role'=>'RA Operator',
	    'meth'=>$auth_meth_bind_value,
	  'result'=>1,
    },
    {
	   'login'=>'E', 
	'password'=>'Ox5',
       'role_attr'=>'CEO',
	    'role'=>'CA Operator',
	    'meth'=>$auth_meth_pw_value,
	  'result'=>1,
    },
    {
	   'login'=>'F', 
	'password'=>'Ox6',
       'role_attr'=>'CEO',
	    'role'=>'CA Operator',
	    'meth'=>$auth_meth_bind_value,
	  'result'=>1,
    },
);

# Prepaire bad credentials to check exceptions
my @bad_credentials = (
    {'login'=>'Q', 'password'=>'Ox1',},
    {'login'=>'A', 'password'=>'QQQ',},
    {'login'=>'B', 'password'=>'QQQ',},
);

# Prepaire attributes for LDAP entries
my $auth_nodes = {};

foreach my $login_set (@credentials){
  my $auth_cn   = $search_prefix .
	            $login_set->{'login'};       
  my $auth_dn = 'cn=' . $auth_cn . 
                ',o=Security,dc=openxpki,dc=org';
  $auth_nodes->{$auth_dn} = [
			         'cn' => $auth_cn,
			         'sn' => 'Mister X',
		       $role_map_attr => $login_set->{'role_attr'},
		      $auth_meth_attr => $login_set->{'meth'},
		       'userPassword' => $login_set->{'password'},     
                        'objectclass' => [ 
					    'person',
				    	    'inetOrgPerson',
					    'organizationalPerson',
					    'opencaEmailAddress',
					    'pkiUser',
					],    
 	                ];
};

#------------------ ENUMERATE EXTRA TASKS TO CALC TEST NUMBER
my @extra_tasks = (
		    '1  connect to LDAP server',
		    '2  bind to LDAP server',
		    '3  auth configuration',
		);    
my $test_number = scalar @extra_tasks;

 
    my $number_of_credentials = (scalar (keys %{$auth_nodes}));
    my $number_of_bad_credentials = scalar @bad_credentials;
    $test_number += $number_of_credentials * 4 + $number_of_bad_credentials;
#                   NUMBER OF TESTS
#               extras + credentials + bad credentials
#                            | x 4
#                  add_node user role result
#
    plan tests => $test_number;

#------------------- $index will store the number of performed tests.
my $index=0;

#### START of SKIP block - we skip the rest if something goes wrong
##
SKIP: {

# 1) CONNECT TO STARTED SERVER
my $testldap = Net::LDAP->new("localhost:60389");
if( !defined $testldap) {
   diag("Cannot connect to running server (strange), check logs..." .
         "\n skipping ldap server related tests \n"
   );
   skip '', $test_number - $index;
};	
ok(1,"Connect to LDAP server");
$index++;

#### 2) BIND TO LDAP SERVER 
my $msg = $testldap->bind ("cn=Manager,dc=OpenXPKI,dc=org",
                        	password => "secret",
                        	version => 3 );
if ( $msg->is_error()) {
    my $strange_error = "\nCODE => " . $msg->code() . 
    		       "\nERROR => " . $msg->error() .
	                "\nNAME => " . ldap_error_name($msg) .
                        "\nTEXT => " . ldap_error_text($msg) .
                 "\nDESCRIPTION => " . ldap_error_desc($msg) . "\n";
    diag("Cannot bind to running server (strange), check logs..." .
         "\n skipping ldap server related tests \n"
    );
    if( $ENV{DEBUG} ) {
        diag($strange_error);
    };
    skip '', $test_number - $index;
};
ok(1,"Bind to LDAP server");
$index++;

#### 3) ADDING NODES FOR AUTHENTICATION
foreach my $node ( keys %{$auth_nodes} ){
#    print STDERR  "ADDING A GOOD NODE ->  $node \n";
    my @attrs = @{$auth_nodes->{$node}};
    my $attr_flag_index = 0;
    my $attr_index      = 0;
#   here we replace plain passwords with hashes
    foreach my $attr ( @attrs){
	if( $attr eq $auth_meth_attr){
	$attr_flag_index = $attr_index;
	}
	if( $attr eq 'userPassword'){
	last;
	}
	$attr_index++;
    };
    if( ${$auth_nodes->{$node}}[$attr_flag_index+1] eq $auth_meth_pw_value ){

	my $insecure_pass = ${$auth_nodes->{$node}}[$attr_index+1];

# FIXME: we are going to check the other hash algorithms too
#	print STDERR "Orig   pass $insecure_pass \n";
	my $secure_pass = secure_password($insecure_pass,'sha1');

#	print STDERR "Secure pass $secure_pass \n";
	${$auth_nodes->{$node}}[$attr_index+1] = $secure_pass;
#    print STDERR "userPassword Index $attr_index \n";
    };
    $msg = $testldap->add( $node, attr => $auth_nodes->{$node});
    if ( $msg->is_error() ) {
	my $strange_error =    "\n CODE => " . $msg->code() . 
    	        	       "\nERROR => " . $msg->error() .
    		                "\nNAME => " . ldap_error_name($msg) .
                    		"\nTEXT => " . ldap_error_text($msg) .
                         "\nDESCRIPTION => " . ldap_error_desc($msg);
	diag("Cannot work with running server (strange), check logs..." . 
    	     "\n skipping ldap server related tests \n"
	);
	if( $ENV{DEBUG} ) {
    	    diag($strange_error);
	};
	skip '', $test_number - $index;
    };
    ok(1,"Add node $node to LDAP server");
    $index++;
};    
$testldap->unbind;

## nodes are ready, now real authentication tests are coming ...

## init XML cache
OpenXPKI::Server::Init::init(
    {
	CONFIG => 't/config_test.xml',
	TASKS => [
        'current_xml_config',
        'log',
        'dbi_backend',
        'xml_config',
    ],
	SILENT => 1,
    });

## load authentication configuration
my $auth = OpenXPKI::Server::Authentication::LDAP->new({
        XPATH   => ['pki_realm', 'auth', 'handler' ], 
        COUNTER => [ 0         , 0     , 5         ],
});

ok($auth, 'Auth object creation');

    foreach my $login_set (@credentials){
	my $ldap_login      = $login_set->{'login'};       
	my $ldap_password   = $login_set->{'password'};       
	my $expected_role   = $login_set->{'role'};       
	my $expected_result = $login_set->{'result'};       
	
	my ($user, $role, $reply) = $auth->login_step({
	    STACK   => 'LDAP user',
	    MESSAGE => {
    		'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
	        'PARAMS'      => {
        	    'LOGIN'  => $ldap_login,
        	    'PASSWD' => $ldap_password,
    		},
	    },
	});
	is($user, $ldap_login,    'Correct user');
	is($role, $expected_role, 'Correct role');
	if($expected_result){
	    is($reply->{'SERVICE_MSG'}, 'SERVICE_READY', 'Service ready');    
	} else {
	    ok($reply->{'SERVICE_MSG'} ne 'SERVICE_READY', 'Rejection');    
	};    
    };	

    foreach my $login_set (@bad_credentials){
	my $ldap_login      = $login_set->{'login'};       
	my $ldap_password   = $login_set->{'password'};       

        eval {	
	    my ($user, $role, $reply) = $auth->login_step({
		STACK   => 'LDAP user',
		MESSAGE => {
    		    'SERVICE_MSG' => 'GET_PASSWD_LOGIN',
		    'PARAMS'      => {
        	        'LOGIN'  => $ldap_login,
        	        'PASSWD' => $ldap_password,
    		    },
		},
	    });
	};
	ok(OpenXPKI::Exception->caught(),'Bad credentials rejected');
    };	
}; # the end of SKIP BLOCK
1;

# The sub to generate hashes for authentication tests
sub secure_password {
    my $passwd = shift;
    my $algorithm = shift;
    my $digest;
    my $pass_salt='12345';
    my $secure_pass;
    if ($algorithm eq "sha1") {
        $digest = Digest::SHA1->new;
        $digest->add($passwd);
        my $b64digest = $digest->b64digest;
        $secure_pass = $b64digest;
    } elsif ($algorithm eq "md5") {
        my $digest = Digest::MD5->new;
        $digest->add($passwd);
        $secure_pass = $digest->b64digest;
    } elsif ($algorithm eq "crypt") {
        $secure_pass = crypt ($passwd, $pass_salt);
    } elsif ($algorithm =~ /^none$/i) {
        return $passwd;
    } else {
        return undef;
    };               
 return '{' . $algorithm . '}' . $secure_pass;
}
1;
