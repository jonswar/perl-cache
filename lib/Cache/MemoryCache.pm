######################################################################
# $Id: MemoryCache.pm,v 1.21 2001/11/08 23:01:23 dclinton Exp $
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
                          Static_Params );
use Cache::MemoryBackend;
use Cache::Object;
use Carp;

@ISA = qw ( Cache::BaseCache );


##
# Public class methods
##


sub Clear
{
  foreach my $namespace ( _Namespaces( ) )
  {
    _Get_Backend( )->delete_namespace( $namespace );
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


sub _Get_Backend
{
  return new Cache::MemoryBackend( );
}

sub _Namespaces
{
  return _Get_Backend( )->get_namespaces( );
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

  $self->_get_backend( )->delete_namespace( $self->get_namespace( ) );
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

  return $self->_get_backend( )->restore( $self->get_namespace( ), $p_key );
}


sub remove
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  $self->_get_backend( )->delete_key( $self->get_namespace( ), $p_key );
}


sub set
{
  my ( $self, $p_key, $p_data, $p_expires_in ) = @_;

  Assert_Defined( $p_key );

  $self->_conditionally_auto_purge_on_set( );

  $self->set_object( $p_key,
                     Build_Object( $p_key,
                                   $p_data,
                                   $self->get_default_expires_in( ),
                                   $p_expires_in ) );
}



sub set_object
{
  my ( $self, $p_key, $p_object ) = @_;

  $self->_get_backend( )->store( $self->get_namespace( ),
                                 $p_key,
                                 $p_object );
}



sub size
{
  my ( $self ) = @_;

  my $size = 0;

  foreach my $key ( $self->get_keys( ) )
  {
    $size += 
      $self->_get_backend( )->get_object_size( $self->get_namespace( ), $key );
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
  my $self = $class->SUPER::_new( $p_options_hash_ref );
  $self->_initialize_memory_cache( );
  return $self;
}


sub _initialize_memory_cache
{
  my ( $self ) = @_;

  $self->_set_backend( new Cache::MemoryBackend( ) );
}


sub _build_object_size
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  return ;
}


##
# Instance properties
##

sub get_keys
{
  my ( $self ) = @_;

  return $self->_get_backend( )->get_keys( $self->get_namespace( ) );
}


sub _get_backend
{
  my ( $self ) = @_;

  return $self->{ _Backend };
}


sub _set_backend
{
  my ( $self, $p_backend ) = @_;

  $self->{ _Backend } = $p_backend;
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
