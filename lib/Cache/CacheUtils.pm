######################################################################
# $Id: CacheUtils.pm,v 1.26 2001/11/07 13:10:56 dclinton Exp $
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
                     $EXPIRES_NEVER );
use Digest::MD5 qw( md5_hex );
use Error;
use Exporter;
use File::Path qw( mkpath );
use File::Spec::Functions;
use Storable qw( nfreeze thaw dclone );

@ISA = qw( Exporter );

@EXPORT_OK = qw( Assert_Defined
                 Build_Expires_At
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
  my ( $p_object, $p_time ) = @_;

  if ( not defined $p_object )
  {
    return 1;
  }

  $p_time = $p_time || time( );

  if ( $p_object->get_expires_at( ) eq $EXPIRES_NOW )
  {
    return 1;
  }
  elsif ( $p_object->get_expires_at( ) eq $EXPIRES_NEVER )
  {
    return 0;
  }
  elsif ( $p_time >= $p_object->get_expires_at( ) )
  {
    return 1;
  }
  else
  {
    return 0;
  }
}


# Take an human readable key, and create a unique key from it

sub Build_Unique_Key
{
  my ( $p_key ) = @_;

  Assert_Defined( $p_key );

  return md5_hex( $p_key );
}


# Takes the time the object was created, the default_expires_in and
# optionally the explicitly set expires_in and returns the time the
# object will expire. Calls _canonicalize_expiration to convert
# strings like "5m" into second values.

sub Build_Expires_At
{
  my ( $p_created_at, $p_default_expires_in, $p_explicit_expires_in ) = @_;

  my $expires_in = defined $p_explicit_expires_in ?
    $p_explicit_expires_in : $p_default_expires_in;

  return Sum_Expiration_Time( $p_created_at, $expires_in );
}


# Returns the sum of the  base created_at time (in seconds since the epoch)
# and the canonical form of the expires_at string


sub Sum_Expiration_Time
{
  my ( $p_created_at, $p_expires_in ) = @_;

  Assert_Defined( $p_created_at );
  Assert_Defined( $p_expires_in );

  if ( $p_expires_in eq $EXPIRES_NEVER )
  {
    return $EXPIRES_NEVER;
  }
  else
  {
    return $p_created_at + Canonicalize_Expiration_Time( $p_expires_in );
  }
}


# turn a string in the form "[number] [unit]" into an explicit number
# of seconds from the present.  E.g, "10 minutes" returns "600"

sub Canonicalize_Expiration_Time
{
  my ( $p_expires_in ) = @_;

  Assert_Defined( $p_expires_in );

  my $secs;

  if ( uc( $p_expires_in ) eq uc( $EXPIRES_NOW ) )
  {
    $secs = 0;
  }
  elsif ( uc( $p_expires_in ) eq uc( $EXPIRES_NEVER ) )
  {
    throw Error( "Internal error.  expires_in eq $EXPIRES_NEVER" );
  }
  elsif ( $p_expires_in =~ /^\s*([+-]?(?:\d+|\d*\.\d*))\s*$/ )
  {
    $secs = $p_expires_in;
  }
  elsif ( $p_expires_in =~ /^\s*([+-]?(?:\d+|\d*\.\d*))\s*(\w*)\s*$/
          and exists( $_Expiration_Units{ $2 } ))
  {
    $secs = ( $_Expiration_Units{ $2 } ) * $1;
  }
  else
  {
    throw Error( "invalid expiration time '$p_expires_in'" );
  }

  return $secs;
}



# Take a list of directory components and create a valid path

sub Build_Path
{
  my ( @p_elements ) = @_;

  if ( grep ( /\.\./, @p_elements ) )
  {
    throw Error( "Illegal path characters '..'" );
  }

  return Untaint_Path( File::Spec->catfile( @p_elements ) );
}


# create a directory with optional mask, building subdirectories as
# needed.

sub Create_Directory
{
  my ( $p_directory, $p_optional_new_umask ) = @_;

  Assert_Defined( $p_directory );

  my $old_umask = umask( ) if defined $p_optional_new_umask;

  umask( $p_optional_new_umask ) if defined $p_optional_new_umask;

  $p_directory =~ s|/$||;

  mkpath( $p_directory, 0, $DIRECTORY_MODE );

  -d $p_directory or
    throw Error( "Couldn't create directory: $p_directory: $!" );

  umask( $old_umask ) if defined $old_umask;
}


# use Storable to freeze an object

sub Freeze_Object
{
  my ( $p_object_ref, $p_frozen_object_ref  ) = @_;

  Assert_Defined( $p_object_ref );
  Assert_Defined( $p_frozen_object_ref );

  $$p_frozen_object_ref = nfreeze( $$p_object_ref ) or
    throw Error( "Couldn't freeze object" );
}


# use Storable to thaw an object

sub Thaw_Object
{
  my ( $p_frozen_object_ref, $p_object_ref ) = @_;

  Assert_Defined( $p_frozen_object_ref );
  Assert_Defined( $$p_frozen_object_ref );
  Assert_Defined( $p_object_ref );

  $$p_object_ref = thaw( $$p_frozen_object_ref );
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


# write a file atomically

sub Write_File
{
  my ( $p_filename, $p_data_ref, $p_optional_mode, $p_optional_umask ) = @_;

  Assert_Defined( $p_filename );
  Assert_Defined( $p_data_ref );

  my $old_umask = umask if $p_optional_umask;

  umask( $p_optional_umask ) if $p_optional_umask;

  my $temp_filename = "$p_filename.tmp$$";

  open( FILE, ">$temp_filename" ) or
    throw Error( "Couldn't open $temp_filename for writing: $!" );

  binmode( FILE );

  print FILE $$p_data_ref;

  close( FILE );

  rename( $temp_filename, $p_filename ) or
    throw Error( "Couldn't rename $temp_filename to $p_filename" );

  chmod( $p_optional_mode, $p_filename ) if defined $p_optional_mode;

  umask( $old_umask ) if $old_umask;
}


# read in a file. returns a reference to the data read

sub Read_File
{
  my ( $p_filename ) = @_;

  Assert_Defined( $p_filename );

  open( FILE, $p_filename ) or
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
  my ( $p_filename ) = @_;

  Assert_Defined( $p_filename );

  -e $p_filename or
    return undef;

  my ( $file_access_time, $file_modified_time ) = ( stat( $p_filename ) )[8,9];

  my $data_ref = Read_File( $p_filename );

  utime( $file_access_time, $file_modified_time, $p_filename );

  return $data_ref;
}


# remove a file

sub Remove_File
{
  my ( $p_filename ) = @_;

  Assert_Defined( $p_filename );

  if ( -f $p_filename )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    unlink( $p_filename );
  }
}



# remove a directory

sub Remove_Directory
{
  my ( $p_directory ) = @_;

  Assert_Defined( $p_directory );

  if ( -d $p_directory )
  {
    # We don't catch the error, because this may fail if two
    # processes are in a race and try to remove the object

    rmdir( $p_directory );
  }
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



# read the dirents from a directory

sub Read_Dirents
{
  my ( $p_directory ) = @_;

  Assert_Defined( $p_directory );

  opendir( DIR, $p_directory ) or
    throw Error( "Couldn't open directory $p_directory: $!" );

  my @dirents = readdir( DIR );

  closedir( DIR ) or
    throw Error( "Couldn't close directory $p_directory" );

  return @dirents;
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



# Return a Cache::Object object

sub Build_Object
{
  my ( $p_key, $p_data, $p_default_expires_in, $p_expires_in ) = @_;

  Assert_Defined( $p_key );
  Assert_Defined( $p_default_expires_in );

  my $now = time( );

  my $object = new Cache::Object( );

  $object->set_key( $p_key );
  $object->set_data( $p_data );
  $object->set_created_at( $now );
  $object->set_accessed_at( $now );
  $object->set_expires_at( Build_Expires_At( $now,
                                             $p_default_expires_in,
                                             $p_expires_in ) );
  return $object;
}


# return the OS default temp directory

sub Get_Temp_Directory
{
  my $tmpdir = File::Spec->tmpdir( ) or
    throw Error( "No tmpdir on this system.  Upgrade File::Spec?" );

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
  my ( $p_cache, $p_cache_meta_data, $p_new_size ) = @_;

  Assert_Defined( $p_cache );
  Assert_Defined( $p_cache_meta_data );
  Assert_Defined( $p_new_size );

  $p_new_size >= 0 or
    throw Error( "p_new_size >= 0 required" );

  my $size_estimate = $p_cache_meta_data->get_cache_size( );

  return if $size_estimate <= $p_new_size;

  foreach my $key ( $p_cache_meta_data->build_removal_list( ) )
  {
    $size_estimate -= $p_cache_meta_data->build_object_size( $key );

    $p_cache->remove( $key );
    $p_cache_meta_data->remove( $key );

    return if $size_estimate <= $p_new_size;
  }

  warn( "Couldn't limit size to $p_new_size" );
}


# this method takes a file path and sets the access and modification
# time of that file to the current time

sub Update_Access_Time
{
  my ( $p_path ) = @_;

  if ( not -e $p_path )
  {
    warn( "$p_path does not exist" );
  }
  else
  {
    my $now = time( );

    utime( $now, $now, $p_path );
  }
}


# throw an Exception if the Assertion fails

sub Assert_Defined
{
  if ( not defined $_[0] )
  {
    my ( $package, $filename, $line ) = caller( );
    throw Error::Simple( "Assert_Defined failed: $package line $line\n" );
  }
}

1;
