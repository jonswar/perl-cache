######################################################################
# $Id: SizeAwareSharedMemoryCache.pm,v 1.14 2001/11/05 13:34:45 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SizeAwareSharedMemoryCache;


use strict;
use vars qw( @ISA @EXPORT_OK $NO_MAX_SIZE );
use Cache::Cache qw( $EXPIRES_NEVER );
use Cache::CacheUtils qw( Assert_Defined
                          Static_Params );
use Cache::SharedCacheUtils qw( Restore_Shared_Hash_Ref
                                Restore_Shared_Hash_Ref_With_Lock
                                Store_Shared_Hash_Ref
                                Store_Shared_Hash_Ref_And_Unlock );
use Cache::SizeAwareMemoryCache;
use Cache::SharedMemoryCache;
use Exporter;


@ISA = qw ( Cache::SizeAwareMemoryCache Exporter );
@EXPORT_OK = qw( $NO_MAX_SIZE );


$NO_MAX_SIZE = $Cache::SizeAwareMemoryCache::NO_MAX_SIZE;


my $IPC_IDENTIFIER = 'ipcc';


##
# Public class methods
##


sub Clear
{
  return Cache::SharedMemoryCache::Clear( );
}


sub Purge
{
  return Cache::SharedMemoryCache::Purge( );
}


sub Size
{
  return Cache::SharedMemoryCache::Size( );
}



##
# Private class methods
##




sub _Restore_Cache_Hash_Ref
{
  return Cache::SharedMemoryCache::_Restore_Cache_Hash_Ref( @_ );
}


sub _Restore_Cache_Hash_Ref_With_Lock
{
  return Cache::SharedMemoryCache::_Restore_Cache_Hash_Ref_With_Lock( @_ );
}


sub _Store_Cache_Hash_Ref
{
  return Cache::SharedMemoryCache::_Store_Cache_Hash_Ref( @_ );
}


sub _Store_Cache_Hash_Ref_And_Unlock
{
  return Cache::SharedMemoryCache::_Store_Cache_Hash_Ref_And_Unlock( @_ );
}


sub _Delete_Namespace
{
  return Cache::SharedMemoryCache::_Delete_Namespace( @_ );
}


sub _Namespaces
{
  return Cache::SharedMemoryCache::_Namespaces( @_ );
}


##
# Constructor
##



sub new
{
  my ( $self ) = _new( @_ );

  $self->_complete_initialization( );

  return $self;
}



sub remove
{
  my ( $self, $p_identifier ) = @_;

  Assert_Defined( $p_identifier );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref( );

  delete $cache_hash_ref->{ $self->get_namespace( ) }->{ $p_identifier };

  _Store_Cache_Hash_Ref( $cache_hash_ref );
}


##
# Private instance methods
##



sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  return $class->SUPER::_new( $p_options_hash_ref );
}



sub _build_object_size
{
  my ( $self, $p_identifier ) = @_;

  Assert_Defined( $p_identifier );

  my $object_dump =
    _Restore_Cache_Hash_Ref( )
      ->{ $self->get_namespace( ) }
        ->{ $p_identifier } or
          return 0;

  return length $object_dump;
}


sub _store
{
  my ( $self, $p_identifier, $p_object ) = @_;

  Assert_Defined( $p_identifier );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref_With_Lock( );

  $cache_hash_ref->{ $self->get_namespace( ) }->{ $p_identifier } =
    $self->_freeze( $p_object );

  _Store_Cache_Hash_Ref( $cache_hash_ref );
}


sub _restore
{
  my ( $self, $p_identifier ) = @_;

  Assert_Defined( $p_identifier );

  my $object_dump = _Restore_Cache_Hash_Ref( )
    ->{ $self->get_namespace( ) }
      ->{ $p_identifier } or
        return undef;

  return $self->_thaw( \$object_dump );
}


sub _delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  _Delete_Namespace( $p_namespace ) or
    croak( "Couldn't delete namespace $p_namespace" );
}


##
# Instance properties
##


sub get_identifiers
{
  my ( $self ) = @_;

  if ( defined _Restore_Cache_Hash_Ref( )->{ $self->get_namespace( ) } )
  {
    return keys %{ _Restore_Cache_Hash_Ref( )->{ $self->get_namespace( ) } };
  }
  else
  {
    return ( );
  }
}



1;


__END__

=pod

=head1 NAME

Cache::SizeAwareSharedMemoryCache -- extends the Cache::SizeAwareMemoryCache module

=head1 DESCRIPTION

The SizeAwareSharedMemoryCache extends the SizeAwareMemoryCache class
and binds the data store to shared memory so that separate process can
use the same cache.

=head1 SYNOPSIS

  use Cache::SizeAwareSharedMemoryCache;

  my %cache_options = ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600,
                        'max_size' => 10000 );

  my $size_aware_shared_memory_cache =
    new Cache::SizeAwareSharedMemoryCache( \%cache_options ) or
      croak( "Couldn't instantiate SizeAwareSharedMemoryCache" );

=head1 METHODS

=over 4

=item B<Clear( )>

See Cache::Cache

=item B<Purge( )>

See Cache::Cache

=item B<Size( )>

See Cache::Cache

=item B<new( $options_hash_ref )>

Constructs a new SizeAwareMemoryCache

=over 4

=item $options_hash_ref

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=back

=item B<clear(  )>

See Cache::Cache

=item B<get( $identifier )>

See Cache::Cache

=item B<get_object( $identifier )>

See Cache::Cache

=item B<limit_size( $new_size )>

See Cache::SizeAwareMemoryCache

=item B<purge( )>

See Cache::Cache

=item B<remove( $identifier )>

See Cache::Cache

=item B<set( $identifier, $data, $expires_in )>

See Cache::Cache

=item B<size(  )>

See Cache::Cache

=back

=head1 OPTIONS

See Cache::Cache for standard options.  See Cache::SizeAwareMemory cache
for other options.

=head1 PROPERTIES

See Cache::Cache and Cache::SizeAwareMemoryCache for default
properties.

=head1 SEE ALSO

Cache::Cache, Cache::MemoryCache, Cache::SizeAwareMemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
