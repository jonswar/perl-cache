#####################################################################
# $Id: Cache.pm,v 1.21 2001/11/07 13:10:56 dclinton Exp $
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
             $EXPIRES_NEVER );
use Exporter;


@ISA = qw( Exporter );


@EXPORT_OK = qw( $VERSION
                 $EXPIRES_NOW
                 $EXPIRES_NEVER );


use vars @EXPORT_OK;


$VERSION = 1.00;
$EXPIRES_NOW = 'now';
$EXPIRES_NEVER = 'never';

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

sub set_namespace;

sub get_keys;

sub get_auto_purge_interval;

sub set_auto_purge_interval;

sub get_auto_purge_interval;

sub set_auto_purge_interval;

sub get_auto_purge_on_set;

sub set_auto_purge_on_set;

sub get_auto_purge_on_get;

sub set_auto_purge_on_get;

sub get_identifiers;  # deprecated


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
    my ( $self, $key ) = @_;

    # implement the get method here
  }

  sub set
  {
    my ( $self, $key, $data, $expires_in ) = @_;

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

=over

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

=back

=head1 METHODS

=over

=item B<Clear( )>

Remove all objects from all caches of this type. Returns either $SUCCESS or $FAILURE.

=item B<Purge( )>

Remove all objects that have expired from all caches of this type. Returns either $SUCCESS or $FAILURE.

=item B<Size( $optional_namespace )>

Returns the total size of all objects in all caches of this type.

=item B<new( $options_hash_ref )>

Construct a new instance of a Cache::Cache. I<$options_hash_ref> is a
reference to a hash containing configuration options; see the section
OPTIONS below.

=item B<clear(  )>

Remove all objects from the namespace associated with this cache instance. Returns either $SUCCESS or $FAILURE.

=item B<get( $key )>

Returns the data associated with I<$key>.

=item B<get_object( $key )>

Returns the underlying Cache::Object object used to store the cached
data associated with I<$key>.  This will not trigger a removal
of the cached object even if the object has expired.

=item B<set_object( $key, $object )>

Associates I<$key> with Cache::Object I<$object>.  Using
_object (as opposed to set) does not trigger an automatic purge.
Returns either $SUCCESS or $FAILURE.

=item B<purge(  )>

Remove all objects that have expired from the namespace associated
with this cache instance. Returns either $SUCCESS or $FAILURE.

=item B<remove( $key )>

Delete the data associated with the I<$key> from the cache.
Returns either $SUCCESS or $FAILURE.

=item B<set( $key, $data, [$expires_in] )>

Associates I<$data> with I<$key> in the cache. I<$expires_in>
indicates the time in seconds until this data should be erased, or the
constant $EXPIRES_NOW, or the constant $EXPIRES_NEVER.  Defaults to
$EXPIRES_NEVER.  This variable can also be in the extended format of
"[number] [unit]", e.g., "10 minutes".  The valid units are s, second,
seconds, sec, m, minute, minutes, min, h, hour, hours, w, week, weeks,
M, month, months, y, year, and years.  Additionally, $EXPIRES_NOW can
be represented as "now" and $EXPIRES_NEVER can be represented as
"never". Returns either $SUCCESS or $FAILURE.

=item B<size(  )>

Returns the total size of all objects in the namespace associated with
this cache instance.

=back

=head1 OPTIONS

The options are set by passing in a reference to a hash containing any
of the following keys:

=over

=item namespace

The namespace associated with this cache.  Defaults to "Default" if
not explicitly set.

=item default_expires_in

The default expiration time for objects place in the cache.  Defaults
to $EXPIRES_NEVER if not explicitly set.

=item auto_purge_interval

Sets the auto purge interval.  If this option is set to a particular
time ( in the same format as the expires_in ), then the purge( )
routine will be called during the first set after the interval
expires.  The interval will then be reset.

=item auto_purge_on_set

If this option is true, then the auto purge interval routine will be
checked on every set.

=item auto_purge_on_get

If this option is true, then the auto purge interval routine will be
checked on every get.

=back

=head1 PROPERTIES

=over

=item B<(get|set)_namespace( )>

The namespace of this cache instance

=item B<get_default_expires_in( )>

The default expiration time for objects placed in this cache instance

=item B<get_keys( )>

The list of keys specifying objects in the namespace associated
with this cache instance

=item B<(get|set)_auto_purge_interval( )>

Accesses the auto purge interval.  If this option is set to a particular
time ( in the same format as the expires_in ), then the purge( )
routine will be called during the first get after the interval
expires.  The interval will then be reset.

=item B<(get|set)_auto_purge_on_set( )>

If this property is true, then the auto purge interval routine will be
checked on every set.

=item B<(get|set)_auto_purge_on_get( )>

If this property is true, then the auto purge interval routine will be
checked on every get.

=back

=head1 SEE ALSO

Cache::Object, Cache::MemoryCache, Cache::FileCache,
Cache::SharedMemoryCache, and Cache::SizeAwareFileCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
