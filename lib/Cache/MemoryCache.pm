######################################################################
# $Id: MemoryCache.pm,v 1.19 2001/11/06 23:44:08 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::MemoryCache;


use strict;
use vars qw( @ISA );
use Cache::BaseCache;
use Cache::Cache qw( $EXPIRES_NEVER );
use Cache::CacheUtils qw( Assert_Defined
                          Build_Object
                          Object_Has_Expired
                          Static_Params
                          );
use Cache::Object;
use Carp;

@ISA = qw ( Cache::BaseCache );


my $_Cache_Hash_Ref = { };


##
# Public class methods
##


sub Clear
{
  foreach my $namespace ( _Namespaces( ) )
  {
    _Delete_Namespace( $namespace );
  }
}


sub Purge
{
  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache = new Cache::MemoryCache( { 'namespace' => $namespace } );

    $cache->purge( );
  }
}


sub Size
{
  my $size = 0;

  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache = new Cache::MemoryCache( { 'namespace' => $namespace } );

    $size += $cache->size( );
  }

  return $size;
}


##
# Private class methods
##


sub _Delete_Namespace
{
  my ( $p_namespace ) = Static_Params( @_ );

  delete _Get_Cache_Hash_Ref( )->{ $p_namespace };
}


sub _Namespaces
{
  return keys %{ _Get_Cache_Hash_Ref( ) };
}



##
# Class properties
##

sub _Get_Cache_Hash_Ref
{
  return $_Cache_Hash_Ref;
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


##
# Public instance methods
##


sub clear
{
  my ( $self ) = @_;

  $self->_delete_namespace( $self->get_namespace( ) );
}


sub get
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  $self->_conditionally_auto_purge_on_get( );

  my $object = $self->get_object( $p_key ) or
    return undef;

  if ( Object_Has_Expired( $object ) )
  {
    $self->remove( $p_key );
    return undef;
  }

  return $object->get_data( );
}


sub get_object
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  return $self->_restore( $p_key );
}


sub purge
{
  my ( $self ) = @_;

  foreach my $key ( $self->get_keys( ) )
  {
    $self->get( $key );
  }
}


sub remove
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  delete $self->_get_cache_hash_ref( )
    ->{ $self->get_namespace( ) }
      ->{ $p_key };
}


sub set
{
  my ( $self, $p_key, $p_data, $p_expires_in ) = @_;

  $self->_conditionally_auto_purge_on_set( );

  $self->_store( $p_key,
                 Build_Object( $p_key,
                               $p_data,
                               $self->get_default_expires_in( ),
                               $p_expires_in ) );
}



sub set_object
{
  my ( $self, $p_key, $p_object ) = @_;

  $self->_store( $p_key, $p_object );
}



sub size
{
  my ( $self ) = @_;

  my $size = 0;

  foreach my $key ( $self->get_keys( ) )
  {
    $size += $self->_build_object_size( $key );
  }

  return $size;
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
  Assert_Defined( $p_object );

  $self->_get_cache_hash_ref( )
    ->{ $self->get_namespace( ) }
      ->{ $p_key } = $self->_freeze( $p_object );
}


sub _restore
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  my $object_dump = $self->_get_cache_hash_ref( )
    ->{ $self->get_namespace( ) }
      ->{ $p_key } or
        return undef;

  return $self->_thaw( \$object_dump );
}


sub _delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  _Delete_Namespace( $p_namespace );
}


sub _build_object_size
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  return length $self->_get_cache_hash_ref( )
    ->{ $self->get_namespace( ) }
      ->{ $p_key };
}


##
# Instance properties
##

sub _get_cache_hash_ref
{
  my ( $self ) = @_;

  return _Get_Cache_Hash_Ref( );
}



sub get_keys
{
  my ( $self ) = @_;

  if ( defined $self->_get_cache_hash_ref( )->{ $self->get_namespace( ) } )
  {
    return keys %{ $self->_get_cache_hash_ref( )->{ $self->get_namespace() } };
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

Cache::MemoryCache -- implements the Cache interface.

=head1 DESCRIPTION

The MemoryCache class implements the Cache interface.  This cache
stores data on a per-process basis.  This is the fastest of the cache
implementations, but data can not be shared between processes with the
MemoryCache.

=head1 SYNOPSIS

  use Cache::MemoryCache;

  my %cache_options_= ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600 );

  my $memory_cache = new Cache::MemoryCache( \%cache_options ) or
    croak( "Couldn't instantiate MemoryCache" );

=head1 METHODS

=over 4

=item B<Clear( )>

See Cache::Cache

=item B<Purge( )>

See Cache::Cache

=item B<Size( )>

See Cache::Cache

=item B<new( $options_hash_ref )>

Constructs a new MemoryCache.

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

Cache::Cache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
