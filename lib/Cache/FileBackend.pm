######################################################################
# $Id: FileBackend.pm,v 1.7 2001/11/29 22:14:11 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::FileBackend;

use strict;
use Cache::CacheUtils qw ( Assert_Defined
                           Build_Unique_Key
                           Build_Path
                           Split_Word
                           List_Subdirectories
                           Make_Path
                           Freeze_Data
                           Read_File_Without_Time_Modification
                           Recursive_Directory_Size
                           Recursively_List_Files
                           Recursively_Remove_Directory
                           Remove_File
                           Update_Access_Time
                           Thaw_Data
                           Write_File );
use Error;


sub new
{
  my ( $proto, $p_root, $p_depth, $p_directory_umask ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  $self = bless( $self, $class );
  $self->set_root( $p_root );
  $self->set_depth( $p_depth );
  $self->set_directory_umask( $p_directory_umask );
  return $self;
}


sub delete_key
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  Remove_File( $self->_path_to_key( $p_namespace, $p_key ) );
}


sub delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  Recursively_Remove_Directory( Build_Path( $self->get_root( ),
                                            $p_namespace ) );
}


sub get_keys
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  my @keys;

  foreach my $unique_key ( $self->get_unique_keys( $p_namespace ) )
  {
    my $key =  $self->_read_data( $self->_path_to_unique_key( $p_namespace, $unique_key ) )->[0] or
      next;

    push( @keys, $key );
  }

  return @keys;

}


sub get_unique_keys
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  my @unique_keys;

  Recursively_List_Files( Build_Path( $self->get_root( ), $p_namespace ),
                          \@unique_keys );

  return @unique_keys;
}


sub get_namespaces
{
  my ( $self ) = @_;

  my @namespaces;

  List_Subdirectories( $self->get_root( ), \@namespaces );

  return @namespaces;
}


sub get_size
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  if ( -e $self->_path_to_key( $p_namespace, $p_key ) )
  {
    return -s $self->_path_to_key( $p_namespace, $p_key );

  }
  else
  {
    return 0;
  }
}


sub restore
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  return $self->_read_data( $self->_path_to_key($p_namespace, $p_key) )->[1];
}


sub store
{
  my ( $self, $p_namespace, $p_key, $p_value ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  $self->_write_data( $self->_path_to_key( $p_namespace, $p_key ),
                      [ $p_key, $p_value ] );

}


sub get_depth
{
  my ( $self ) = @_;

  return $self->{_Depth};
}


sub set_depth
{
  my ( $self, $depth ) = @_;

  $self->{_Depth} = $depth;
}


sub get_root
{
  my ( $self ) = @_;

  return $self->{_Root};
}


sub set_root
{
  my ( $self, $root ) = @_;

  $self->{_Root} = $root;
}


sub get_directory_umask
{
  my ( $self ) = @_;

  return $self->{_Directory_Umask};
}


sub set_directory_umask
{
  my ( $self, $directory_umask ) = @_;

  $self->{_Directory_Umask} = $directory_umask;
}


sub _path_to_key
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  return $self->_path_to_unique_key( $p_namespace,
                                     Build_Unique_Key( $p_key ) );
}


sub _path_to_unique_key
{
  my ( $self, $p_namespace, $p_unique_key ) = @_;

  Assert_Defined( $p_unique_key );
  Assert_Defined( $p_namespace );

  return Build_Path( $self->get_root( ),
                     $p_namespace,
                     Split_Word( $p_unique_key, $self->get_depth( ) ),
                     $p_unique_key );
}


# the data is returned as reference to an array ( key, value )

sub _read_data
{
  my ( $self, $p_path ) = @_;

  Assert_Defined( $p_path );

  my $frozen_data_ref = Read_File_Without_Time_Modification( $p_path ) or
    return [ undef, undef ];

  return Thaw_Data( $$frozen_data_ref );
}


# the data is passed as reference to an array ( key, value )

sub _write_data
{
  my ( $self, $p_path, $p_data ) = @_;

  Assert_Defined( $p_path );
  Assert_Defined( $p_data );

  Make_Path( $p_path, $self->get_directory_umask( ) );

  my $frozen_file = Freeze_Data( $p_data );

  Write_File( $p_path, \$frozen_file );
}


1;
