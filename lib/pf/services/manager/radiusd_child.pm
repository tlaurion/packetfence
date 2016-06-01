package pf::services::manager::radiusd_child;

=head1 NAME

pf::services::manager::radiusd_child

=cut

=head1 DESCRIPTION

pf::services::manager::radiusd_child

Used to create the childs of the submanager radiusd
The first manager will create the config for all radiusd processes through the global variable.

=cut

use strict;
use warnings;
use Moo;
use pf::file_paths qw(
    $conf_dir
    $install_dir
    $var_dir
);
use pf::util;
use pf::config qw(
    %Config
    $management_network
    %ConfigDomain
    @listen_ints
    %ConfigNetworks
);
use NetAddr::IP;
use pf::cluster;
use pf::dhcpd qw (freeradius_populate_dhcpd_config);

extends 'pf::services::manager';

has options => (is => 'rw');

our $CONFIG_GENERATED = 0;

=head2 generateConfig

Generate the configuration for ALL radiusd childs
Executed once for ALL processes

=cut

sub generateConfig {
    my ($self, $quick) = @_;

    unless($CONFIG_GENERATED){
        $self->_generateConfig();

        $CONFIG_GENERATED = 1;
    }
}

=head2 _generateConfig

Generate the configuration files for radiusd processes

=cut

sub _generateConfig {
    my ($self,$quick) = @_;
    $self->generate_radiusd_mainconf();
    $self->generate_radiusd_authconf();
    $self->generate_radiusd_acctconf();
    $self->generate_radiusd_eapconf();
    $self->generate_radiusd_restconf();
    $self->generate_radiusd_sqlconf();
    $self->generate_radiusd_sitesconf();
    $self->generate_radiusd_proxy();
    $self->generate_radiusd_cluster();
    $self->generate_radiusd_dhcpd();
}


=head2 generate_radiusd_sitesconf
Generates the packetfence and packetfence-tunnel configuration file
=cut

sub generate_radiusd_sitesconf {
    my %tags;

    if(isenabled($Config{advanced}{record_accounting_in_sql})){
        $tags{'accounting_sql'} = "sql";
    }
    else {
        $tags{'accounting_sql'} = "# sql not activated because explicitly disabled in pf.conf";
    }

    $tags{'template'}    = "$conf_dir/raddb/sites-enabled/packetfence";
    parse_template( \%tags, "$conf_dir/radiusd/packetfence", "$install_dir/raddb/sites-enabled/packetfence" );

    %tags = ();

    if(isenabled($Config{advanced}{disable_pf_domain_auth})){
        $tags{'multi_domain'} = '# packetfence-multi-domain not activated because explicitly disabled in pf.conf';
    }
    elsif(keys %ConfigDomain){
        $tags{'multi_domain'} = 'packetfence-multi-domain';
    }
    else {
        $tags{'multi_domain'} = '# packetfence-multi-domain not activated because no domains configured';
    }

    $tags{'template'}    = "$conf_dir/raddb/sites-enabled/packetfence-tunnel";
    parse_template( \%tags, "$conf_dir/radiusd/packetfence-tunnel", "$install_dir/raddb/sites-enabled/packetfence-tunnel" );

}


=head2 generate_radiusd_mainconf
Generates the radiusd.conf configuration file
=cut

sub generate_radiusd_mainconf {
    my ($self) = @_;
    my %tags;

    $tags{'template'}    = "$conf_dir/radiusd/radiusd.conf";
    $tags{'install_dir'} = $install_dir;
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'arch'} = `uname -m` eq "x86_64" ? "64" : "";
    $tags{'rpc_pass'} = $Config{webservices}{pass} || "''";
    $tags{'rpc_user'} = $Config{webservices}{user} || "''";
    $tags{'rpc_port'} = $Config{webservices}{aaa_port} || "7070";
    $tags{'rpc_host'} = $Config{webservices}{host} || "127.0.0.1";
    $tags{'rpc_proto'} = $Config{webservices}{proto} || "http";

    parse_template( \%tags, "$conf_dir/radiusd/radiusd.conf", "$install_dir/raddb/radiusd.conf" );
}

sub generate_radiusd_restconf {
    my ($self) = @_;
    my %tags;

    $tags{'template'}    = "$conf_dir/radiusd/rest.conf";
    $tags{'install_dir'} = $install_dir;
    $tags{'rpc_pass'} = $Config{webservices}{pass} || "''";
    $tags{'rpc_user'} = $Config{webservices}{user} || "''";
    $tags{'rpc_port'} = $Config{webservices}{aaa_port} || "7070";
    $tags{'rpc_host'} = $Config{webservices}{host} || "127.0.0.1";
    $tags{'rpc_proto'} = $Config{webservices}{proto} || "http";

    parse_template( \%tags, "$conf_dir/radiusd/rest.conf", "$install_dir/raddb/mods-enabled/rest" );
}

sub generate_radiusd_authconf {
    my ($self) = @_;
    my %tags;
    $tags{'template'}    = "$conf_dir/radiusd/auth.conf";
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'pid_file'} = "$var_dir/run/radiusd.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd.sock";
    parse_template( \%tags, $tags{template}, "$install_dir/raddb/auth.conf" );
}

sub generate_radiusd_acctconf {
    my ($self) = @_;
    my %tags;
    $tags{'template'}    = "$conf_dir/radiusd/acct.conf";
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'pid_file'} = "$var_dir/run/radiusd-acct.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd-acct.sock";
    parse_template( \%tags, $tags{template}, "$install_dir/raddb/acct.conf" );
}


=head2 generate_radiusd_eapconf
Generates the eap.conf configuration file
=cut

sub generate_radiusd_eapconf {
   my %tags;

   $tags{'template'}    = "$conf_dir/radiusd/eap.conf";
   $tags{'install_dir'} = $install_dir;

   parse_template( \%tags, "$conf_dir/radiusd/eap.conf", "$install_dir/raddb/mods-enabled/eap" );
}

=head2 generate_radiusd_sqlconf
Generates the sql.conf configuration file
=cut

sub generate_radiusd_sqlconf {
   my %tags;

   $tags{'template'}    = "$conf_dir/radiusd/sql.conf";
   $tags{'install_dir'} = $install_dir;
   $tags{'db_host'} = $Config{'database'}{'host'};
   $tags{'db_port'} = $Config{'database'}{'port'};
   $tags{'db_database'} = $Config{'database'}{'db'};
   $tags{'db_username'} = $Config{'database'}{'user'};
   $tags{'db_password'} = $Config{'database'}{'pass'};
   $tags{'hash_passwords'} = $Config{'advanced'}{'hash_passwords'} eq 'ntlm' ? 'NT-Password' : 'Cleartext-Password';

   parse_template( \%tags, "$conf_dir/radiusd/sql.conf", "$install_dir/raddb/mods-enabled/sql" );
}

=head2 generate_radiusd_proxy
Generates the proxy.conf.inc configuration file
=cut

sub generate_radiusd_proxy {
    my %tags;

    $tags{'template'} = "$conf_dir/radiusd/proxy.conf.inc";
    $tags{'install_dir'} = $install_dir;
    $tags{'config'} = '';

    foreach my $realm ( sort keys %pf::config::ConfigRealm ) {
        my $options = $pf::config::ConfigRealm{$realm}->{'options'} || '';
        $tags{'config'} .= <<"EOT";
realm $realm {
$options
}
EOT
    }
    parse_template( \%tags, "$conf_dir/radiusd/proxy.conf.inc", "$install_dir/raddb/proxy.conf.inc" );
}

=head2 generate_radiusd_cluster
Generates the load balancer configuration
=cut

sub generate_radiusd_cluster {
    my ($self) = @_;
    my %tags;

    my $int = $management_network->{'Tint'};
    my $cfg = $Config{"interface $int"};

    $tags{'members'} = '';
    $tags{'config'} ='';

    if ($cluster_enabled) {
        $tags{'template'}    = "$conf_dir/radiusd/packetfence-cluster";
        my $cluster_ip = pf::cluster::management_cluster_ip();
        $tags{'virt_ip'} = $cluster_ip;
        my @radius_backend = values %{pf::cluster::members_ips($int)};
        my $i = 0;
        foreach my $radius_back (@radius_backend) {
            next if($radius_back eq $management_network->{Tip} && isdisabled($Config{active_active}{auth_on_management}));
            $tags{'members'} .= <<"EOT";
home_server pf$i.cluster {
        type = auth+acct
        ipaddr = $radius_back
        src_ipaddr = $cluster_ip
        port = 1812
        secret = testing1234
        response_window = 6
        status_check = status-server
        revive_interval = 120
        check_interval = 30
        num_answers_to_alive = 3
}
EOT
            $tags{'home_server'} .= <<"EOT";
        home_server =  pf$i.cluster
EOT
            $i++;
        }
        parse_template( \%tags, "$conf_dir/radiusd/packetfence-cluster", "$install_dir/raddb/sites-enabled/packetfence-cluster" );

        %tags = ();
        $tags{'template'} = "$conf_dir/radiusd/load_balancer.conf";
        $tags{'virt_ip'} = pf::cluster::management_cluster_ip();
        $tags{'pid_file'} = "$var_dir/run/radiusd-load_balancer.pid";
        $tags{'socket_file'} = "$var_dir/run/radiusd-load_balancer.sock";
        parse_template( \%tags, $tags{'template'}, "$install_dir/raddb/load_balancer.conf");
    } else {
        my $file = $install_dir."/raddb/sites-enabled/packetfence-cluster";
        unlink($file);
    }
    $tags{'template'} = "$conf_dir/radiusd/clients.conf.inc";
    my $ip = NetAddr::IP::Lite->new($cfg->{'ip'}, $cfg->{'mask'});
    my $net = $ip->network();
    if ($pf::cluster::cluster_enabled) {
        $tags{'config'} .= <<"EOT";
client $net {
        secret = testing1234
        shortname = pf
}
EOT
    } else {
        $tags{'config'} = '';
    }
    parse_template( \%tags, "$conf_dir/radiusd/clients.conf.inc", "$install_dir/raddb/clients.conf.inc" );
}

sub generate_radiusd_dhcpd {
    my %tags;
    my %direct_subnets;

    freeradius_populate_dhcpd_config();
    $tags{'template'}    = "$conf_dir/radiusd/dhcpd.conf";
    $tags{'management_ip'} = defined($management_network->tag('vip')) ? $management_network->tag('vip') : $management_network->tag('ip');
    $tags{'pid_file'} = "$var_dir/run/radiusd-dhcpd.pid";
    $tags{'socket_file'} = "$var_dir/run/radiusd-dhcpd.sock";

    foreach my $interface ( @listen_ints ) {
        my $cfg = $Config{"interface $interface"};
        next unless $cfg;
        my $enforcement = $cfg->{'enforcement'};
        my $members = pf::cluster::dhcpd_peer($interface);
        my $current_network = NetAddr::IP->new( $cfg->{'ip'}, $cfg->{'mask'} );
            $tags{'listen'} .= <<"EOT";

listen {
	type = dhcp
	ipaddr = 0.0.0.0
	src_ipaddr = $cfg->{'ip'}
	port = 67
	interface = $interface
	broadcast = yes
        virtual_server = dhcp\.$interface
}

EOT

        $tags{'config'} .= <<"EOT";

server dhcp\.$interface {
dhcp DHCP-Discover {
	convert_to_int
	if ("%{expr: %{Tmp-Integer-1} %% 2}" == '1') {

		update reply {
		       DHCP-Message-Type = DHCP-Offer
		}

EOT

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};
        if ( $net{'dhcpd'} eq 'enabled' ) {
            my $ip = NetAddr::IP::Lite->new(clean_ip($net{'gateway'}));
            my $current_network2 = NetAddr::IP->new( $net{'gateway'}, $net{'netmask'} );
            if (defined($net{'next_hop'})) {
                $ip = NetAddr::IP::Lite->new(clean_ip($net{'next_hop'}));
             }

             if ($current_network->contains($ip)) {
                 my $network = $current_network2->network();
                 my $prefix = $current_network2->network()->nprefix();
                 my $mask = $current_network2->masklen();
                 $prefix =~ s/\.$//;
                 if (defined($net{'next_hop'})) {
                     $tags{'config'} .= <<"EOT";
		if ( ( (&request:DHCP-Gateway-IP-Address != 0.0.0.0) && (&request:DHCP-Gateway-IP-Address < $prefix/$mask) ) || (&request:DHCP-Client-IP-Address < $prefix/$mask) ) {
EOT
                 } else {
                     $tags{'config'} .= <<"EOT";
	        if ( (&request:DHCP-Gateway-IP-Address == 0.0.0.0)  || (&request:DHCP-Client-IP-Address < $prefix/$mask) ) {

EOT
                 }
                 $tags{'config'} .= <<"EOT";


			update {
				&reply:DHCP-Domain-Name-Server = $net{'dns'}
				&reply:DHCP-Subnet-Mask = $net{'netmask'}
				&reply:DHCP-Router-Address = $net{'gateway'}
				&reply:DHCP-IP-Address-Lease-Time = "%{%{sql: SELECT lease_time FROM radippool WHERE callingstationid = '%{request:DHCP-Client-Hardware-Address}'}:-$net{'dhcp_default_lease_time'}}"
				&reply:DHCP-DHCP-Server-Identifier = $cfg->{'ip'}
				&reply:DHCP-Domain-Name = $net{'domain-name'}
				&control:Pool-Name := "$network"
				&request:DHCP-Domain-Name-Server = $net{'dns'}
				&request:DHCP-Subnet-Mask = $net{'netmask'}
				&request:DHCP-Router-Address = $net{'gateway'}
				&request:DHCP-IP-Address-Lease-Time = "%{%{sql: SELECT lease_time FROM radippool WHERE callingstationid = '%{request:DHCP-Client-Hardware-Address}'}:-$net{'dhcp_default_lease_time'}}"
				&request:DHCP-DHCP-Server-Identifier = $cfg->{'ip'}
				&request:DHCP-Domain-Name = $net{'domain-name'}
				&request:DHCP-Site-specific-0 = $enforcement
			}
		}
EOT
            }
        }
    }

 $tags{'config'} .= <<"EOT";
	dhcp_sqlippool
        rest-dhcp
	ok
	}
	else {
		reject
	}
}

dhcp DHCP-Request {
        convert_to_int
	if ("%{expr: %{Tmp-Integer-1} %% 2}" == '1') {

		update reply {
		       &DHCP-Message-Type = DHCP-Ack
		}

EOT

    foreach my $network ( keys %ConfigNetworks ) {
        # shorter, more convenient local accessor
        my %net = %{$ConfigNetworks{$network}};
        if ( $net{'dhcpd'} eq 'enabled' ) {
            my $ip = NetAddr::IP::Lite->new(clean_ip($net{'gateway'}));
            my $current_network2 = NetAddr::IP->new( $net{'gateway'}, $net{'netmask'} );
            if (defined($net{'next_hop'})) {
                $ip = NetAddr::IP::Lite->new(clean_ip($net{'next_hop'}));
             }

             if ($current_network->contains($ip)) {
                 my $network = $current_network2->network();
                 my $prefix = $current_network2->network()->nprefix();
                 my $mask = $current_network2->masklen();
                 $prefix =~ s/\.$//;
                 if (defined($net{'next_hop'})) {
                     $tags{'config'} .= <<"EOT";

        if (  ( (&request:DHCP-Gateway-IP-Address != 0.0.0.0) && (&request:DHCP-Gateway-IP-Address < $prefix/$mask) ) || (&request:DHCP-Client-IP-Address < $prefix/$mask) ) {
EOT
                 } else {
                     $tags{'config'} .= <<"EOT";
        if (  (&request:DHCP-Gateway-IP-Address == 0.0.0.0)  || (&request:DHCP-Client-IP-Address < $prefix/$mask) ) {

EOT
                 }
                $tags{'config'} .= <<"EOT";

		update {
			&reply:DHCP-Domain-Name-Server = $net{'dns'}
			&reply:DHCP-Subnet-Mask = $net{'netmask'}
			&reply:DHCP-Router-Address = $net{'gateway'}
			&reply:DHCP-IP-Address-Lease-Time = "%{%{sql: SELECT lease_time FROM radippool WHERE callingstationid = '%{request:DHCP-Client-Hardware-Address}'}:-$net{'dhcp_default_lease_time'}}"
			&reply:DHCP-DHCP-Server-Identifier = $cfg->{'ip'}
			&reply:DHCP-Domain-Name = $net{'domain-name'}
			&control:Pool-Name := "$network"
                        &request:DHCP-Domain-Name-Server = $net{'dns'}
                        &request:DHCP-Subnet-Mask = $net{'netmask'}
                        &request:DHCP-Router-Address = $net{'gateway'}
                        &request:DHCP-IP-Address-Lease-Time = "%{%{sql: SELECT lease_time FROM radippool WHERE callingstationid = '%{request:DHCP-Client-Hardware-Address}'}:-$net{'dhcp_default_lease_time'}}"
                        &request:DHCP-DHCP-Server-Identifier = $cfg->{'ip'}
                        &request:DHCP-Domain-Name = $net{'domain-name'}
                        &request:DHCP-Site-specific-0 = $enforcement
		}
	}

EOT
            }
        }
    }

 $tags{'config'} .= <<"EOT";
	dhcp_sqlippool
	rest-dhcp
	ok
        }
        else {
                reject
        }
}


dhcp DHCP-Decline {
	update reply {
	       &DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}

dhcp DHCP-Inform {
	update reply {
	       &DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}

#
#  For Windows 7 boxes
#
dhcp DHCP-Inform {
	update reply {
		Packet-Dst-Port = 67
		DHCP-Message-Type = DHCP-ACK
		DHCP-DHCP-Server-Identifier = "%{Packet-Dst-IP-Address}"
		DHCP-Site-specific-28 = 0x0a00
	}
	ok
}

dhcp DHCP-Release {
	update reply {
	       &DHCP-Message-Type = DHCP-Do-Not-Respond
	}
	reject
}


dhcp DHCP-Lease-Query {

	# has MAC, asking for IP, etc.
	if (&DHCP-Client-Hardware-Address) {
		# look up MAC in database
	}

	# has IP, asking for MAC, etc.
	elsif (&DHCP-Your-IP-Address) {
		# look up IP in database
	}

	# has host name, asking for IP, MAC, etc.
	elsif (&DHCP-Client-Identifier) {
		# look up identifier in database
	}
	else {
		update reply {
			&DHCP-Message-Type = DHCP-Lease-Unknown
		}

		ok

		# stop processing
		return
	}

	if (notfound) {
		update reply {
			&DHCP-Message-Type = DHCP-Lease-Unknown
		}
		ok
		return
	}

	update reply {
		&DHCP-Message-Type = DHCP-Lease-Unassigned
	}

}

}

EOT
        }


    parse_template( \%tags, "$conf_dir/radiusd/packetfence-dhcp", "$install_dir/raddb/sites-enabled/packetfence-dhcp" );
    parse_template( \%tags, $tags{template}, "$install_dir/raddb/dhcpd.conf" );
    return 1;
}


=head1 AUTHOR

Inverse inc. <info@inverse.ca>


=head1 COPYRIGHT

Copyright (C) 2005-2016 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
USA.

=cut

1;

