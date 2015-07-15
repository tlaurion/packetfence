package pfappserver::Form::Config::Authentication::Source::Billing;

=head1 NAME

pfappserver::Form::Config::Authentication::Source::Billing;

=cut

=head1 DESCRIPTION

pfappserver::Form::Authentication::Source::Billing

=cut

use strict;
use warnings;
use HTML::FormHandler::Moose;
extends 'pfappserver::Form::Config::Authentication::Source';

has_field currency => (
    type => 'Text',
    default => 'USD',
);

has_field 'create_local_account' => (
    type => 'Toggle',
    checkbox_value => 'yes',
    unchecked_value => 'no',
    label => 'Create Local Account',
    default => pf::Authentication::Source::BillingSource->meta->get_attribute('create_local_account')->default,
    tags => {
        after_element => \&help,
        help => 'Create a local account on the PacketFence system based on the account email address provided.',
    },
);

has_field test_mode => (
    type => 'Checkbox',
    checkbox_value => '1',
    unchecked_value => '0',
    default => 1,
);


# Form fields

=head1 AUTHOR

Inverse inc. <info@inverse.ca>

=head1 COPYRIGHT

Copyright (C) 2005-2013 Inverse inc.

=head1 LICENSE

This program is free software; you can redistribute it and::or
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