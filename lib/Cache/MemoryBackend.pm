######################################################################
# $Id: MemoryBackend.pm,v 1.3 2001/11/29 18:12:55 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::MemoryBackend;

use strict;
use Cache::CacheUtils qw( Freeze_Object
                          Thaw_Object );

my $Store_Ref;


sub new
{
  my ( $proto ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  $self = bless( $self, $class );
  $self->_initialize_memory_backend( );
  return $self;
}


sub delete_key
{
  my ( $self, $p_namespace, $p_key ) = @_;

  delete $self->_get_store_ref( )->{ $p_namespace }{ $p_key };
}


sub delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  delete $self->_get_store_ref( )->{ $p_namespace };
}


sub get_keys
{
  my ( $self, $p_namespace ) = @_;

  return keys %{ $self->_get_store_ref( )->{ $p_namespace } };
}


sub get_namespaces
{
  my ( $self ) = @_;

  return keys %{ $self->_get_store_ref( ) };
}


sub get_object_size
{
  my ( $self, $p_namespace, $p_key ) = @_;

  if ( exists $self->_get_store_ref( )->{ $p_namespace }{ $p_key } )
  {
    return length $self->_get_store_ref( )->{ $p_namespace }{ $p_key };
  }
  else
  {
    return 0;
  }
}


sub restore
{
  my ( $self, $p_namespace, $p_key ) = @_;

  return $self->_thaw( $self->_get_store_ref( )->{ $p_namespace }{ $p_key } );
}


sub store
{
  my ( $self, $p_namespace, $p_key, $p_value ) = @_;

  $self->_get_store_ref( )->{ $p_namespace }{ $p_key } =
    $self->_freeze( $p_value );
}


sub _freeze
{
  my ( $self, $p_data ) = @_;

  return undef if not defined $p_data;

  my $frozen_data;

  Freeze_Object( \$p_data, \$frozen_data );

  return $frozen_data;
}


sub _initialize_memory_backend
{
  my ( $self ) = @_;

  if ( not defined $self->_get_store_ref( ) )
  {
    $self->_set_store_ref( { } );
  }
}


sub _thaw
{
  my ( $self, $p_frozen_data ) = @_;

  return undef if not defined $p_frozen_data;

  my $data;

  Thaw_Object( \$p_frozen_data, \$data );

  return $data;

}


sub _get_store_ref
{
  return $Store_Ref;
}


sub _set_store_ref
{
  my ( $self, $p_store_ref ) = @_;

  $Store_Ref = $p_store_ref;
}



1;


