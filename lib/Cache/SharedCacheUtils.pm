######################################################################
# $Id: CacheUtils.pm,v 1.16 2001/03/23 00:15:06 dclinton Exp $
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
use Cache::Cache qw( $SUCCESS $FAILURE );
use Cache::CacheUtils qw( Freeze_Object
                          Static_Params
                          Thaw_Object );
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
  my ( $ipc_identifier ) = Static_Params( @_ );

  defined $ipc_identifier or
    croak( "ipc_identifier required" );

  my %ipc_options = (
                     -key       =>  $ipc_identifier,
                     -create    => 'yes',
                     -destroy   => 'no',
                     -exclusive => 'no'
                    );

  my $share = new IPC::ShareLite( %ipc_options ) or
    croak( "Couldn't instantiate new IPC::ShareLite" );

  return $share;
}


# this method uses the shared created by Instantiate_Share to
# transparently retrieve a reference to a shared hash structure

sub Restore_Shared_Hash_Ref
{
  my ( $ipc_identifier ) = Static_Params( @_ );

  defined $ipc_identifier or
    croak( "ipc_identifier required" );

  my $share = Instantiate_Share( $ipc_identifier ) or
    croak( "Couldn't instantiate share" );

  my $frozen_hash_ref = $share->fetch( ) or
    return ( { } );

  my $hash_ref = { };

  Thaw_Object( \$frozen_hash_ref, \$hash_ref ) or
    croak( "Couldn't thaw object" );

  return $hash_ref;
}


# this method uses the shared created by Instantiate_Share to
# transparently retrieve a reference to a shared hash structure, and
# additionally exlusively locks the share

sub Restore_Shared_Hash_Ref_With_Lock
{
  my ( $ipc_identifier ) = Static_Params( @_ );

  defined $ipc_identifier or
    croak( "ipc_identifier required" );

  my $share = Instantiate_Share( $ipc_identifier ) or
    croak( "Couldn't instantiate share" );

  $share->lock( LOCK_EX ) or
    croak( "Couldn't lock share" );

  my $frozen_hash_ref = $share->fetch( ) or
    return ( { } );

  my $hash_ref = { };

  Thaw_Object( \$frozen_hash_ref, \$hash_ref ) or
    croak( "Couldn't thaw object" );

  return $hash_ref;
}


# this method uses the shared created by Instantiate_Share to
# transparently persist a reference to a shared hash structure

sub Store_Shared_Hash_Ref
{
  my ( $ipc_identifier, $hash_ref ) = @_;

  defined $ipc_identifier or
    croak( "ipc_identifier required" );

  defined $hash_ref or
    croak( "hash_ref required" );

  my $frozen_hash_ref = { };

  Freeze_Object( \$hash_ref, \$frozen_hash_ref ) or
    croak( "Couldn't freeze hash ref" );

  my $share = Instantiate_Share( $ipc_identifier ) or
    croak( "Couldn't instantiate share" );

  $share->store( $frozen_hash_ref ) or
    croak( "Couldn't store frozen_hash_ref" );

  return $SUCCESS;
}


# this method uses the shared created by Instantiate_Share to
# transparently persist a reference to a shared hash structure and
# additionally unlocks the share

sub Store_Shared_Hash_Ref_And_Unlock
{
  my ( $ipc_identifier, $hash_ref ) = @_;

  defined $ipc_identifier or
    croak( "ipc_identifier required" );

  defined $hash_ref or
    croak( "hash_ref required" );

  my $frozen_hash_ref = { };

  Freeze_Object( \$hash_ref, \$frozen_hash_ref ) or
    croak( "Couldn't freeze hash ref" );

  my $share = Instantiate_Share( $ipc_identifier ) or
    croak( "Couldn't instantiate share" );

  $share->store( $frozen_hash_ref ) or
    croak( "Couldn't store frozen_hash_ref" );

  $share->unlock( LOCK_UN ) or
    croak( "Couldn't unlock share" );

  return $SUCCESS;
}



1;

