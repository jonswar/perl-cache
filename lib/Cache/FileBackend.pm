######################################################################
# $Id: FileBackend.pm,v 1.9 2001/12/03 17:21:32 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::FileBackend;

use strict;
use Cache::CacheUtils qw( Assert_Defined Build_Path Freeze_Data Thaw_Data );
use Digest::MD5 qw( md5_hex );
use Error;
use File::Path qw( mkpath );


# the file mode for new directories, which will be modified by the
# current umask

my $DIRECTORY_MODE = 0777;


# valid filepath characters for tainting. Be sure to accept
# DOS/Windows style path specifiers (C:\path) also

my $UNTAINTED_PATH_REGEX = qr{^([-\@\w\\\\~./:]+|[\w]:[-\@\w\\\\~./]+)$};


# Take an human readable key, and create a unique key from it

sub Build_Unique_Key
{
  my ( $p_key ) = @_;

  Assert_Defined( $p_key );

  return md5_hex( $p_key );
}


# create a directory with optional mask, building subdirectories as
# needed.

sub Create_Directory
{
  my ( $p_directory, $p_optional_new_umask ) = @_;

  Assert_Defined( $p_directory );

  my $old_umask = umask( ) if defined $p_optional_new_umask;

  umask( $p_optional_new_umask ) if defined $p_optional_new_umask;

  my $directory = Untaint_Path( $p_directory );

  $directory =~ s|/$||;

  mkpath( $directory, 0, $DIRECTORY_MODE );

  -d $directory or
    throw Error::Simple( "Couldn't create directory: $directory: $!" );

  umask( $old_umask ) if defined $old_umask;
}



# list the names of the subdirectories in a given directory, without the
# full path

sub List_Subdirectories
{
  my ( $p_directory, $p_subdirectories_ref ) = @_;

  foreach my $dirent ( Read_Dirents( $p_directory ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_directory, $dirent );

    next unless -d $path;

    push( @$p_subdirectories_ref, $dirent );
  }
}


# read the dirents from a directory

sub Read_Dirents
{
  my ( $p_directory ) = @_;

  Assert_Defined( $p_directory );

  -d $p_directory or
    return ( );

  opendir( DIR, Untaint_Path( $p_directory ) ) or
    throw Error::Simple( "Couldn't open directory $p_directory: $!" );

  my @dirents = readdir( DIR );

  closedir( DIR ) or
    throw Error::Simple( "Couldn't close directory $p_directory" );

  return @dirents;
}


# read in a file. returns a reference to the data read

sub Read_File
{
  my ( $p_path ) = @_;

  Assert_Defined( $p_path );

  open( FILE, Untaint_Path( $p_path ) ) or
    return undef;

  binmode( FILE );

  local $/ = undef;

  my $data_ref;

  $$data_ref = <FILE>;

  close( FILE );

  return $data_ref;
}


# read in a file. returns a reference to the data read, without
# modifying the last accessed time

sub Read_File_Without_Time_Modification
{
  my ( $p_path ) = @_;

  Assert_Defined( $p_path );

  -e $p_path or
    return undef;

  my ( $file_access_time, $file_modified_time ) =
    ( stat( Untaint_Path( $p_path ) ) )[8,9];

  my $data_ref = Read_File( $p_path );

  utime( $file_access_time, $file_modified_time, Untaint_Path( $p_path ) );

  return $data_ref;
}


# remove a file

sub Remove_File
{
  my ( $p_path ) = @_;

  Assert_Defined( $p_path );

  if ( -f Untaint_Path( $p_path ) )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    unlink( Untaint_Path( $p_path ) );
  }
}


# remove a directory

sub Remove_Directory
{
  my ( $p_directory ) = @_;

  Assert_Defined( $p_directory );

  if ( -d Untaint_Path( $p_directory ) )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    rmdir( Untaint_Path( $p_directory ) );
  }
}


# recursively list the files of the subdirectories, without the full paths

sub Recursively_List_Files
{
  my ( $p_directory, $p_files_ref ) = @_;

  return unless -d $p_directory;

  foreach my $dirent ( Read_Dirents( $p_directory ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_directory, $dirent );

    if ( -d $path )
    {
      Recursively_List_Files( $path, $p_files_ref );
    }
    else
    {
      push( @$p_files_ref, $dirent );
    }
  }
}


# recursively list the files of the subdirectories, with the full paths

sub Recursively_List_Files_With_Paths
{
  my ( $p_directory, $p_files_ref ) = @_;

  foreach my $dirent ( Read_Dirents( $p_directory ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_directory, $dirent );

    if ( -d $path )
    {
      Recursively_List_Files_With_Paths( $path, $p_files_ref );
    }
    else
    {
      push( @$p_files_ref, $path );
    }
  }
}



# remove a directory and all subdirectories and files

sub Recursively_Remove_Directory
{
  my ( $p_root ) = @_;

  return unless -d $p_root;

  foreach my $dirent ( Read_Dirents( $p_root ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_root, $dirent );

    if ( -d $path )
    {
      Recursively_Remove_Directory( $path );
    }
    else
    {
      Remove_File( Untaint_Path( $path ) );
    }
  }

  Remove_Directory( Untaint_Path( $p_root ) );
}



# walk down a directory structure and total the size of the files
# contained therein.

sub Recursive_Directory_Size
{
  my ( $p_directory ) = @_;

  Assert_Defined( $p_directory );

  return 0 unless -d $p_directory;

  my $size = 0;

  foreach my $dirent ( Read_Dirents( $p_directory ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_directory, $dirent );

    if ( -d $path )
    {
      $size += Recursive_Directory_Size( $path );
    }
    else
    {
      $size += -s $path;
    }
  }

  return $size;
}


# Untaint a file path

sub Untaint_Path
{
  my ( $p_path ) = @_;

  return Untaint_String( $p_path, $UNTAINTED_PATH_REGEX );
}


# Untaint a string

sub Untaint_String
{
  my ( $p_string, $p_untainted_regex ) = @_;

  Assert_Defined( $p_string );
  Assert_Defined( $p_untainted_regex );

  my ( $untainted_string ) = $p_string =~ /$p_untainted_regex/;

  if ( not defined $untainted_string || $untainted_string ne $p_string )
  {
    warn( "String $p_string contains possible taint" );
  }

  return $untainted_string;
}


# create a directory with the optional umask if it doesn't already
# exist

sub Make_Path
{
  my ( $p_path, $p_optional_new_umask ) = @_;

  my ( $volume, $directory, $filename ) = File::Spec->splitpath( $p_path );

  if ( defined $directory and not -d $directory )
  {
    Create_Directory( $directory, $p_optional_new_umask );
  }
}


# return a list of the first $depth letters in the $word

sub Split_Word
{
  my ( $p_word, $p_depth ) = @_;

  Assert_Defined( $p_word );
  Assert_Defined( $p_depth );

  my @split_word_list;

  for ( my $i = 0; $i < $p_depth; $i++ )
  {
    push ( @split_word_list, substr( $p_word, $i, 1 ) );
  }

  return @split_word_list;
}


# write a file atomically

sub Write_File
{
  my ( $p_path, $p_data_ref, $p_optional_mode, $p_optional_umask ) = @_;

  Assert_Defined( $p_path );
  Assert_Defined( $p_data_ref );
  Untaint_Path( $p_path );

  my $old_umask = umask if $p_optional_umask;

  umask( $p_optional_umask ) if $p_optional_umask;

  my $temp_path = Untaint_Path( "$p_path.tmp$$" );

  open( FILE, ">$temp_path" ) or
    throw Error::Simple( "Couldn't open $temp_path for writing: $!" );

  binmode( FILE );

  print FILE $$p_data_ref;

  close( FILE );

  rename( $temp_path, Untaint_Path( $p_path ) ) or
    throw Error::Simple( "Couldn't rename $temp_path to $p_path" );

  chmod( $p_optional_mode, Untaint_Path($p_path) ) if defined $p_optional_mode;

  umask( $old_umask ) if $old_umask;
}


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
