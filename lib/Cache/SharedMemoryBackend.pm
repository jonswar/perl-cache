######################################################################
# $Id: SharedMemoryBackend.pm,v 1.1 2001/11/08 23:01:23 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::SharedMemoryBackend;

use strict;
use Cache::MemoryBackend;
use Cache::SharedCacheUtils qw( Restore_Shared_Hash_Ref
                                Restore_Shared_Hash_Ref_With_Lock
                                Store_Shared_Hash_Ref
                                Store_Shared_Hash_Ref_And_Unlock );

use vars qw( @ISA );

@ISA = qw ( Cache::MemoryBackend );


my $IPC_IDENTIFIER = 'ipcc';


sub new
{
  my ( $proto ) = @_;
  my $class = ref( $proto ) || $proto;
  return $class->SUPER::new( );
}


sub delete_key
{
  my ( $self, $p_namespace, $p_key ) = @_;

  my $store_ref = $self->_get_locked_store_ref( );

  delete $store_ref->{ $p_namespace }{ $p_key };

  $self->_set_locked_store_ref( $store_ref );
}


sub delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  my $store_ref = $self->_get_locked_store_ref( );

  delete $store_ref->{ $p_namespace };

  $self->_set_locked_store_ref( $store_ref );
}


sub store
{
  my ( $self, $p_namespace, $p_key, $p_value ) = @_;

  my $store_ref = $self->_get_locked_store_ref( );

  $store_ref->{ $p_namespace }{ $p_key } = $self->_freeze( $p_value );

  $self->_set_locked_store_ref( $store_ref );
}


sub _get_locked_store_ref
{
  return Restore_Shared_Hash_Ref_With_Lock( $IPC_IDENTIFIER );
}


sub _set_locked_store_ref
{
  my ( $self, $p_store_ref ) = @_;

  Store_Shared_Hash_Ref_And_Unlock( $IPC_IDENTIFIER, $p_store_ref );
}


sub _get_store_ref
{
  return Restore_Shared_Hash_Ref( $IPC_IDENTIFIER );
}


sub _set_store_ref
{
  my ( $self, $p_store_ref ) = @_;

  Store_Shared_Hash_Ref( $IPC_IDENTIFIER, $p_store_ref );
}

1;
