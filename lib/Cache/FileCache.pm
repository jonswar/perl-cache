######################################################################
# $Id: FileCache.pm,v 1.23 2001/11/24 21:12:43 dclinton Exp $
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
use Cache::FileBackend;
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

  foreach my $namespace ( _Namespaces( $p_optional_cache_root ) )
  {
    # TODO:  This is broken -- try changing the root!
    my $cache = new Cache::FileCache( { 'namespace' => $namespace } );
    $cache->clear( );
  }
}


sub Purge
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  foreach my $namespace ( _Namespaces( $p_optional_cache_root ) )
  {
    # TODO:  This is broken -- try changing the root!
    my $cache = new Cache::FileCache( { 'namespace' => $namespace } );
    $cache->purge( );
  }
}


sub Size
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  my $size = 0;

  foreach my $namespace ( _Namespaces( $p_optional_cache_root ) )
  {
    # TODO:  This is broken -- try changing the root!
    my $cache = new Cache::FileCache( { 'namespace' => $namespace } );
    $size += $cache->size( );
  }

  return $size;
}



##
# Private class methods
##


sub _Get_Backend
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  return new Cache::FileBackend( _Build_Cache_Root( $p_optional_cache_root ) );

}


sub _Build_Cache_Root
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  return defined $p_optional_cache_root ?
    $p_optional_cache_root :
      Build_Path( Get_Temp_Directory( ), $DEFAULT_CACHE_ROOT );
}


sub _Namespaces
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  return _Get_Backend( $p_optional_cache_root )->get_namespaces( );
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

  $self->_get_backend( )->delete_namespace( $self->get_namespace( ) );
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

  return $object->get_data( );
}


sub get_object
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  return $self->_get_backend( )->restore( $self->get_namespace( ), $p_key );
}


sub remove
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  $self->_get_backend( )->delete_key( $self->get_namespace( ), $p_key );
}


sub set
{
  my ( $self, $p_key, $p_data, $p_expires_in ) = @_;

  Assert_Defined( $p_key );

  $self->_conditionally_auto_purge_on_set( );

  $self->set_object( $p_key,
                     Build_Object( $p_key,
                                   $p_data,
                                   $self->get_default_expires_in( ),
                                   $p_expires_in ) );
}


sub set_object
{
  my ( $self, $p_key, $p_object ) = @_;

  $self->_get_backend( )->store( $self->get_namespace( ),
                                 $p_key,
                                 $p_object );
}


sub size
{
  my ( $self ) = @_;

  my $size = 0;

  foreach my $key ( $self->get_keys( ) )
  {
    $size += 
      $self->_get_backend( )->get_object_size( $self->get_namespace( ), $key );
  }

  return $size;
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

  $self->_initialize_file_backend( );
}


sub _initialize_file_backend
{
  my ( $self ) = @_;

  $self->_set_backend( new Cache::FileBackend( $self->_get_initial_root( ),
                                               $self->_get_initial_depth( ),
                                               $self->_get_initial_umask( ) ));
}


sub _get_initial_root
{
  my ( $self ) = @_;

  if ( defined $self->_read_option( 'cache_root' ) )
  {
    return $self->_read_option( 'cache_root' );
  }
  else
  {
    return Build_Path( Get_Temp_Directory( ), $DEFAULT_CACHE_ROOT );
  }
}


sub _get_initial_depth
{
  my ( $self ) = @_;

  return $self->_read_option( 'cache_depth', $DEFAULT_CACHE_DEPTH );
}


sub _get_initial_umask
{
  my ( $self ) = @_;

  return $self->_read_option( 'directory_umask', $DEFAULT_DIRECTORY_UMASK );
}


##
# Instance properties
##


sub get_cache_depth
{
  my ( $self ) = @_;

  return $self->_get_backend( )->get_depth( );
}


sub set_cache_depth
{
  my ( $self, $p_cache_depth ) = @_;

  $self->_get_backend( )->set_depth( $p_cache_depth );
}


sub get_cache_root
{
  my ( $self ) = @_;

  return $self->_get_backend( )->get_root( );
}


sub set_cache_root
{
  my ( $self, $p_cache_root ) = @_;

  $self->_get_backend( )->set_root( $p_cache_root );
}


sub get_directory_umask
{
  my ( $self ) = @_;

  return $self->_get_backend( )->get_directory_umask( );
}


sub set_directory_umask
{
  my ( $self, $p_directory_umask ) = @_;

  $self->_get_backend( )->set_directory_umask( $p_directory_umask );
}



sub get_keys
{
  my ( $self ) = @_;

  return $self->_get_backend->get_keys( $self->get_namespace( ) );
}



sub _get_backend
{
  my ( $self ) = @_;

  return $self->{ _Backend };
}


sub _set_backend
{
  my ( $self, $p_backend ) = @_;

  $self->{ _Backend } = $p_backend;
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
