######################################################################
# $Id: BaseCache.pm,v 1.19 2001/11/29 22:14:11 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::BaseCache;


use strict;
use vars qw( @ISA );
use Cache::Cache qw( $EXPIRES_NEVER );
use Cache::CacheUtils qw( Assert_Defined
                          Build_Object
                          Clone_Data
                          Object_Has_Expired
                        );
use Error;


@ISA = qw( Cache::Cache );


my $DEFAULT_EXPIRES_IN = $EXPIRES_NEVER;
my $DEFAULT_NAMESPACE = "Default";
my $DEFAULT_AUTO_PURGE_ON_SET = 0;
my $DEFAULT_AUTO_PURGE_ON_GET = 0;


# namespace that stores the keys used for the auto purge functionality

my $AUTO_PURGE_NAMESPACE = "__AUTO_PURGE__";



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


sub get_keys
{
  my ( $self ) = @_;

  return $self->_get_backend( )->get_keys( $self->get_namespace( ) );
}


sub get_identifiers
{
  my ( $self ) = @_;

  warn( "get_identifiers has been marked deprepricated.  use get_keys" );

  return $self->get_keys( );
}


sub get_object
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  my $object =
    $self->_get_backend( )->restore( $self->get_namespace( ), $p_key ) or
      return undef;

  $object->set_size( $self->_get_backend( )->
                     get_size( $self->get_namespace( ), $p_key ) );

  $object->set_key( $p_key );

  return $object;
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

  my $object = Clone_Data( $p_object );

  $object->set_size( undef );
  $object->set_key( undef );

  $self->_get_backend( )->store( $self->get_namespace( ), $p_key, $object );
}


sub size
{
  my ( $self ) = @_;

  my $size = 0;

  foreach my $key ( $self->get_keys( ) )
  {
    $size += $self->_get_backend( )->get_size( $self->get_namespace( ), $key );
  }

  return $size;
}


sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  bless( $self, $class );
  $self->_initialize_base_cache( $p_options_hash_ref );
  return $self;
}


sub _complete_initialization
{
  my ( $self ) = @_;
  $self->_initialize_auto_purge_interval( );
}


sub _initialize_base_cache
{
  my ( $self, $p_options_hash_ref ) = @_;

  $self->_initialize_options_hash_ref( $p_options_hash_ref );
  $self->_initialize_namespace( );
  $self->_initialize_default_expires_in( );
  $self->_initialize_auto_purge_on_set( );
  $self->_initialize_auto_purge_on_get( );
}


sub _initialize_options_hash_ref
{
  my ( $self, $p_options_hash_ref ) = @_;

  $self->_set_options_hash_ref( defined $p_options_hash_ref ?
                                $p_options_hash_ref :
                                { } );
}


sub _initialize_namespace
{
  my ( $self ) = @_;

  my $namespace = $self->_read_option( 'namespace', $DEFAULT_NAMESPACE );

  $self->set_namespace( $namespace );
}


sub _initialize_default_expires_in
{
  my ( $self ) = @_;

  my $default_expires_in =
    $self->_read_option( 'default_expires_in', $DEFAULT_EXPIRES_IN );

  $self->_set_default_expires_in( $default_expires_in );
}


sub _initialize_auto_purge_interval
{
  my ( $self ) = @_;

  my $auto_purge_interval = $self->_read_option( 'auto_purge_interval' );

  if ( defined $auto_purge_interval )
  {
    $self->set_auto_purge_interval( $auto_purge_interval );
    $self->_auto_purge( );
  }
}


sub _initialize_auto_purge_on_set
{
  my ( $self ) = @_;

  my $auto_purge_on_set =
    $self->_read_option( 'auto_purge_on_set', $DEFAULT_AUTO_PURGE_ON_SET );

  $self->set_auto_purge_on_set( $auto_purge_on_set );
}


sub _initialize_auto_purge_on_get
{
  my ( $self ) = @_;

  my $auto_purge_on_get =
    $self->_read_option( 'auto_purge_on_get', $DEFAULT_AUTO_PURGE_ON_GET );

  $self->set_auto_purge_on_get( $auto_purge_on_get );
}



# _read_option looks for an option named 'option_name' in the
# option_hash associated with this instance.  If it is not found, then
# 'default_value' will be returned instance

sub _read_option
{
  my ( $self, $p_option_name, $p_default_value ) = @_;

  my $options_hash_ref = $self->_get_options_hash_ref( );

  if ( defined $options_hash_ref->{ $p_option_name } )
  {
    return $options_hash_ref->{ $p_option_name };
  }
  else
  {
    return $p_default_value;
  }
}



# this method checks to see if the auto_purge property is set for a
# particular cache.  If it is, then it switches the cache to the
# $AUTO_PURGE_NAMESPACE and stores that value under the name of the
# current cache namespace

sub _reset_auto_purge_interval
{
  my ( $self ) = @_;

  return if not $self->_should_auto_purge( );

  my $real_namespace = $self->get_namespace( );

  $self->set_namespace( $AUTO_PURGE_NAMESPACE );

  if ( not defined $self->get( $real_namespace ) )
  {
    $self->_insert_auto_purge_object( $real_namespace );
  }

  $self->set_namespace( $real_namespace );
}


sub _should_auto_purge
{
  my ( $self ) = @_;

  return ( defined $self->get_auto_purge_interval( ) &&
           $self->get_auto_purge_interval( ) ne $EXPIRES_NEVER );
}

sub _insert_auto_purge_object
{
  my ( $self, $p_real_namespace ) = @_;

  my $object = Build_Object( $p_real_namespace,
                             1,
                             $self->get_auto_purge_interval( ),
                             undef );

  $self->set_object( $p_real_namespace, $object );
}



# this method checks to see if the auto_purge property is set, and if
# it is, switches to the $AUTO_PURGE_NAMESPACE and sees if a value
# exists at the location specified by a key named for the current
# namespace.  If that key doesn't exist, then the purge method is
# called on the cache

sub _auto_purge
{
  my ( $self ) = @_;

  if ( $self->_needs_auto_purge( ) )
  {
    $self->purge( );
    $self->_reset_auto_purge_interval( );
  }
}


sub _get_auto_purge_object
{
  my ( $self ) = @_;

  my $real_namespace = $self->get_namespace( );
  $self->set_namespace( $AUTO_PURGE_NAMESPACE );
  my $auto_purge_object = $self->get_object( $real_namespace );
  $self->set_namespace( $real_namespace );
  return $auto_purge_object;
}


sub _needs_auto_purge
{
  my ( $self ) = @_;

  return ( $self->_should_auto_purge( ) &&
           Object_Has_Expired( $self->_get_auto_purge_object( ) ) );
}


# call auto_purge if the auto_purge_on_set option is true

sub _conditionally_auto_purge_on_set
{
  my ( $self ) = @_;

  if ( $self->get_auto_purge_on_set( ) )
  {
    $self->_auto_purge( );
  }
}


# call auto_purge if the auto_purge_on_get option is true

sub _conditionally_auto_purge_on_get
{
  my ( $self ) = @_;

  if ( $self->get_auto_purge_on_get( ) )
  {
    $self->_auto_purge( );
  }
}


sub _get_options_hash_ref
{
  my ( $self ) = @_;

  return $self->{_Options_Hash_Ref};
}


sub _set_options_hash_ref
{
  my ( $self, $options_hash_ref ) = @_;

  $self->{_Options_Hash_Ref} = $options_hash_ref;
}


sub get_namespace
{
  my ( $self ) = @_;

  return $self->{_Namespace};
}


sub set_namespace
{
  my ( $self, $namespace ) = @_;

  $self->{_Namespace} = $namespace;
}


sub get_default_expires_in
{
  my ( $self ) = @_;

  return $self->{_Default_Expires_In};
}


sub _set_default_expires_in
{
  my ( $self, $default_expires_in ) = @_;

  $self->{_Default_Expires_In} = $default_expires_in;
}


sub get_auto_purge_interval
{
  my ( $self ) = @_;

  return $self->{_Auto_Purge_Interval};
}


sub set_auto_purge_interval
{
  my ( $self, $auto_purge_interval ) = @_;

  $self->{_Auto_Purge_Interval} = $auto_purge_interval;

  $self->_reset_auto_purge_interval( );
}


sub get_auto_purge_on_set
{
  my ( $self ) = @_;

  return $self->{_Auto_Purge_On_Set};
}


sub set_auto_purge_on_set
{
  my ( $self, $auto_purge_on_set ) = @_;

  $self->{_Auto_Purge_On_Set} = $auto_purge_on_set;
}


sub get_auto_purge_on_get
{
  my ( $self ) = @_;

  return $self->{_Auto_Purge_On_Get};
}


sub set_auto_purge_on_get
{
  my ( $self, $auto_purge_on_get ) = @_;

  $self->{_Auto_Purge_On_Get} = $auto_purge_on_get;
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

Cache::BaseCache -- abstract cache base class

=head1 DESCRIPTION

BaseCache provides functionality common to all instances of a cache.
It differes from the CacheUtils package insofar as it is designed to
be used as superclass for cache implementations.

=head1 SYNOPSIS

Cache::BaseCache is to be used as a superclass for cache
implementations.  The most effective way to use BaseCache is to use
the protected _set_backend method, which will be used to retrieve the
persistance mechanism.  The subclass can then inherit the BaseCache's
implentation of get, set, etc.  However, due to the difficulty
inheriting static methods in Perl, the subclass will likely need to
explicitly implement Clear, Purge, and Size.

  package Cache::MyCache;

  use vars qw( @ISA );
  use Cache::BaseCache;
  use Cache::MyBackend;

  @ISA = qw( Cache::BaseCache );

  sub new
  {
    my ( $self ) = _new( @_ );

    $self->_complete_initialization( );

    return $self;
  }

  sub _new
  {
    my ( $proto, $p_options_hash_ref ) = @_;
    my $class = ref( $proto ) || $proto;
    my $self = $class->SUPER::_new( $p_options_hash_ref );
    $self->_set_backend( new Cache::MyBackend( ) );
    return $self;
  }


=head1 SEE ALSO

Cache::Cache, Cache::FileCache, Cache::MemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
