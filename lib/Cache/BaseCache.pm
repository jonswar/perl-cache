######################################################################
# $Id: BaseCache.pm,v 1.4 2001/03/22 21:41:35 dclinton Exp $
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
use Cache::Cache qw( $SUCCESS $FAILURE $EXPIRES_NEVER );
use Cache::CacheUtils qw( Freeze_Object
                          Thaw_Object
                        );
use Carp;


@ISA = qw( Cache::Cache );


my $DEFAULT_EXPIRES_IN = $EXPIRES_NEVER;
my $DEFAULT_NAMESPACE = "Default";


##
# Constructor
##


sub new
{
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  bless( $self, $class );

  $self->_initialize_base_cache( $options_hash_ref ) or
    croak( "Couldn't initialize Cache::BaseCache" );

  return $self;
}


##
# Private instance methods
##


sub _initialize_base_cache
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_initialize_options_hash_ref( $options_hash_ref ) or
    croak( "Couldn't initialize options hash ref" );

  $self->_initialize_namespace( ) or
    croak( "Couldn't initialize namespace" );

  $self->_initialize_default_expires_in( ) or
    croak( "Couldn't initialize default expires in" );

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

  $self->_set_namespace( $namespace );

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


sub _set_namespace
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

=back

=head1 SEE ALSO

Cache::Cache, Cache::FileCache, Cache::MemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
