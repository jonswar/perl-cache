######################################################################
# $Id: SharedCacheUtils.pm,v 1.5 2001/11/29 22:40:39 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::SharedCacheUtils;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Cache::CacheUtils qw( Assert_Defined Freeze_Data Static_Params Thaw_Data );
use IPC::ShareLite qw( LOCK_EX LOCK_UN );


@ISA = qw( Exporter );


@EXPORT_OK = qw(
                Instantiate_Share
                Restore_Shared_Hash_Ref
                Restore_Shared_Hash_Ref_With_Lock
                Store_Shared_Hash_Ref
                Store_Shared_Hash_Ref_And_Unlock
               );



# create a IPC::ShareLite share under the ipc_identifier

sub Instantiate_Share
{
  my ( $p_ipc_identifier ) = Static_Params( @_ );

  Assert_Defined( $p_ipc_identifier );

  my %ipc_options = (
                     -key       =>  $p_ipc_identifier,
                     -create    => 'yes',
                     -destroy   => 'no',
                     -exclusive => 'no'
                    );

  return new IPC::ShareLite( %ipc_options );
}


# this method uses the shared created by Instantiate_Share to
# transparently retrieve a reference to a shared hash structure

sub Restore_Shared_Hash_Ref
{
  my ( $p_ipc_identifier ) = Static_Params( @_ );

  Assert_Defined( $p_ipc_identifier );

  my $hash_ref = { };

  my $frozen_hash_ref = Instantiate_Share( $p_ipc_identifier )->fetch( ) or
    return $hash_ref;

  return Thaw_Data( $frozen_hash_ref );
}


# this method uses the shared created by Instantiate_Share to
# transparently retrieve a reference to a shared hash structure, and
# additionally exlusively locks the share

sub Restore_Shared_Hash_Ref_With_Lock
{
  my ( $p_ipc_identifier ) = Static_Params( @_ );

  Assert_Defined( $p_ipc_identifier );

  my $share = Instantiate_Share( $p_ipc_identifier );

  $share->lock( LOCK_EX );

  my $hash_ref = { };

  my $frozen_hash_ref = $share->fetch( ) or
    return $hash_ref;

  return Thaw_Data( $frozen_hash_ref );
}


# this method uses the shared created by Instantiate_Share to
# transparently persist a reference to a shared hash structure

sub Store_Shared_Hash_Ref
{
  my ( $p_ipc_identifier, $p_hash_ref ) = @_;

  Assert_Defined( $p_ipc_identifier );
  Assert_Defined( $p_hash_ref );

  Instantiate_Share( $p_ipc_identifier )->store( Freeze_Data( $p_hash_ref ) );
}


# this method uses the shared created by Instantiate_Share to
# transparently persist a reference to a shared hash structure and
# additionally unlocks the share

sub Store_Shared_Hash_Ref_And_Unlock
{
  my ( $p_ipc_identifier, $p_hash_ref ) = @_;

  Assert_Defined( $p_ipc_identifier );
  Assert_Defined( $p_hash_ref );

  my $share = Instantiate_Share( $p_ipc_identifier );

  $share->store( Freeze_Data( $p_hash_ref ) );

  $share->unlock( LOCK_UN );
}



1;

