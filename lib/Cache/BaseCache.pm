######################################################################
# $Id: BaseCache.pm,v 1.7 2001/04/25 22:22:04 dclinton Exp $
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
use Cache::Cache qw( $SUCCESS $FAILURE $EXPIRES_NEVER $TRUE $FALSE);
use Cache::CacheUtils qw( Build_Object
                          Freeze_Object
                          Object_Has_Expired
                          Thaw_Object
                        );
use Carp;


@ISA = qw( Cache::Cache );


my $DEFAULT_EXPIRES_IN = $EXPIRES_NEVER;
my $DEFAULT_NAMESPACE = "Default";
my $DEFAULT_AUTO_PURGE_ON_SET = $FALSE;
my $DEFAULT_AUTO_PURGE_ON_GET = $FALSE;


# namespace that stores the keys used for the auto purge functionality

my $AUTO_PURGE_NAMESPACE = "__AUTO_PURGE__";



##
# Constructor
##


sub new
{
  my ( $self ) = _new( @_ );

  $self->_complete_initialization( ) or
    croak( "Couldn't complete initialization" );

  return $self;
}


##
# Private instance methods
##


sub _new
{
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  bless( $self, $class );

  $self->_initialize_base_cache( $options_hash_ref ) or
    croak( "Couldn't initialize Cache::BaseCache" );

  return $self;
}


sub _complete_initialization
{
  my ( $self ) = @_;

  $self->_initialize_auto_purge_interval( ) or
    croak( "Couldn't initialize auto purge interval" );

  return $SUCCESS;
}


sub _initialize_base_cache
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_initialize_options_hash_ref( $options_hash_ref ) or
    croak( "Couldn't initialize options hash ref" );

  $self->_initialize_namespace( ) or
    croak( "Couldn't initialize namespace" );

  $self->_initialize_default_expires_in( ) or
    croak( "Couldn't initialize default expires in" );

  $self->_initialize_auto_purge_on_set( ) or
    croak( "Couldn't initialize auto purge on set" );

  $self->_initialize_auto_purge_on_get( ) or
    croak( "Couldn't initialize auto purge on get" );

  return $SUCCESS;
}


sub _initialize_options_hash_ref
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_set_options_hash_ref( $options_hash_ref );

  return $SUCCESS;
}


sub _initialize_namespace
{
  my ( $self ) = @_;

  my $namespace = $self->_read_option( 'namespace', $DEFAULT_NAMESPACE );

  $self->set_namespace( $namespace );

  return $SUCCESS;
}


sub _initialize_default_expires_in
{
  my ( $self ) = @_;

  my $default_expires_in =
    $self->_read_option( 'default_expires_in', $DEFAULT_EXPIRES_IN );

  $self->_set_default_expires_in( $default_expires_in );

  return $SUCCESS;
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

  return $SUCCESS;
}


sub _initialize_auto_purge_on_set
{
  my ( $self ) = @_;

  my $auto_purge_on_set =
    $self->_read_option( 'auto_purge_on_set', $DEFAULT_AUTO_PURGE_ON_SET );

  $self->set_auto_purge_on_set( $auto_purge_on_set );

  return $SUCCESS;
}


sub _initialize_auto_purge_on_get
{
  my ( $self ) = @_;

  my $auto_purge_on_get =
    $self->_read_option( 'auto_purge_on_get', $DEFAULT_AUTO_PURGE_ON_GET );

  $self->set_auto_purge_on_get( $auto_purge_on_get );

  return $SUCCESS;
}



# _read_option looks for an option named 'option_name' in the
# option_hash associated with this instance.  If it is not found, then
# 'default_value' will be returned instance


sub _read_option
{
  my ( $self, $option_name, $default_value ) = @_;

  my $options_hash_ref = $self->_get_options_hash_ref( );

  if ( defined $options_hash_ref->{$option_name} )
  {
    return $options_hash_ref->{$option_name};
  }
  else
  {
    return $default_value;
  }
}


sub _freeze
{
  my ( $self, $object ) = @_;

  defined $object or
    croak( "object required" );

  $object->set_size( undef );

  my $object_dump;

  Freeze_Object( \$object, \$object_dump ) or
    croak( "Couldn't freeze object" );

  return $object_dump;
}


sub _thaw
{
  my ( $self, $object_dump ) = @_;

  defined $object_dump or
    croak( "object_dump required" );

  my $size = length $object_dump;

  my $object;

  Thaw_Object( \$object_dump, \$object ) or
    croak( "Couldn't thaw object" );

  $object->set_size( $size );

  return $object;
}



# this method checks to see if the auto_purge property is set for a
# particular cache.  If it is, then it switches the cache to the
# $AUTO_PURGE_NAMESPACE and stores that value under the name of the
# current cache namespace

sub _reset_auto_purge_interval
{
  my ( $self ) = @_;

  my $auto_purge_interval = $self->get_auto_purge_interval( );

  return $SUCCESS if not defined $auto_purge_interval;

  return $SUCCESS if $auto_purge_interval eq $EXPIRES_NEVER;

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  $self->set_namespace( $AUTO_PURGE_NAMESPACE ) or
    croak( "Couldn't set auto purge namespace to $AUTO_PURGE_NAMESPACE" );

  if ( not defined $self->get( $namespace ) )
  {
    my $object =
      Build_Object( $namespace, 1, $auto_purge_interval, undef ) or
        croak( "Couldn't build cache object" );

    $self->set_object( $namespace, $object ) or
      croak( "Couldn't set_object( $namespace, $object )" );
  }

  $self->set_namespace( $namespace ) or
    croak( "Couldn't set namespace to $namespace" );

  return $SUCCESS;
}





# this method checks to see if the auto_purge property is set, and if
# it is, switches to the $AUTO_PURGE_NAMESPACE and sees if a value
# exists at the location specified by a key named for the current
# namespace.  If that key doesn't exist, then the purge method is
# called on the cache

sub _auto_purge
{
  my ( $self ) = @_;

  my $auto_purge_interval = $self->get_auto_purge_interval( );

  return $SUCCESS if not defined $auto_purge_interval;

  return $SUCCESS if $auto_purge_interval eq $EXPIRES_NEVER;

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  $self->set_namespace( $AUTO_PURGE_NAMESPACE ) or
    croak( "Couldn't set auto purge namespace to $AUTO_PURGE_NAMESPACE" );

  my $auto_purge_object = $self->get_object( $namespace );

  $self->set_namespace( $namespace ) or
    croak( "Couldn't set namespace to $namespace" );

  if ( ( not defined $auto_purge_object ) or
       ( Object_Has_Expired ( $auto_purge_object ) ) )
  {
    $self->purge( ) or
      croak( "Couldn't purge" );

    $self->_reset_auto_purge_interval( ) or
      croak( "Couldn't reset auto purge interval" );
  }

  return $SUCCESS;
}


# call auto_purge if the auto_purge_on_set option is true

sub _conditionally_auto_purge_on_set
{
  my ( $self ) = @_;

  if ( $self->get_auto_purge_on_set( ) )
  {
    $self->_auto_purge( ) or
      croak( "Couldn't auto purge" );
  }

  return $SUCCESS;
}


# call auto_purge if the auto_purge_on_get option is true

sub _conditionally_auto_purge_on_get
{
  my ( $self ) = @_;

  if ( $self->get_auto_purge_on_get( ) )
  {
    $self->_auto_purge( ) or
      croak( "Couldn't auto purge" );
  }

  return $SUCCESS;
}


##
# Instance properties
##


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

  $self->_reset_auto_purge_interval( ) or
    croak( "Couldn't reset auto purge interval" );
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
implementations.

  package Cache::MyCache;

  use vars qw( @ISA );
  use Cache::BaseCache;

  @ISA = qw( Cache::BaseCache );

  sub new
  {
    my ( $proto, $options_hash_ref ) = @_;
    my $class = ref( $proto ) || $proto;

    my $self  =  $class->SUPER::new( $options_hash_ref ) or
      croak( "Couldn't run super constructor" );

    return $self;
  }

  sub get
  {
    my ( $self, $identifier ) = @_;

    #...
  }


=head1 PROPERTIES

=over 4

=item B<get_namespace>

See Cache::Cache

=item B<get_default_expires_in>

See Cache::Cache

=item B<get_auto_purge>

See Cache::Cache

=back

=head1 SEE ALSO

Cache::Cache, Cache::FileCache, Cache::MemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
