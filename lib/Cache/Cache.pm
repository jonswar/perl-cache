######################################################################
# $Id: Cache.pm,v 1.14 2001/04/08 22:48:37 dclinton Exp $
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


$VERSION = 0.07;
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


sub set_object;


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

To implement the Cache::Cache interface:

  package Cache::MyCache;

  use Cache::Cache;
  use vars qw( @ISA );

  @ISA = qw( Cache::Cache );

  sub get
  {
    my ( $self, $identifier ) = @_;

    # implement the get method here
  }

  sub set
  {
    my ( $self, $identifier, $data, $expires_in ) = @_;

    # implement the set method here
  }

  # implement the other interface methods here


To use a Cache implementation, such as Cache::MemoryCache:


  use Cache::Cache qw( $EXPIRES_NEVER $EXPIRES_NOW );
  use Cache::MemoryCache;

  my $options_hash_ref = { 'default_expires_in' => '10 seconds' };

  my $cache = new Cache::MemoryCache( $options_hash_ref );

  my $expires_in = '10 minutes';

  $cache->set( 'Key', 'Value', $expires_in );

  # if the next line is called within 10 minutes, then this 
  # will return the cache value

  my $value = $cache->get( 'Key' );


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

=over 4

=item Returns

Either $SUCCESS or $FAILURE.

=back

=item B<Purge( )>

Remove all objects that have expired from all caches of this type.

=over 4

=item Returns

Either $SUCCESS or $FAILURE.

=back

=item B<Size( $optional_namespace )>

Calculate the total size of all objects in all caches of this type.

=over 4

=item Returns

The total size of all the objects in all caches of this type.

=back

=item B<new( $options_hash_ref )>

Construct a new instance of a Cache::Cache

=over 4

=item $options_hash_ref

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=back

=item B<clear(  )>

Remove all objects from the namespace associated with this cache instance.

=over 4

=item Returns

Either $SUCCESS or $FAILURE.

=back

=item B<get( $identifier )>

Fetch the data specified.

=over 4

=item $identifier

A string uniquely identifying the data.

=item Returns

The data specified.

=back

=item B<get_object( $identifier )>

Fetch the underlying Cache::Object object that is used to store the
cached data.  This will not trigger a removal of the cached object
even if the object has expired.

=over 4

=item $identifier

A string uniquely identifying the data.

=item Returns

The underlying Cache::Object object, which may or may not have expired.

=back

=item B<set_object( $identifier, $object )>

Stores the underlying Cache::Object object that is to be cached.  Using
set_object (as opposed to set) does not trigger an automatic purge.

=over 4

=item $identifier

A string uniquely identifying the data.

=item $object

The underlying Cache::Object object to be stored.

=item Returns

Either $SUCCESS or $FAILURE.

=back

=item B<purge(  )>

Remove all objects that have expired from the namespace associated
with this cache instance.

=over 4

=item Returns

Either $SUCCESS or $FAILURE.

=back

=item B<remove( $identifier )>

Delete the data associated with the $identifier from the cache.

=over 4

=item $identifier

A string uniquely identifying the data.

=item Returns

Either $SUCCESS or $FAILURE.

=back

=item B<set( $identifier, $data, $expires_in )>

Store an item in the cache

=over 4

=item $identifier

A string uniquely identifying the data.

=item $data

A scalar or reference to the object to be stored.

=item $expires_in

Either the time in seconds until this data should be erased, or the
constant $EXPIRES_NOW, or the constant $EXPIRES_NEVER.  Defaults to
$EXPIRES_NEVER.  This variable can also be in the extended format of
"[number] [unit]", e.g., "10 minutes".  The valid units are s, second,
seconds, sec, m, minute, minutes, min, h, hour, hours, w, week, weeks,
M, month, months, y, year, and years.  Additionally, $EXPIRES_NOW can
be represented as "now" and $EXPIRES_NEVER can be represented as
"never".

=item Returns

Either $SUCCESS or $FAILURE.

=back

=item B<size(  )>

Calculate the total size of all objects in the namespace associated with
this cache instance.

=over 4

=item Returns

The total size of all objects in the namespace associated with this
cache instance.

=back

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

=item auto_purge

Sets the auto purge interval.  If this option is set to a particular
time ( in the same format as the expires_in ), then the purge( )
routine will be called during the first set after the interval
expires.  The interval will then be reset.


=back

=head1 PROPERTIES

=over 4

=item B<(get|set)_namespace( )>

The namespace of this cache instance

=item B<get_default_expires_in( )>

The default expiration time for objects placed in this cache instance

=item B<get_identifiers( )>

The list of identifiers specifying objects in the namespace associated
with this cache instance

=item B<(get|set)_auto_purge( )>

Accesses the auto purge interval.  If this option is set to a particular
time ( in the same format as the expires_in ), then the purge( )
routine will be called during the first get after the interval
expires.  The interval will then be reset.

=back

=head1 SEE ALSO

Cache::Object, Cache::MemoryCache, Cache::FileCache,
Cache::SharedMemoryCache, and Cache::SizeAwareFileCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
