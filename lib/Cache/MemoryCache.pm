######################################################################
# $Id: MemoryCache.pm,v 1.14 2001/04/08 22:48:37 dclinton Exp $
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
use Cache::Cache qw( $EXPIRES_NEVER $TRUE $FALSE $SUCCESS $FAILURE );
use Cache::CacheUtils qw( Auto_Purge
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
    _Delete_Namespace( $namespace ) or
      croak( "Couldn't delete namespace $namespace" );
  }

  return $SUCCESS;
}


sub Purge
{
  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache = new Cache::MemoryCache( { 'namespace' => $namespace } ) or
      croak( "Couldn't construct cache with namespace $namespace" );

    $cache->purge( ) or
      croak( "Couldn't purge cache with namespace $namespace" );
  }

  return $SUCCESS;
}


sub Size
{
  my $size = 0;

  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache = new Cache::MemoryCache( { 'namespace' => $namespace } ) or
      croak( "Couldn't construct cache with namespace $namespace" );

    $size += $cache->size( );
  }

  return $size;
}


##
# Private class methods
##


sub _Delete_Namespace
{
  my ( $namespace ) = Static_Params( @_ );

  defined $namespace or
    croak( "Namespace required" );

  my $cache_hash_ref = _Get_Cache_Hash_Ref( ) or
    croak( "Couldn't get cache hash ref" );

  delete $cache_hash_ref->{ $namespace };

  return $SUCCESS;
}


sub _Namespaces
{
  my $cache_hash_ref = _Get_Cache_Hash_Ref( ) or
    croak( "Couldn't get cache hash ref" );

  return keys %{$cache_hash_ref};
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
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;

  my $self  =  $class->SUPER::new( $options_hash_ref ) or
    croak( "Couldn't run super constructor" );

  $self->_initialize_memory_cache( ) or
    croak( "Couldn't initialize Cache::MemoryCache" );

  return $self;
}


##
# Public instance methods
##


sub clear
{
  my ( $self ) = @_;

  my $namespace = $self->get_namespace( ) or
    croak( "Namespace required" );

  $self->_delete_namespace( $namespace ) or
    croak( "Couldn't delete namespace $namespace" );

  return $SUCCESS;
}


sub get
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $object = $self->get_object( $identifier ) or
    return undef;

  my $has_expired = Object_Has_Expired( $object );

  if ( $has_expired eq $TRUE )
  {
    $self->remove( $identifier ) or
      croak( "Couldn't remove object $identifier" );

    return undef;
  }

  return $object->get_data( );
}


sub get_object
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $object = $self->_restore( $identifier ) or
    return undef;

  return $object;
}


sub purge
{
  my ( $self ) = @_;

  foreach my $identifier ( $self->get_identifiers( ) )
  {
    $self->get( $identifier );
  }

  return $SUCCESS;
}


sub remove
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache hash ref" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  delete $cache_hash_ref->{$namespace}->{$identifier};

  return $SUCCESS;
}


sub set
{
  my ( $self, $identifier, $data, $expires_in ) = @_;

  Auto_Purge( $self ) or
    croak( "Couldn't auto purge" );

  my $default_expires_in = $self->get_default_expires_in( );

  my $object =
    Build_Object( $identifier, $data, $default_expires_in, $expires_in ) or
      croak( "Couldn't build cache object" );

  $self->set_object( $identifier, $object ) or
    croak( "Couldn't set object" );

  return $SUCCESS;
}


sub set_object
{
  my ( $self, $identifier, $object ) = @_;

  $self->_store( $identifier, $object ) or
    croak( "Couldn't store $identifier" );

  return $SUCCESS;
}


sub size
{
  my ( $self ) = @_;

  my $size = 0;

  foreach my $identifier ( $self->get_identifiers( ) )
  {
    $size += $self->_build_object_size( $identifier );
  }

  return $size;
}


##
# Private instance methods
##


sub _initialize_memory_cache
{
  my ( $self, $options_hash_ref ) = @_;

  return $SUCCESS;
}


sub _store
{
  my ( $self, $identifier, $object ) = @_;

  $identifier or
    croak( "identifier required" );

  my $object_dump = $self->_freeze( $object ) or
    croak( "Couldn't freeze object" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache hash ref" );

  $cache_hash_ref->{$namespace}->{$identifier} = $object_dump;

  return $SUCCESS;
}


sub _restore
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache hash ref" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $object_dump = $cache_hash_ref->{$namespace}->{$identifier} or
    return undef;

  my $object = $self->_thaw( $object_dump ) or
    croak( "Couldn't thaw object" );

  return $object;
}


sub _delete_namespace
{
  my ( $self, $namespace ) = @_;

  defined( $namespace ) or
    croak( "namespace required" );

  _Delete_Namespace( $namespace ) or
    croak( "Couldn't delete namespace $namespace" );

  return $SUCCESS;
}


sub _build_object_size
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache hash ref" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $object_dump = $cache_hash_ref->{$namespace}->{$identifier} or
    return 0;

  my $size = length $object_dump;

  return $size;
}


##
# Instance properties
##

sub _get_cache_hash_ref
{
  my ( $self ) = @_;

  return _Get_Cache_Hash_Ref( );
}



sub get_identifiers
{
  my ( $self ) = @_;

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache hash ref" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  return ( ) unless defined $cache_hash_ref->{ $namespace };

  return keys %{ $cache_hash_ref->{ $namespace} };
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

=item B<get( $identifier )>

See Cache::Cache

=item B<get_object( $identifier )>

See Cache::Cache

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
