######################################################################
# $Id: Cache.pm,v 1.9 2001/03/22 21:44:40 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::Cache;


use strict;
use vars qw( @ISA
             @EXPORT_OK
             $VERSION
             $EXPIRES_NOW
             $EXPIRES_NEVER
             $TRUE
             $FALSE
             $SUCCESS
             $FAILURE );
use Exporter;


@ISA = qw( Exporter );


@EXPORT_OK = qw( $VERSION
                 $EXPIRES_NOW
                 $EXPIRES_NEVER
                 $TRUE
                 $FALSE
                 $SUCCESS
                 $FAILURE );


use vars @EXPORT_OK;


$VERSION = 0.05;
$EXPIRES_NOW = 'now';
$EXPIRES_NEVER = 'never';
$TRUE = 1;
$FALSE = 0;
$SUCCESS = 1;
$FAILURE = 0;



##
# Public class methods
##


sub Clear;


sub Purge;


sub Size;


##
# Constructor
##


sub new;


##
# Public instance methods
##


sub clear;


sub get;


sub get_object;


sub purge;


sub remove;


sub set;


sub size;


##
# Properties
##


sub get_default_expires_in;


sub get_namespace;


sub get_identifiers;


1;


__END__


=pod

=head1 NAME

Cache::Cache -- the Cache interface.

=head1 DESCRIPTION

The Cache interface is implemented by classes that support the get,
set, remove, size, purge, and clear instance methods and their
corresponding static methods for persisting data across method calls.

=head1 SYNOPSIS

  use Cache::Cache;
  use vars qw( @ISA );

  @ISA = qw( Cache::Cache );


=head1 CONSTANTS

=over 4

=item $SUCCESS

Typically returned from a subroutine, this value is synonymous with 1
and can be used as the typical perl "boolean" for true

=item $FAILURE

Typically returned from a subroutine, this value is synonymous with 0
and can be used as the typical perl "boolean" for false

=item $EXPIRES_NEVER

The item being set in the cache will never expire.

=item $EXPIRES_NOW

The item being set in the cache will expire immediately.

=item $EXPIRES_NEVER

The item being set in the cache will never expire.

=back

=head1 METHODS

=over 4

=item B<Clear( )>

Remove all objects from all caches of this type.

=item Returns

Either $SUCCESS or $FAILURE

=item B<Purge( )>

Remove all objects that have expired from all caches of this type.

=item Returns

Either $SUCCESS or $FAILURE

=item B<Size( $optional_namespace )>

Calculate the total size of all objects in all caches of this type.

=item Returns

The total size of all the objects in all caches of this type.

=item B<new( $options_hash_ref )>

Construct a new instance of a Cache::Cache

=item C<$options_hash_ref>

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=item B<clear(  )>

Remove all objects from the namespace associated with this cache instance.

=item Returns

Either $SUCCESS or $FAILURE

=item B<get( $identifier )>

Fetch the data specified.

=item C<$identifier>

A string uniquely identifying the data.

=item Returns

The data specified.

=item B<get_object( $identifier )>

Fetch the underlying Cache::Object object that is used to store the
cached data.  This will not trigger a removal of the cached object
even if the object has expired.

=item C<$identifier>

A string uniquely identifying the data.

=item Returns

The underlying Cache::Object object, which may or may not have expired.

=item B<purge(  )>

Remove all objects that have expired from the namespace associated
with this cache instance.

=item Returns

Either $SUCCESS or $FAILURE

=item B<remove( $identifier )>

Delete the data associated with the $identifier from the cache.

=item C<$identifier>

A string uniquely identifying the data.

=item Returns

Either $SUCCESS or $FAILURE

=item B<set( $identifier, $data, $expires_in )>

=item C<$identifier>

A string uniquely identifying the data.

=item C<$data>

A scalar or reference to the object to be stored.

=item C<$expires_in>

Either the time in seconds until this data should be erased, or the
constant $EXPIRES_NOW, or the constant $EXPIRES_NEVER.  Defaults to
$EXPIRES_NEVER.  This variable can also be in the extended format of
"[number] [unit]", e.g., "10 minutes".  The valid units are s, second,
seconds, sec, m, minute, minutes, min, h, hour, hours, w, week, weeks,
M, month, months, y, year, and years.  Additionally, $EXPIRES_NOW can
be represented as "now" and $EXPIRES_NEVER can be represented as
"never".

=item Returns

Either $SUCCESS or $FAILURE

=item B<size(  )>

Calculate the total size of all objects in the namespace associated with
this cache instance.

=item Returns

The total size of all objects in the namespace associated with this
cache instance.

=back

=head1 OPTIONS

The options are set by passing in a reference to a hash containing any
of the following keys:

=over 4

=item namespace

The namespace associated with this cache.  Defaults to "Default" if
not explicitly set.

=item default_expires_in

The default expiration time for objects place in the cache.  Defaults
to $EXPIRES_NEVER if not explicitly set.

=back

=head1 PROPERTIES

=over 4

=item B<get_namespace( )>

The namespace of this cache instance

=item B<get_default_expires_in( )>

The default expiration time for objects placed in this cache instance

=item B<get_identifiers( )>

The list of identifiers specifying objects in the namespace associated
with this cache instance

=back

=head1 SEE ALSO

Cache::Object, Cache::MemoryCache, Cache::FileCache,
Cache::SharedMemoryCache, and Cache::SizeAwareFileCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
