######################################################################
# $Id: FileCache.pm,v 1.20 2001/11/06 23:44:08 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::FileCache;


use strict;
use vars qw( @ISA );
use Cache::BaseCache;
use Cache::Cache;
use Cache::CacheUtils qw ( Assert_Defined
                           Build_Object
                           Build_Path
                           Build_Unique_Key
                           Create_Directory
                           Get_Temp_Directory
                           List_Subdirectories
                           Make_Path
                           Object_Has_Expired
                           Read_File_Without_Time_Modification
                           Recursive_Directory_Size
                           Recursively_List_Files
                           Recursively_Remove_Directory
                           Remove_File
                           Split_Word
                           Static_Params
                           Update_Access_Time
                           Write_File );
use Cache::Object;
use Error;

@ISA = qw ( Cache::BaseCache );


# by default, the cache nests all entries on the filesystem three
# directories deep

my $DEFAULT_CACHE_DEPTH = 3;


# by default, the root of the cache is located in 'FileCache'.  On a
# UNIX system, this will appear in "/tmp/FileCache/"

my $DEFAULT_CACHE_ROOT = "FileCache";


# by, default, the directories in the cache on the filesystem should
# be globally writable to allow for multiple users.  While this is a
# potential security concern, the actual cache entries are written
# with the user's umask, thus reducing the risk of cache poisoning

my $DEFAULT_DIRECTORY_UMASK = 000;


##
# Public class methods
##


sub Clear
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  Recursively_Remove_Directory( _Build_Cache_Root( $p_optional_cache_root ) );
}


# TODO: It would be more effecient to iterate over the list of cached
# objects and purge them individually


sub Purge
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  foreach my $namespace ( _List_Namespaces( $p_optional_cache_root ) )
  {
    my $cache = new Cache::FileCache( { 'namespace' => $namespace } );

    $cache->purge( );
  }
}


sub Size
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  return Recursive_Directory_Size( _Build_Cache_Root($p_optional_cache_root) );
}



##
# Private class methods
##


sub _Build_Cache_Root
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  return defined $p_optional_cache_root ?
    $p_optional_cache_root :
      Build_Path( Get_Temp_Directory( ), $DEFAULT_CACHE_ROOT );
}


sub _List_Namespaces
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  my @namespaces;

  List_Subdirectories( _Build_Cache_Root( $p_optional_cache_root ), 
                       \@namespaces );

  return @namespaces;
}


##
# Constructor
##


sub new
{
  my ( $self ) = _new( @_ );

  $self->_complete_initialization( );

  return $self;
}


##
# Public instance methods
##


sub clear
{
  my ( $self ) = @_;

  Recursively_Remove_Directory( $self->_build_namespace_path( ) );
}


sub get
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  $self->_conditionally_auto_purge_on_get( );

  my $object = $self->get_object( $p_key ) or
    return undef;

  if ( Object_Has_Expired( $object ) )
  {
    $self->remove( $p_key );
    return undef;
  }

  $self->_update_access_time( $p_key );

  return $object->get_data( );
}


sub get_object
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  return $self->_restore( Build_Unique_Key( $p_key ) );
}


sub purge
{
  my ( $self ) = @_;

  foreach my $unique_key ( $self->_list_unique_keys( ) )
  {
    my $object = $self->_restore( $unique_key ) or
      next;

    if ( Object_Has_Expired( $object ) )
    {
      $self->remove( $object->get_key( ) );
    }
  }
}


sub remove
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  Remove_File( $self->_build_object_path( Build_Unique_Key($p_key) ) );
}


sub set
{
  my ( $self, $p_key, $p_data, $p_expires_in ) = @_;

  $self->_conditionally_auto_purge_on_set( );

  $self->_store( Build_Unique_Key( $p_key ),
                 Build_Object( $p_key,
                               $p_data,
                               $self->get_default_expires_in( ),
                               $p_expires_in ) );
}


sub set_object
{
  my ( $self, $p_key, $p_object ) = @_;

  $self->_store( Build_Unique_Key( $p_key ), $p_object );
}


sub size
{
  my ( $self ) = @_;

  return Recursive_Directory_Size( $self->_build_namespace_path( ) );
}


##
# Private instance methods
##


sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;

  my $self  =  $class->SUPER::_new( $p_options_hash_ref );

  $self->_initialize_file_cache( );

  return $self;
}


sub _initialize_file_cache
{
  my ( $self ) = @_;

  $self->_initialize_cache_depth( );
  $self->_initialize_cache_root( );
  $self->_initialize_directory_umask( );
}


sub _initialize_cache_depth
{
  my ( $self ) = @_;

  $self->set_cache_depth( $self->_read_option( 'cache_depth',
                                               $DEFAULT_CACHE_DEPTH ) );
}


sub _initialize_cache_root
{
  my ( $self ) = @_;

  $self->set_cache_root(_Build_Cache_Root($self->_read_option('cache_root')));
}


sub _initialize_directory_umask
{
  my ( $self ) = @_;

  $self->set_directory_umask( $self->_read_option( 'directory_umask',
                                                   $DEFAULT_DIRECTORY_UMASK ));

}


sub _store
{
  my ( $self, $p_unique_key, $p_object ) = @_;

  Assert_Defined( $p_unique_key );

  Make_Path( $self->_build_object_path( $p_unique_key ),
             $self->get_directory_umask( ) );

  Write_File( $self->_build_object_path( $p_unique_key ),
              \$self->_freeze( $p_object ) );
}


sub _restore
{
  my ( $self, $p_unique_key ) = @_;

  Assert_Defined( $p_unique_key );

  my $object_path = $self->_build_object_path( $p_unique_key );

  my $object_dump_ref = Read_File_Without_Time_Modification( $object_path ) or
    return undef;

  my $object = $self->_thaw( $object_dump_ref );

  $object->set_accessed_at( $self->_get_atime( $object_path ) );

  return $object;
}


sub _get_atime
{
  my ( $self, $p_path ) = @_;

  return ( stat( $p_path ) )[8];
}


sub _build_object_path
{
  my ( $self, $p_unique_key ) = @_;

  Assert_Defined( $p_unique_key );

  ( $p_unique_key !~ m|[0-9][a-f][A-F]| ) or
    throw Error( "unique_key '$p_unique_key' contains illegal characters'" );

  return Build_Path( $self->get_cache_root( ),
                     $self->get_namespace( ),
                     Split_Word( $p_unique_key, $self->get_cache_depth( ) ),
                     $p_unique_key );
}


sub _build_namespace_path
{
  my ( $self ) = @_;

  return Build_Path( $self->get_cache_root( ), $self->get_namespace( ) );
}


sub _list_unique_keys
{
  my ( $self ) = @_;

  my @unique_keys;

  Recursively_List_Files( $self->_build_namespace_path( ), \@unique_keys );

  return @unique_keys;
}


sub _update_access_time
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  Update_Access_Time( $self->_build_object_path( Build_Unique_Key($p_key) ) );
}


##
# Instance properties
##


sub get_cache_depth
{
  my ( $self ) = @_;

  return $self->{_Cache_Depth};
}

sub set_cache_depth
{
  my ( $self, $cache_depth ) = @_;

  $self->{_Cache_Depth} = $cache_depth;
}


sub get_cache_root
{
  my ( $self ) = @_;

  return $self->{_Cache_Root};
}


sub set_cache_root
{
  my ( $self, $cache_root ) = @_;

  $self->{_Cache_Root} = $cache_root;
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


sub get_keys
{
  my ( $self ) = @_;

  my @keys;

  foreach my $unique_key ( $self->_list_unique_keys( ) )
  {
    my $object = $self->_restore( $unique_key ) or
      next;

    push( @keys, $object->get_key( ) );
  }

  return @keys;
}


1;


__END__

=pod

=head1 NAME

Cache::FileCache -- implements the Cache interface.

=head1 DESCRIPTION

The FileCache class implements the Cache interface.  This cache stores
data in the filesystem so that it can be shared between processes.

=head1 SYNOPSIS

  use Cache::FileCache;

  my %cache_options = ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600 );

  my $file_cache = new Cache::FileCache( \%cache_options ) or
    croak( "Couldn't instantiate FileCache" );

=head1 METHODS

=over 4

=item B<Clear( $optional_cache_root )>

See Cache::Cache

=over 4

=item $optional_cache_root

If specified, this indicates the root on the filesystem of the cache
to be cleared.

=back

=item B<Purge( $optional_cache_root )>

See Cache::Cache

=over 4

=item $optional_cache_root

If specified, this indicates the root on the filesystem of the cache
to be purged.

=back

=item B<Size( $optional_cache_root )>

See Cache::Cache

=over 4

=item $optional_cache_root

If specified, this indicates the root on the filesystem of the cache
to be sized.

=back

=item B<new( $options_hash_ref )>

Constructs a new FileCache.

=over 4

=item $options_hash_ref

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=back

=item B<clear(  )>

See Cache::Cache

=item B<get( $key )>

See Cache::Cache

=item B<get_object( $key )>

See Cache::Cache

=item B<purge( )>

See Cache::Cache

=item B<remove( $key )>

See Cache::Cache

=item B<set( $key, $data, $expires_in )>

See Cache::Cache

=item B<size(  )>

See Cache::Cache

=back

=head1 OPTIONS

See Cache::Cache for standard options.  Additionally, options are set
by passing in a reference to a hash containing any of the following
keys:

=over 4

=item cache_root

The location in the filesystem that will hold the root of the cache.
Defaults to the 'FileCache' under the OS default temp directory (
often '/tmp' on UNIXes ) unless explicitly set.

=item cache_depth

The number of subdirectories deep to cache object item.  This should
be large enough that no cache directory has more than a few hundred
objects.  Defaults to 3 unless explicitly set.

=item directory_umask

The directories in the cache on the filesystem should be globally
writable to allow for multiple users.  While this is a potential
security concern, the actual cache entries are written with the user's
umask, thus reducing the risk of cache poisoning.  If you desire it to
only be user writable, set the 'directory_umask' option to '077' or
similar.  Defaults to '000' unless explicitly set.


=back

=head1 PROPERTIES

See Cache::Cache for default properties.

=over 4

=item B<(get|set)_cache_root>

The root on the filesystem of this cache.

=item B<(get|set)_cache_depth>

The number of subdirectories deep to cache each object.

=item B<(get|set)_directory_umask>

The directories in the cache on the filesystem should be globally
writable to allow for multiple users.  While this is a potential
security concern, the actual cache entries are written with the user's
umask, thus reducing the risk of cache poisoning.  If you desire it to
only be user writable, set the 'directory_umask' option to '077' or
similar.

=item B<get_keys>

The list of keys specifying objects in the namespace associated
with this cache instance.  For FileCache implementations, the
get_keys routine must actual examine each stored item in the
cache, and it is therefore an expensive operation.

=back

=head1 SEE ALSO

Cache::Cache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
