######################################################################
# $Id: FileBackend.pm,v 1.3 2001/11/29 16:12:11 dclinton Exp $
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
                           Freeze_Object
                           Read_File_Without_Time_Modification
                           Recursive_Directory_Size
                           Recursively_List_Files
                           Recursively_Remove_Directory
                           Remove_File
                           Update_Access_Time
                           Thaw_Object
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


sub store
{
  my ( $self, $p_namespace, $p_key, $p_value ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  $self->_write_data( $self->_path_to_key( $p_namespace, $p_key ), $p_value );
}


sub restore
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  return $self->_read_data( $self->_path_to_key( $p_namespace, $p_key ) );
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


sub delete_all_namespaces
{
  my ( $self ) = @_;

  Recursively_Remove_Directory( $self->get_root( ) );
}


sub get_file_accessed_at
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  # TODO:  Verify that this is correct

  return stat( $self->_path_to_key( $p_namespace, $p_key ) )->[8];
}



# TODO: This code presumes that the data stored is an Object, which
# makes FileBackend less generally applicable to any type of data
# to be stored

sub get_keys
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  my @keys;

  foreach my $unique_key ( $self->get_unique_keys( $p_namespace ) )
  {
    my $object = 
      $self->_read_data( $self->_path_to_unique_key( $p_namespace,
                                                     $unique_key ) ) or
                                                       next;

    push( @keys, $object->get_key( ) );
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


sub get_object_size
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


sub _write_data
{
  my ( $self, $p_path, $p_file ) = @_;

  Assert_Defined( $p_path );
  Assert_Defined( $p_file );


  Make_Path( $p_path, $self->get_directory_umask( ) );

  my $frozen_file;

  Freeze_Object( \$p_file, \$frozen_file );

  Write_File( $p_path, \$frozen_file );
}


sub _read_data
{
  my ( $self, $p_path ) = @_;

  Assert_Defined( $p_path );

  my $frozen_file_ref = Read_File_Without_Time_Modification( $p_path ) or
    return undef;

  my $file;

  Thaw_Object( $frozen_file_ref, \$file );

  return $file;
}


1;
