######################################################################
# $Id: Cache.pm,v 1.7 2001/03/10 18:30:42 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SizeAwareCache;


use strict;
use Cache::Cache;
use vars qw( @ISA
             @EXPORT_OK
             $VERSION
             $EXPIRES_NOW
             $EXPIRES_NEVER
             $TRUE
             $FALSE
             $SUCCESS
             $FAILURE
             $NO_MAX_SIZE );
use Exporter;


@ISA = qw( Cache::Cache Exporter );

@EXPORT_OK = qw( $VERSION
                 $EXPIRES_NOW
                 $EXPIRES_NEVER
                 $TRUE
                 $FALSE
                 $SUCCESS
                 $FAILURE
                 $NO_MAX_SIZE );


use vars @EXPORT_OK;


$VERSION = $Cache::Cache::VERSION;
$EXPIRES_NOW = $Cache::Cache::EXPIRES_NOW;
$EXPIRES_NEVER = $Cache::Cache::EXPIRES_NEVER;
$TRUE = $Cache::Cache::TRUE;
$FALSE = $Cache::Cache::FALSE;
$SUCCESS = $Cache::Cache::SUCCESS;
$FAILURE = $Cache::Cache::FAILURE;
$NO_MAX_SIZE = -1;


##
# Public instance methods
##


sub limit_size;


##
# Properties
##


sub get_max_size;


sub set_max_size;


1;


__END__


=pod

=head1 NAME

Cache::SizeAwareCache -- extends the Cache interface.

=head1 DESCRIPTION

The SizeAwareCache interface is implemented by classes that support
all of the Cache::Cache interface in addition to the limit_size and
max_size features of a size aware cache.


=head1 SYNOPSIS

  use Cache::SizeAwareCache;
  use vars qw( @ISA );

  @ISA = qw( Cache::SizeAwareCache );


=head1 CONSTANTS

Please see Cache::Cache for standard constants

=over 4

=item $NO_MAX_SIZE

The cache has no size restrictions

=back

=head1 METHODS

Please see Cache::Cache for standard methods

=over 4

=item B<limit_size( $new_size )>

Attempt to resize the cache such that the total disk usage is under
the 'new_size' parameter.

=item C<$new_size>

The size (in bytes) that the cache should be limited to.  This is
only a one time adjustment.  To maintain the cache size, consider using
the 'max_size' option, although it is considered very expensive.

=item Returns

Either $SUCCESS or $FAILURE

=back

=head1 OPTIONS

Please see Cache::Cache for standard options

=over 4

=item max_size

Sets the max_size property, which is described in detail below.
Defaults to $NO_MAX_SIZE.

=back

=head1 PROPERTIES

Please see Cache::Cache for standard properties

=over 4

=item B<(get|set)_max_size>

If this property is set, then the cache will try not to exceed the max
size value specified.  NOTE: This causes the size of the cache to be
checked on every set, and can be considered *very* expensive in some
implementations.  A good alternative approach is leave max_size as
$NO_MAX_SIZE and to periodically limit the size of the cache by
calling the limit_size( $size ) method.

=back

=head1 SEE ALSO

Cache::Cache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
