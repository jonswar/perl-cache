######################################################################
# $Id: FileBackend.pm,v 1.20 2002/04/07 17:04:46 dclinton Exp $
# Copyright (C) 2001, 2002 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::FileBackend;

use strict;
use Cache::CacheUtils qw( Assert_Defined Build_Path Freeze_Data Thaw_Data );
use Digest::SHA1 qw( sha1_hex );
use Error;
use File::Path qw( mkpath );


# the file mode for new directories, which will be modified by the
# current umask

my $DIRECTORY_MODE = 0777;


# regex for untainting directory and file paths. since all paths are
# generated by us or come from user via API, a tautological regex
# suffices.

my $UNTAINTED_PATH_REGEX = '^(.*)$';


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

  _Remove_File( $self->_path_to_key( $p_namespace, $p_key ) );
}


sub delete_namespace
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  _Recursively_Remove_Directory( Build_Path( $self->get_root( ),
                                             $p_namespace ) );
}


sub get_keys
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  my @keys;

  foreach my $unique_key ( $self->_get_unique_keys( $p_namespace ) )
  {
    my $key = $self->_get_key_for_unique_key( $p_namespace, $unique_key ) or
      next;

    push( @keys, $key );
  }

  return @keys;

}


sub get_namespaces
{
  my ( $self ) = @_;

  my @namespaces;

  _List_Subdirectories( $self->get_root( ), \@namespaces );

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
  my ( $self, $p_namespace, $p_key, $p_data ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  $self->_write_data( $self->_path_to_key( $p_namespace, $p_key ),
                      [ $p_key, $p_data ] );

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


# Take an human readable key, and create a unique key from it

sub _Build_Unique_Key
{
  my ( $p_key ) = @_;

  Assert_Defined( $p_key );

  return sha1_hex( $p_key );
}


# create a directory with optional mask, building subdirectories as
# needed.

sub _Create_Directory
{
  my ( $p_directory, $p_optional_new_umask ) = @_;

  Assert_Defined( $p_directory );

  my $old_umask = umask( ) if defined $p_optional_new_umask;

  umask( $p_optional_new_umask ) if defined $p_optional_new_umask;

  my $directory = _Untaint_Path( $p_directory );

  $directory =~ s|/$||;

  mkpath( $directory, 0, $DIRECTORY_MODE );

  -d $directory or
    throw Error::Simple( "Couldn't create directory: $directory: $!" );

  umask( $old_umask ) if defined $old_umask;
}



# list the names of the subdirectories in a given directory, without the
# full path

sub _List_Subdirectories
{
  my ( $p_directory, $p_subdirectories_ref ) = @_;

  foreach my $dirent ( _Read_Dirents( $p_directory ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_directory, $dirent );

    next unless -d $path;

    push( @$p_subdirectories_ref, $dirent );
  }
}


# read the dirents from a directory

sub _Read_Dirents
{
  my ( $p_directory ) = @_;

  Assert_Defined( $p_directory );

  -d $p_directory or
    return ( );

  local *Dir;

  opendir( Dir, _Untaint_Path( $p_directory ) ) or
    throw Error::Simple( "Couldn't open directory $p_directory: $!" );

  my @dirents = readdir( Dir );

  closedir( Dir ) or
    throw Error::Simple( "Couldn't close directory $p_directory" );

  return @dirents;
}


# read in a file. returns a reference to the data read

sub _Read_File
{
  my ( $p_path ) = @_;

  Assert_Defined( $p_path );

  local *File;

  open( File, _Untaint_Path( $p_path ) ) or
    return undef;

  binmode( File );

  local $/ = undef;

  my $data_ref;

  $$data_ref = <File>;

  close( File );

  return $data_ref;
}


# read in a file. returns a reference to the data read, without
# modifying the last accessed time

sub _Read_File_Without_Time_Modification
{
  my ( $p_path ) = @_;

  Assert_Defined( $p_path );

  -e $p_path or
    return undef;

  my ( $file_access_time, $file_modified_time ) =
    ( stat( _Untaint_Path( $p_path ) ) )[8,9];

  my $data_ref = _Read_File( $p_path );

  utime( $file_access_time, $file_modified_time, _Untaint_Path( $p_path ) );

  return $data_ref;
}


# remove a file

sub _Remove_File
{
  my ( $p_path ) = @_;

  Assert_Defined( $p_path );

  if ( -f _Untaint_Path( $p_path ) )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    unlink( _Untaint_Path( $p_path ) );
  }
}


# remove a directory

sub _Remove_Directory
{
  my ( $p_directory ) = @_;

  Assert_Defined( $p_directory );

  if ( -d _Untaint_Path( $p_directory ) )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    rmdir( _Untaint_Path( $p_directory ) );
  }
}


# recursively list the files of the subdirectories, without the full paths

sub _Recursively_List_Files
{
  my ( $p_directory, $p_files_ref ) = @_;

  return unless -d $p_directory;

  foreach my $dirent ( _Read_Dirents( $p_directory ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_directory, $dirent );

    if ( -d $path )
    {
      _Recursively_List_Files( $path, $p_files_ref );
    }
    else
    {
      push( @$p_files_ref, $dirent );
    }
  }
}


# recursively list the files of the subdirectories, with the full paths

sub _Recursively_List_Files_With_Paths
{
  my ( $p_directory, $p_files_ref ) = @_;

  foreach my $dirent ( _Read_Dirents( $p_directory ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_directory, $dirent );

    if ( -d $path )
    {
      _Recursively_List_Files_With_Paths( $path, $p_files_ref );
    }
    else
    {
      push( @$p_files_ref, $path );
    }
  }
}



# remove a directory and all subdirectories and files

sub _Recursively_Remove_Directory
{
  my ( $p_root ) = @_;

  return unless -d $p_root;

  foreach my $dirent ( _Read_Dirents( $p_root ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_root, $dirent );

    if ( -d $path )
    {
      _Recursively_Remove_Directory( $path );
    }
    else
    {
      _Remove_File( _Untaint_Path( $path ) );
    }
  }

  _Remove_Directory( _Untaint_Path( $p_root ) );
}



# walk down a directory structure and total the size of the files
# contained therein.

sub _Recursive_Directory_Size
{
  my ( $p_directory ) = @_;

  Assert_Defined( $p_directory );

  return 0 unless -d $p_directory;

  my $size = 0;

  foreach my $dirent ( _Read_Dirents( $p_directory ) )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $p_directory, $dirent );

    if ( -d $path )
    {
      $size += _Recursive_Directory_Size( $path );
    }
    else
    {
      $size += -s $path;
    }
  }

  return $size;
}


# Untaint a file path

sub _Untaint_Path
{
  my ( $p_path ) = @_;

  return _Untaint_String( $p_path, $UNTAINTED_PATH_REGEX );
}


# Untaint a string

sub _Untaint_String
{
  my ( $p_string, $p_untainted_regex ) = @_;

  Assert_Defined( $p_string );
  Assert_Defined( $p_untainted_regex );

  my ( $untainted_string ) = $p_string =~ /$p_untainted_regex/;

  if ( not defined $untainted_string || $untainted_string ne $p_string )
  {
    throw Error::Simple( "String $p_string contains possible taint" );
  }

  return $untainted_string;
}


# create a directory with the optional umask if it doesn't already
# exist

sub _Make_Path
{
  my ( $p_path, $p_optional_new_umask ) = @_;

  my ( $volume, $directory, $filename ) = File::Spec->splitpath( $p_path );

  if ( defined $directory and defined $volume )
  {
    $directory = File::Spec->catpath( $volume, $directory, "" );
  }

  if ( defined $directory and not -d $directory )
  {
    _Create_Directory( $directory, $p_optional_new_umask );
  }
}


# return a list of the first $depth letters in the $word

sub _Split_Word
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

sub _Write_File
{
  my ( $p_path, $p_data_ref, $p_optional_mode, $p_optional_umask ) = @_;

  Assert_Defined( $p_path );
  Assert_Defined( $p_data_ref );

  my $old_umask = umask if $p_optional_umask;

  umask( $p_optional_umask ) if $p_optional_umask;

  my $temp_path = _Untaint_Path( "$p_path.tmp$$" );

  local *File;

  open( File, ">$temp_path" ) or
    throw Error::Simple( "Couldn't open $temp_path for writing: $!" );

  binmode( File );

  print File $$p_data_ref;

  close( File );

  rename( $temp_path, _Untaint_Path( $p_path ) ) or
    throw Error::Simple( "Couldn't rename $temp_path to $p_path" );

  chmod( $p_optional_mode, _Untaint_Path($p_path) ) if
    defined $p_optional_mode;

  umask( $old_umask ) if $old_umask;
}


sub _get_key_for_unique_key
{
  my ( $self, $p_namespace, $p_unique_key ) = @_;

  return $self->_read_data( $self->_path_to_unique_key( $p_namespace,
                                                        $p_unique_key ) )->[0];
}


sub _get_unique_keys
{
  my ( $self, $p_namespace ) = @_;

  Assert_Defined( $p_namespace );

  my @unique_keys;

  _Recursively_List_Files( Build_Path( $self->get_root( ), $p_namespace ),
                           \@unique_keys );

  return @unique_keys;
}


sub _path_to_key
{
  my ( $self, $p_namespace, $p_key ) = @_;

  Assert_Defined( $p_namespace );
  Assert_Defined( $p_key );

  return $self->_path_to_unique_key( $p_namespace,
                                     _Build_Unique_Key( $p_key ) );
}


sub _path_to_unique_key
{
  my ( $self, $p_namespace, $p_unique_key ) = @_;

  Assert_Defined( $p_unique_key );
  Assert_Defined( $p_namespace );

  return Build_Path( $self->get_root( ),
                     $p_namespace,
                     _Split_Word( $p_unique_key, $self->get_depth( ) ),
                     $p_unique_key );
}

# the data is returned as reference to an array ( key, data )

sub _read_data
{
  my ( $self, $p_path ) = @_;

  Assert_Defined( $p_path );

  my $frozen_data_ref = _Read_File_Without_Time_Modification( $p_path ) or
    return [ undef, undef ];

  return Thaw_Data( $$frozen_data_ref );
}


# the data is passed as reference to an array ( key, data )

sub _write_data
{
  my ( $self, $p_path, $p_data ) = @_;

  Assert_Defined( $p_path );
  Assert_Defined( $p_data );

  _Make_Path( $p_path, $self->get_directory_umask( ) );

  my $frozen_file = Freeze_Data( $p_data );

  _Write_File( $p_path, \$frozen_file );
}


1;


__END__

=pod

=head1 NAME

Cache::FileBackend -- a filesystem based persistance mechanism

=head1 DESCRIPTION

The FileBackend class is used to persist data to the filesystem

=head1 SYNOPSIS

  my $backend = new Cache::FileBackend( '/tmp/FileCache', 3, 000 );

  See Cache::Backend for the usage synopsis.

  $backend->store( 'namespace', 'foo', 'bar' );

  my $bar = $backend->restore( 'namespace', 'foo' );

  my $size_of_bar = $backend->get_size( 'namespace', 'foo' );

  foreach my $key ( $backend->get_keys( 'namespace' ) )
  {
    $backend->delete_key( 'namespace', $key );
  }

  foreach my $namespace ( $backend->get_namespaces( ) )
  {
    $backend->delete_namespace( $namespace );
  }

=head1 METHODS

See Cache::Backend for the API documentation.

=over

=item B<new( $root, $depth, $directory_umask )>

Construct a new FileBackend that writes data to the I<$root>
directory, automatically creates subdirectories I<$depth> levels deep,
and uses the umask of I<$directory_umask> when creating directories.

=back

=head1 PROPERTIES

=over

=item B<(get|set)_root>

The location of the parent directory in which to store the files

=item B<(get|set)_depth>

The branching factor of the subdirectories created to store the files

=item B<(get|set)_directory_umask>

The umask to be used when creating directories

=back

=head1 SEE ALSO

Cache::Backend, Cache::MemoryBackend, Cache::SharedMemoryBackend

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001, 2002 DeWitt Clinton

=cut
