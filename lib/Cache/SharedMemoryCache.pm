######################################################################
# $Id: SharedMemoryCache.pm,v 1.15 2001/11/06 23:44:08 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SharedMemoryCache;


use strict;
use vars qw( @ISA );
use Cache::Cache;
use Cache::MemoryCache;
use Cache::CacheUtils qw( Assert_Defined
                          Static_Params );
use Cache::SharedCacheUtils qw( Restore_Shared_Hash_Ref
                                Restore_Shared_Hash_Ref_With_Lock
                                Store_Shared_Hash_Ref
                                Store_Shared_Hash_Ref_And_Unlock );
use Error;


@ISA = qw ( Cache::MemoryCache );


my $IPC_IDENTIFIER = 'ipcc';


##
# Public class methods
##


sub Clear
{
  my $empty_cache_hash_ref = { };

  _Store_Cache_Hash_Ref( $empty_cache_hash_ref );
}


sub Purge
{
  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache = new Cache::SharedMemoryCache( { 'namespace' => $namespace } );
    $cache->purge( );
  }
}


sub Size
{
  my $size = 0;

  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache = new Cache::SharedMemoryCache( { 'namespace' => $namespace } );
    $size += $cache->size( );
  }

  return $size;
}



##
# Private class methods
##


sub _Restore_Cache_Hash_Ref
{
  return Restore_Shared_Hash_Ref( $IPC_IDENTIFIER );
}


sub _Restore_Cache_Hash_Ref_With_Lock
{
  return Restore_Shared_Hash_Ref_With_Lock( $IPC_IDENTIFIER );
}


sub _Store_Cache_Hash_Ref
{
  my ( $cache_hash_ref ) = Static_Params( @_ );

  return Store_Shared_Hash_Ref( $IPC_IDENTIFIER, $cache_hash_ref );
}


sub _Store_Cache_Hash_Ref_And_Unlock
{
  my ( $cache_hash_ref ) = Static_Params( @_ );

  return Store_Shared_Hash_Ref_And_Unlock( $IPC_IDENTIFIER, $cache_hash_ref );
}


sub _Delete_Namespace
{
  my ( $p_namespace ) = Static_Params( @_ );

  Assert_Defined( $p_namespace );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref_With_Lock( );

  delete $cache_hash_ref->{ $p_namespace };

  _Store_Cache_Hash_Ref_And_Unlock( $cache_hash_ref );
}


sub _Namespaces
{
  return keys %{ _Restore_Cache_Hash_Ref( ) };
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
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref_With_Lock( );

  delete $cache_hash_ref->{ $self->get_namespace( ) }->{ $p_key };

  _Store_Cache_Hash_Ref_And_Unlock( $cache_hash_ref );
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


sub _store
{
  my ( $self, $p_key, $p_object ) = @_;

  Assert_Defined( $p_key );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref_With_Lock( );

  $cache_hash_ref->{ $self->get_namespace( ) }->{ $p_key } =
    $self->_freeze( $p_object );

  _Store_Cache_Hash_Ref_And_Unlock( $cache_hash_ref );
}


sub _restore
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  my $object_dump = _Restore_Cache_Hash_Ref( )
    ->{ $self->get_namespace( ) }
      ->{ $p_key } or
        return undef;

  return $self->_thaw( \$object_dump );
}



sub _build_object_size
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  return length _Restore_Cache_Hash_Ref( )
    ->{ $self->get_namespace( ) }
      ->{ $p_key };
}


sub _delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  _Delete_Namespace( $p_namespace );
}


##
# Instance properties
##


sub get_keys
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



=pod

=head1 NAME

Cache::SharedMemoryCache -- extends the MemoryCache.

=head1 DESCRIPTION

The SharedMemoryCache extends the MemoryCache class and binds the data
store to shared memory so that separate process can use the same
cache.

=head1 SYNOPSIS

  use Cache::SharedMemoryCache;

  my %cache_options_= ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600 );

  my $shared_memory_cache = 
    new Cache::SharedMemoryCache( \%cache_options ) or
      croak( "Couldn't instantiate SharedMemoryCache" );

=head1 METHODS

=over 4

=item B<Clear( )>

See Cache::Cache

=item B<Purge( )>

See Cache::Cache

=item B<Size( )>

See Cache::Cache

=item B<new( $options_hash_ref )>

Constructs a new SharedMemoryCache.

=over 4

=item $options_hash_ref

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=back

=item B<clear(  )>

See Cache::Cache

=item B<get( $key )>

See Cache::Cache

=item B<get_object( $key )>

See Cache::Cache

=item B<purge( )>

See Cache::Cache

=item B<remove( $key )>

See Cache::Cache

=item B<set( $key, $data, $expires_in )>

See Cache::Cache

=item B<size(  )>

See Cache::Cache

=back

=head1 OPTIONS

See Cache::Cache for standard options.

=head1 PROPERTIES

See Cache::Cache for default properties.

=head1 SEE ALSO

Cache::Cache, Cache::MemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
