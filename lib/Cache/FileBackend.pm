######################################################################
# $Id: FileBackend.pm,v 1.1 2001/11/24 19:15:48 dclinton Exp $
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

  Make_Path( $self->_path_to_key( $p_namespace, $p_key ),
             $self->get_directory_umask( ) );

  Write_File( $self->_path_to_key( $p_namespace, $p_key ),
              \$self->_freeze( $p_value ) );
}


sub restore
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  return $self->_read_object( $self->_path_to_key( $p_namespace, $p_key ) );
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


sub update_access_time
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  Update_Access_Time( $self->_path_to_key( $p_namespace, $p_key ) );
}




sub get_keys
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  my @keys;

  foreach my $unique_key ( $self->_list_unique_keys( $p_namespace ) )
  {
    my $object = 
      $self->_read_object( $self->_path_to_unique_key( $p_namespace,
                                                       $unique_key ) ) or
                                                         next;

    push( @keys, $object->get_key( ) );
  }

  return @keys;

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
}


sub get_namespace_size
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  return Recursive_Directory_Size( Build_Path( $self->get_root( ),
                                               $p_namespace ) );
}


sub get_total_size
{
  my ( $self ) = @_;

  return Recursive_Directory_Size( $self->get_root( ) );
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


sub _get_atime
{
  my ( $self, $p_path ) = @_;

  return ( stat( $p_path ) )[8];
}


sub _freeze
{
  my ( $self, $p_object ) = @_;

  return undef if not defined $p_object;

  $p_object->set_size( undef );

  my $frozen_object;

  Freeze_Object( \$p_object, \$frozen_object );

  return $frozen_object;
}


sub _thaw
{
  my ( $self, $p_frozen_object ) = @_;

  return undef if not defined $p_frozen_object;

  my $object;

  Thaw_Object( $p_frozen_object, \$object );

  $object->set_size( length $p_frozen_object );

  return $object;

}


sub _list_unique_keys
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  my @unique_keys;

  Recursively_List_Files( Build_Path( $self->get_root( ), $p_namespace ),
                          \@unique_keys );

  return @unique_keys;
}



sub _read_object
{
  my ( $self, $p_object_path ) = @_;

  Assert_Defined( $p_object_path );

  my $object_dump_ref = Read_File_Without_Time_Modification($p_object_path) or
    return undef;

  my $object = $self->_thaw( $object_dump_ref );

  $object->set_accessed_at( $self->_get_atime( $p_object_path ) );

  return $object;
}

1;
