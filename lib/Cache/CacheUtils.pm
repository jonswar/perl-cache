######################################################################
# $Id:  $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::CacheUtils;

use strict;
use vars qw( @ISA @EXPORT_OK );
use Cache::Cache qw( $EXPIRES_NOW
                     $EXPIRES_NEVER
                     $TRUE
                     $FALSE
                     $SUCCESS
                     $FAILURE );
use Carp;
use Digest::MD5 qw( md5_hex );
use Exporter;
use File::Path qw( mkpath );
use File::Spec::Functions qw( catfile splitdir splitpath catdir );

@ISA = qw( Exporter );

@EXPORT_OK = qw( Object_Has_Expired
                 Build_Expires_At
                 Build_Object
                 Split_Word
                 Build_Unique_Key
                 Write_File
                 Remove_File
                 Recursive_Directory_Size
                 Recursively_Remove_Directory
                 Recursively_List_Files
                 List_Subdirectories
                 Read_File
                 Build_Path
                 Make_Path );

use vars ( @EXPORT_OK );


my $UNTAINTED_PATH_REGEX = qr{^([-\@\w\\\\~./:]+|[\w]:[-\@\w\\\\~./]+)$};


# Compare the expires_at to the current time to determine whether or
# not an object has expired (the time parameter is optional)

sub Object_Has_Expired
{
  my ( $object, $time ) = @_;

  $time = $time || time( );

  my $expires_at = $object->get_expires_at( ) or
    croak( "Couldn't get expires_at" );

  if ( $expires_at == $EXPIRES_NOW )
  {
    return $TRUE;
  }
  elsif ( $expires_at == $EXPIRES_NEVER )
  {
    return $FALSE;
  }
  elsif ( $time >= $expires_at )
  {
    return $TRUE;
  }
  else
  {
    return $FALSE;
  }
}


# Take an human readable identifier, and create a unique key from it

sub Build_Unique_Key
{
  my ( $identifier ) = @_;

  defined( $identifier ) or
    croak( "identifier required" );

  my $unique_key = md5_hex( $identifier ) or
    croak( "couldn't build unique key for identifier $identifier" );

  return $unique_key;
}


# Takes the time the object was created, the default_expires_in and
# optionally the explicitly set expires_in and returns the time the
# object will expire.

sub Build_Expires_At
{
  my ( $created_at, $default_expires_in, $explicit_expires_in ) = @_;

  if ( defined $explicit_expires_in )
  {
    return( $created_at + $explicit_expires_in );
  }
  elsif ( $default_expires_in ne $EXPIRES_NEVER )
  {
    return( $created_at + $default_expires_in );
  }
  else
  {
    return( $EXPIRES_NEVER );
  }
}



# Take a list of directory components and create a valid path

sub Build_Path
{
  my ( @elements ) = @_;

  if ( grep ( /\.\./, @elements ) )
  {
    croak( "Illegal path characters '..'" );
  }

  my $path = File::Spec->catfile( @elements );

  return $path;
}




# Check to see if a directory exists and is writable, or if a prefix
# directory exists and we can write to it in order to create
# subdirectories.

sub Verify_Directory
{
  my ( $directory ) = @_;

  defined( $directory ) or
    croak( "directory required" );

  # If the directory doesn't exist, crawl upwards until we find a file or
  # directory that exists

  while ( defined $directory and not -e $directory )
  {
    $directory = Extract_Parent_Directory( $directory );
  }

  defined $directory or
    croak( "parent directory undefined" );

  -d $directory or
    croak( "path '$directory' is not a directory" );

  -w $directory or
    croak( "path '$directory' is not writable" );

  return $SUCCESS;
}


# find the parent directory of a directory. Returns undef if there is
# no parent

sub Extract_Parent_Directory
{
  my ( $directory ) = @_;

  defined( $directory ) or
    croak( "directory required" );

  my @directories = splitdir( $directory );

  pop @directories;

  return undef unless @directories;

  my $parent_directory = catdir( @directories );

  return $parent_directory;
}



# create a directory with optional mask, building subdirectories as
# needed.

sub Create_Directory
{
  my ( $directory, $optional_new_umask ) = @_;

  defined( $directory ) or
    croak( "directory required" );

  my $old_umask = umask if defined $optional_new_umask;

  umask( $optional_new_umask ) if defined $optional_new_umask;

  mkpath( $directory, 0, 0777 );

  -d $directory or
    croak( "Couldn't create directory: $directory: $!" );

  umask( $old_umask ) if defined $old_umask;

  return $SUCCESS;
}


# return a list of the first $depth letters in the $word

sub Split_Word
{
  my ( $word, $depth, $split_word_list_ref ) = @_;

  defined $word or
    croak( "word required" );

  defined $depth or
    croak( "depth required" );

  my @list;

  for ( my $i = 0; $i < $depth; $i++ )
  {
    push ( @$split_word_list_ref, substr( $word, $i, 1 ) );
  }

  return $SUCCESS;
}



sub Make_Path
{
  my ( $path ) = @_;

  my ( $volume, $directory, $filename ) = splitpath( $path );

  return $SUCCESS unless $directory;

  return $SUCCESS if -d $directory;

  Create_Directory( $directory ) or
    croak( "Couldn't create directory $directory" );

  return $SUCCESS;
}

# write a file atomically

sub Write_File
{
  my ( $filename, $data_ref, $optional_mode, $optional_new_umask ) = @_;

  defined( $filename ) or
    croak( "filename required" );

  defined( $data_ref ) or
    croak( "data reference required" );

  # Change the umask if necessary

  my $old_umask = umask if $optional_new_umask;

  umask( $optional_new_umask ) if $optional_new_umask;

  # Create a temp filename

  my $temp_filename = "$filename.tmp$$";

  open( FILE, ">$temp_filename" ) or
    croak( "Couldn't open $temp_filename for writing: $!\n" );

  # Use binmode in case the user stores binary data

  binmode( FILE );

  chmod( $optional_mode, $filename ) if defined $optional_mode;

  print FILE $$data_ref;

  close( FILE );

  rename( $temp_filename, $filename ) or
    croak( "Couldn't rename $temp_filename to $filename" );

  umask( $old_umask ) if $old_umask;

  return $SUCCESS;
}


# read in a file. returns a reference to the data read

sub Read_File
{
  my ( $filename ) = @_;

  my $data_ref;

  defined( $filename ) or
    croak( "filename required" );

  open( FILE, $filename ) or
    return undef;

  # In case the user stores binary data

  binmode( FILE );

  local $/ = undef;

  $$data_ref = <FILE>;

  close( FILE );

  return $data_ref;
}


# remove a file

sub Remove_File
{
  my ( $filename ) = @_;

  defined( $filename ) or
    croak( "path required" );

  if ( -f $filename )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    unlink( $filename );
  }

  return $SUCCESS;
}


# list the names of the subdirectories in a given directory, without the
# full path

sub List_Subdirectories
{
  my ( $directory, $subdirectories_ref ) = @_;

  opendir( DIR, $directory ) or
    croak( "Couldn't open directory $directory: $!" );

  my @dirents = readdir( DIR );

  closedir( DIR ) or
    croak( "Couldn't close directory $directory" );

  foreach my $dirent ( @dirents )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $directory, $dirent );

    next unless -d $path;

    push( @$subdirectories_ref, $dirent );
  }

  return $SUCCESS;
}


# recursively list the files of the subdirectories, without the full paths

sub Recursively_List_Files
{
  my ( $directory, $files_ref ) = @_;

  opendir( DIR, $directory ) or
    croak( "Couldn't open directory $directory: $!" );

  my @dirents = readdir( DIR );

  closedir( DIR ) or
    croak( "Couldn't close directory $directory" );

  my @files;

  foreach my $dirent ( @dirents )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $directory, $dirent );

    if ( -d $path )
    {
      Recursively_List_Files( $path, $files_ref ) or
        croak( "Couldn't recursively list files at $path" );
    }
    else
    {
      push( @$files_ref, $dirent );
    }
  }

  return $SUCCESS;
}


# remove a directory and all subdirectories and files

sub Recursively_Remove_Directory
{
  my ( $root ) = @_;

  -d $root or
    return $SUCCESS;

  opendir( DIR, $root ) or
    croak( "Couldn't open directory $root: $!" );

  my @dirents = readdir( DIR );

  closedir( DIR ) or
    croak( "Couldn't close directory $root: $!" );

  foreach my $dirent ( @dirents )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path_to_dirent = "$root/$dirent";

    if ( -d $path_to_dirent )
    {
      Recursively_Remove_Directory( $path_to_dirent );
    }
    else
    {
      my $untainted_path_to_dirent = Untaint_Path( $path_to_dirent );

      unlink( $untainted_path_to_dirent ) or
        croak( "Couldn't unlink( $untainted_path_to_dirent ): $!\n" );
    }
  }

  my $untainted_root = Untaint_Path( $root ) or
    croak( "Couldn't untain root" );

  rmdir( $untainted_root ) or
    croak( "Couldn't rmdir $untainted_root: $!" );

  return $SUCCESS;
}



# walk down a directory structure and total the size of the files
# contained therein.

sub Recursive_Directory_Size
{
  my ( $directory ) = @_;

  defined( $directory ) or
    croak( "directory required" );

  my $size = 0;

  -d $directory or
    return 0;

  opendir( DIR, $directory ) or
    croak( "Couldn't opendir '$directory': $!" );

  my @dirents = readdir( DIR );

  closedir( DIR );

  foreach my $dirent ( @dirents )
  {
    next if $dirent eq '.' or $dirent eq '..';

    my $path = Build_Path( $directory, $dirent );

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
  my ( $path ) = @_;

  return Untaint_String( $path, $UNTAINTED_PATH_REGEX );
}

# Untaint a string

sub Untaint_String
{
  my ( $string, $untainted_regex ) = @_;

  defined( $untainted_regex ) or
    croak( "untainted regex required" );

  defined( $string ) or
    croak( "string required" );

  my ( $untainted_string ) = $string =~ /$untainted_regex/;

  if ( not defined $untainted_string || $untainted_string ne $string )
  {
    warn( "String $string contains possible taint" );
  }

  return $untainted_string;
}



# Return a Cache::Object object

sub Build_Object
{
  my ( $identifier, $data, $default_expires_in, $expires_in ) = @_;

  $identifier or
    croak( "identifier required" );

  defined $default_expires_in or
    croak( "default_expires_in required" );

  my $object = new Cache::Object( ) or
    croak( "Couldn't construct new cache object" );

  $object->set_identifier( $identifier );

  $object->set_data( $data );

  my $created_at = time( ) or
    croak( "Couldn't get time" );

  $object->set_created_at( $created_at );

  my $expires_at =
    Build_Expires_At( $created_at, $default_expires_in, $expires_in ) or
      croak( "Couldn't build expires at" );

  $object->set_expires_at( $expires_at );

  return $object;
}


1;
