######################################################################
# $Id: CacheUtils.pm,v 1.23 2001/09/10 14:47:24 dclinton Exp $
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
use Cache::CacheMetaData;
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
use File::Spec::Functions;
use Storable qw( nfreeze thaw dclone );

@ISA = qw( Exporter );

@EXPORT_OK = qw( Build_Expires_At
                 Build_Object
                 Build_Object_Dump
                 Build_Path
                 Build_Unique_Key
                 Create_Directory
                 Freeze_Object
                 Get_Temp_Directory
                 Instantiate_Share
                 Limit_Size
                 List_Subdirectories
                 Make_Path
                 Read_File
                 Read_File_Without_Time_Modification
                 Recursive_Directory_Size
                 Recursively_List_Files
                 Recursively_List_Files_With_Paths
                 Recursively_Remove_Directory
                 Remove_File
                 Remove_Directory
                 Restore_Shared_Hash_Ref
                 Restore_Shared_Hash_Ref_With_Lock
                 Split_Word
                 Static_Params
                 Store_Shared_Hash_Ref
                 Store_Shared_Hash_Ref_And_Unlock
                 Update_Access_Time
                 Thaw_Object
                 Write_File
                 Object_Has_Expired );

use vars ( @EXPORT_OK );


# valid filepath characters for tainting. Be sure to accept
# DOS/Windows style path specifiers (C:\path) also

my $UNTAINTED_PATH_REGEX = qr{^([-\@\w\\\\~./:]+|[\w]:[-\@\w\\\\~./]+)$};


# map of expiration formats to their respective time in seconds

my %_Expiration_Units = ( map(($_,             1), qw(s second seconds sec)),
                          map(($_,            60), qw(m minute minutes min)),
                          map(($_,         60*60), qw(h hour hours)),
                          map(($_,      60*60*24), qw(d day days)),
                          map(($_,    60*60*24*7), qw(w week weeks)),
                          map(($_,   60*60*24*30), qw(M month months)),
                          map(($_,  60*60*24*365), qw(y year years)) );


# the file mode for new directories, which will be modified by the
# current umask

my $DIRECTORY_MODE = 0777;


# Compare the expires_at to the current time to determine whether or
# not an object has expired (the time parameter is optional)

sub Object_Has_Expired
{
  my ( $object, $time ) = @_;

  if ( not defined $object )
  {
    return $TRUE;
  }

  $time = $time || time( );

  my $expires_at = $object->get_expires_at( ) or
    croak( "Couldn't get expires_at" );

  if ( $expires_at eq $EXPIRES_NOW )
  {
    return $TRUE;
  }
  elsif ( $expires_at eq $EXPIRES_NEVER )
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
# object will expire. Calls _canonicalize_expiration to convert
# strings like "5m" into second values.

sub Build_Expires_At
{
  my ( $created_at, $default_expires_in, $explicit_expires_in ) = @_;

  my $expires_at;

  if ( defined $explicit_expires_in )
  {
    $expires_at = Sum_Expiration_Time( $created_at, $explicit_expires_in );
  }
  else
  {
    $expires_at = Sum_Expiration_Time( $created_at, $default_expires_in );
  }

  return $expires_at;
}


# Returns the sum of the  base created_at time (in seconds since the epoch)
# and the canonical form of the expires_at string


sub Sum_Expiration_Time
{
  my ( $created_at, $expires_in ) = @_;

  defined $created_at or
    croak( "created_at required" );

  defined $expires_in or
    croak( "expires_in required" );

  my $expires_at;

  if ( $expires_in eq $EXPIRES_NEVER )
  {
    $expires_at = $EXPIRES_NEVER;
  }
  else
  {
    my $canonical_expires_in = Canonicalize_Expiration_Time( $expires_in );

    $expires_at = $created_at + $canonical_expires_in;
  }

  return $expires_at;
}


# turn a string in the form "[number] [unit]" into an explicit number
# of seconds from the present.  E.g, "10 minutes" returns "600"

sub Canonicalize_Expiration_Time
{
  my ( $expires_in ) = @_;

  defined $expires_in or
    croak( "expires_in required" );

  my $secs;

  if ( uc( $expires_in ) eq uc( $EXPIRES_NOW ) )
  {
    $secs = 0;
  }
  elsif ( uc( $expires_in ) eq uc( $EXPIRES_NEVER ) )
  {
    croak( "Internal error.  expires_in eq $EXPIRES_NEVER" );
  }
  elsif ( $expires_in =~ /^\s*([+-]?(?:\d+|\d*\.\d*))\s*$/ )
  {
    $secs = $expires_in;
  }
  elsif ( $expires_in =~ /^\s*([+-]?(?:\d+|\d*\.\d*))\s*(\w*)\s*$/
          and exists( $_Expiration_Units{ $2 } ))
  {
    $secs = ( $_Expiration_Units{ $2 } ) * $1;
  }
  else
  {
    croak( "invalid expiration time '$expires_in'" );
  }

  return $secs;
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

  my @directories = File::Spec->splitdir( $directory );

  pop @directories;

  return undef unless @directories;

  my $parent_directory = File::Spec->catdir( @directories );

  return $parent_directory;
}



# create a directory with optional mask, building subdirectories as
# needed.

sub Create_Directory
{
  my ( $directory, $optional_new_umask ) = @_;

  defined( $directory ) or
    croak( "directory required" );

  my $old_umask = umask( ) if defined $optional_new_umask;

  umask( $optional_new_umask ) if defined $optional_new_umask;

  $directory =~ s|/$||;

  mkpath( $directory, 0, $DIRECTORY_MODE );

  -d $directory or
    croak( "Couldn't create directory: $directory: $!" );

  umask( $old_umask ) if defined $old_umask;

  return $SUCCESS;
}


# use Storable to freeze an object

sub Freeze_Object
{
  my ( $object_ref, $frozen_object_ref  ) = @_;

  $$frozen_object_ref = nfreeze( $$object_ref ) or
    croak( "Couldn't freeze object" );

  return $SUCCESS;
}


# use Storable to thaw an object

sub Thaw_Object
{
  my ( $frozen_object_ref, $object_ref ) = @_;

  $$object_ref = thaw( $$frozen_object_ref );

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


# create a directory with the optional umask if it doesn't already
# exist

sub Make_Path
{
  my ( $path, $optional_new_umask ) = @_;

  my ( $volume, $directory, $filename ) = File::Spec->splitpath( $path );

  return $SUCCESS unless $directory;

  return $SUCCESS if -d $directory;

  Create_Directory( $directory, $optional_new_umask ) or
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


# read in a file. returns a reference to the data read, without
# modifying the last accessed time

sub Read_File_Without_Time_Modification
{
  my ( $filename ) = @_;

  defined( $filename ) or
    croak( "filename required" );

  -e $filename or
    return undef;

  my ( $file_access_time, $file_modified_time ) = ( stat( $filename ) )[8,9];

  my $data_ref = Read_File( $filename );

  utime( $file_access_time, $file_modified_time, $filename );

  return $data_ref;
}


# remove a file

sub Remove_File
{
  my ( $filename ) = @_;

  defined( $filename ) or
    croak( "directory required" );

  if ( -f $filename )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    unlink( $filename );
  }

  return $SUCCESS;
}



# remove a directory

sub Remove_Directory
{
  my ( $directory ) = @_;

  defined( $directory ) or
    croak( "directory required" );

  if ( -d $directory )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    rmdir( $directory );
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

  return $SUCCESS unless -d $directory;

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



# recursively list the files of the subdirectories, without the full paths

sub Recursively_List_Files_With_Paths
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
      Recursively_List_Files_With_Paths( $path, $files_ref ) or
        croak( "Couldn't recursively list files at $path" );
    }
    else
    {
      push( @$files_ref, $path );
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

      Remove_File( $untainted_path_to_dirent ) or
        croak( "Couldn't Remove_File( $untainted_path_to_dirent ): $!\n" );
    }
  }

  my $untainted_root = Untaint_Path( $root ) or
    croak( "Couldn't untain root" );

  Remove_Directory( $untainted_root ) or
    croak( "Couldn't Remove_Directory( $untainted_root ): $!" );

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

  $object->set_accessed_at( $created_at );

  return $object;
}


# return the OS default temp directory

sub Get_Temp_Directory
{
  my $tmpdir = File::Spec->tmpdir( ) or
    croak( "No tmpdir on this system.  Bugs to the authors of File::Spec" );

  return $tmpdir;
}


# Take a parameter list and automatically shift it such that if
# the method was called as a static method, then $self will be
# undefined.  This allows the use to write
#
#   sub Static_Method
#   {
#     my ( $parameter ) = Static_Params( @_ );
#   }
#
# and not worry about whether it is called as:
#
#   Class->Static_Method( $param );
#
# or
#
#   Class::Static_Method( $param );


sub Static_Params
{
  my $type = ref $_[0];

  if ( $type and ( $type !~ /^(SCALAR|ARRAY|HASH|CODE|REF|GLOB|LVALUE)$/ ) )
  {
    shift( @_ );
  }

  return @_;
}


# take a Cache reference and a CacheMetaData reference and
# limit the cache's size to new_size

sub Limit_Size
{
  my ( $cache, $cache_meta_data, $new_size ) = @_;

  defined $cache or
    croak( "cache required" );

  defined $cache_meta_data or
    croak( "cache_meta_data required" );

  defined $new_size or
    croak( "new_size required" );

  $new_size >= 0 or
    croak( "size >= 0 required" );

  my $current_size = $cache_meta_data->get_cache_size( );

  return $SUCCESS if ( $current_size <= $new_size );

  my @removal_list;

  $cache_meta_data->build_removal_list( \@removal_list ) or
    croak( "Couldn't build removal list" );

  foreach my $identifier ( @removal_list )
  {
    my $object_size = $cache_meta_data->build_object_size( $identifier ) or
      croak( "Couldn't build object size" );

    $cache->remove( $identifier ) or
      croak( "Couldn't remove identifier" );

    $cache_meta_data->remove( $identifier ) or
      croak( "Couldn't remove identifier from cache_meta_data" );

    $current_size -= $object_size;

    return $SUCCESS if ( $current_size <= $new_size );
  }

  warn("Couldn't limit size to $new_size\n");

  return $FAILURE;
}


# this method takes a file path and sets the access and modification
# time of that file to the current time

sub Update_Access_Time
{
  my ( $path ) = @_;

  if ( not -e $path )
  {
    warn( "$path does not exist" );
  }
  else
  {
    my $now = time( );

    utime( $now, $now, $path );
  }

  return $SUCCESS;
}


1;
