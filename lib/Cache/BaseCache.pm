######################################################################
# $Id: FileCache.pm,v 1.5 2001/02/19 04:58:30 jswartz Exp $
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
use Carp;

@ISA = qw( Cache::Cache );

my $DEFAULT_EXPIRES_IN = $EXPIRES_NEVER;
my $DEFAULT_NAMESPACE = "Default";

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
