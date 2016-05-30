package pfconfig::namespaces::config::Pf;

=head1 NAME

pfconfig::namespaces::config::Pf

=cut

=head1 DESCRIPTION

pfconfig::namespaces::config::Pf

This module creates the configuration hash associated to pf.conf

=cut

use strict;
use warnings;

use JSON::MaybeXS;
use pfconfig::namespaces::config;
use Config::IniFiles;
use File::Slurp qw(read_file);
use pf::log;
use pf::file_paths qw(
    $pf_default_file
    $pf_config_file
    $log_dir
);
use pf::util;
use List::MoreUtils qw(uniq);

use base 'pfconfig::namespaces::config';

# need to override it since it imports data from pf.conf.defaults
sub build {
    my ($self) = @_;

    my %tmp_cfg;

    my $pf_conf_defaults = Config::IniFiles->new( -file => $pf_default_file );

    tie %tmp_cfg, 'Config::IniFiles', ( -file => $self->{file}, -import => $pf_conf_defaults );

    # for pfcmd checkup
    $self->{_file_cfg} = {%tmp_cfg};

    @{ $self->{ordered_sections} } = keys %tmp_cfg;

    my $json = encode_json( \%tmp_cfg );
    my $cfg  = decode_json($json);

    $self->unarray_parameters($cfg);

    $self->{cfg} = $cfg;

    my $child_resource = $self->build_child();
    $self->{cfg} = $child_resource;
    return $child_resource;
}

sub init {
    my ($self, $host_id) = @_;
    $self->{file}            = $pf_config_file;
    $self->{default_config}  = $self->{cache}->get_cache('config::PfDefault');
    $self->{doc_config}      = $self->{cache}->get_cache('config::Documentation');
    $self->{cluster_config}  = $self->{cache}->get_cache('config::Cluster');

    $self->{child_resources} = [ 'resource::CaptivePortal', 'resource::Database', 'resource::fqdn', 'config::Pfdetect', 'resource::trapping_range', 'resource::stats_levels' ];
    if(defined($host_id)){
        push @{$self->{child_resources}}, "interfaces($host_id)";
    }
    else{
        push @{$self->{child_resources}}, "interfaces";
    }
    $self->{host_id} = $host_id;
}

sub build_child {
    my ($self) = @_;
    my $logger = get_logger;

    my %Config         = %{ $self->{cfg} };
    my %Doc_Config     = %{ $self->{doc_config} };
    my %Default_Config = %{ $self->{default_config} };
    my %ConfigCluster  = %{ $self->{cluster_config} };

    # for cluster overlaying
    if(defined($self->{host_id}) && exists($ConfigCluster{$self->{host_id}})){
        $logger->debug("Doing the cluster overlaying for host $self->{host_id}");
        while(my ($key, $config) = (each %{$ConfigCluster{$self->{host_id}}})){
            if($key =~ /^interface /){
                $logger->debug("Reconfiguring interface $key with cluster information");
                $Config{$key} = $config;
            }
        }
    }
    elsif(defined($self->{host_id})){
        $logger->warn("A host was defined for the config::Pf namespace but no cluster configuration was found. This is not a big issue but it's worth noting.")
    }

    my @time_values = grep { my $t = $Doc_Config{$_}{type}; defined $t && $t eq 'time' } keys %Doc_Config;

    # normalize time
    foreach my $val (@time_values) {
        my ( $group, $item ) = split( /\./, $val );
        $Config{$group}{$item} = normalize_time( $Config{$group}{$item} ) if ( $Config{$group}{$item} );
    }

    # determine absolute paths
    foreach my $val ("alerting.log") {
        my ( $group, $item ) = split( /\./, $val );
        if ( !File::Spec->file_name_is_absolute( $Config{$group}{$item} ) ) {
            $Config{$group}{$item} = File::Spec->catfile( $log_dir, $Config{$group}{$item} );
        }
    }

    $Config{trapping}{passthroughs} = [ split( /\s*,\s*/, $Config{trapping}{passthroughs} || '' ) ];

    # We're looking for the merged_list configurations and we merge the default value with
    # the user defined value
    while( my( $key, $value ) = each %Doc_Config ){
        if(defined($value->{type}) && $value->{type} eq "merged_list"){
            my ($category, $attribute) = split /\./, $key;
            my $additionnal = $Config{$category}{$attribute} || '';
            $Config{$category}{$attribute} = [ split( /\s*,\s*/, $Default_Config{$category}{$attribute}), split( /\s*,\s*/, $additionnal ) ];
            $Config{$category}{$attribute} = [ uniq @{$Config{$category}{$attribute}} ];
        }
    }

    $Config{network}{dhcp_filter_by_message_types}
        = [ split( /\s*,\s*/, $Config{network}{dhcp_filter_by_message_types} || '' ) ];

    return \%Config;

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

# vim: set shiftwidth=4:
# vim: set expandtab:
# vim: set backspace=indent,eol,start:

