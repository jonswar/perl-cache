######################################################################
# $Id: FileCache.pm,v 1.8 2001/03/06 17:02:01 dclinton Exp $
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
use Cache::Cache qw( $EXPIRES_NEVER $SUCCESS $FAILURE $TRUE $FALSE );
use Cache::CacheUtils qw ( Build_Object
                           Build_Path
                           Build_Unique_Key
                           Get_Temp_Directory
                           List_Subdirectories
                           Make_Path
                           Object_Has_Expired
                           Read_File
                           Recursive_Directory_Size
                           Recursively_List_Files
                           Recursively_Remove_Directory
                           Remove_File
                           Split_Word
                           Static_Params
                           Write_File );
use Cache::Object;
use Carp;
use Data::Dumper;


@ISA = qw ( Cache::BaseCache );


my $DEFAULT_CACHE_DEPTH = 3;
my $DEFAULT_CACHE_ROOT = "FileCache";



##
# Public class methods
##


sub Clear
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  my $cache_root = _Build_Cache_Root( $optional_cache_root ) or
    croak( "Couldn't build cache root" );

  Recursively_Remove_Directory( $cache_root ) or
    croak( "Couldn't remove $cache_root" );

  return $SUCCESS;
}


# TODO: It would be more effecient to iterate over the list of cached
# objects and purge them individually


sub Purge
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  my @namespaces;

  _List_Namespaces( \@namespaces, $optional_cache_root ) or
    croak( "Couldn't list namespaces" );

  foreach my $namespace ( @namespaces )
  {
    my $cache = new Cache::FileCache( { 'namespace' => $namespace } ) or
      croak( "Couldn't construct cache with namespace $namespace" );

    $cache->purge( ) or
      croak( "Couldn't purge cache with namespace $namespace" );
  }

  return $SUCCESS;
}


sub Size
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  my $cache_root = _Build_Cache_Root( $optional_cache_root ) or
    croak( "Couldn't build cache root" );

  my $size = Recursive_Directory_Size( $cache_root );

  return $size;
}


##
# Private class methods
##


sub _Build_Cache_Root
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  my $cache_root;

  if ( defined $optional_cache_root )
  {
    $cache_root = $optional_cache_root;
  }
  else
  {
    my $tmpdir = Get_Temp_Directory( ) or
      croak( "Couldn't get temp directory" );

    $cache_root = Build_Path( $tmpdir, $DEFAULT_CACHE_ROOT ) or
      croak( "Couldn't build cache root" );
  }

  return $cache_root;
}


sub _List_Namespaces
{
  my ( $namespaces_ref, $optional_cache_root ) = Static_Params( @_ );

  my $cache_root = _Build_Cache_Root( $optional_cache_root ) or
    croak( "Couldn't build cache root" );

  List_Subdirectories( $cache_root, $namespaces_ref ) or
    croak( "Couldn't list subdirectories of $cache_root" );

  return $SUCCESS;
}


##
# Constructor
##


sub new
{
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;

  my $self  =  $class->SUPER::new( $options_hash_ref ) or
    croak( "Couldn't run super constructor" );

  $self->_initialize_file_cache( ) or
    croak( "Couldn't initialize Cache::FileCache" );

  return $self;
}


##
# Public instance methods
##


sub clear
{
  my ( $self ) = @_;

  my $namespace_path = $self->_build_namespace_path( ) or
    croak( "Couldn't build namespace path" );

  Recursively_Remove_Directory( $namespace_path ) or
    croak( "Couldn't remove $namespace_path" );

  return $SUCCESS;
}


sub get
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $object = $self->get_object( $identifier ) or
    return undef;

  my $has_expired = Object_Has_Expired( $object );

  if ( $has_expired eq $TRUE )
  {
    $self->remove( $identifier ) or
      croak( "Couldn't remove object $identifier" );

    return undef;
  }

  return $object->get_data( );
}


sub get_object
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $unique_key = Build_Unique_Key( $identifier ) or
    croak( "Couldn't build unique key" );

  my $object = $self->_restore( $unique_key ) or
    return undef;

  return $object;
}


sub purge
{
  my ( $self ) = @_;

  my @unique_keys;

  $self->_list_unique_keys( \@unique_keys ) or
    croak( "Couldn't list unique keys" );

  foreach my $unique_key ( @unique_keys )
  {
    my $object = $self->_restore( $unique_key );

    my $has_expired = Object_Has_Expired( $object );

    if ( $has_expired eq $TRUE )
    {
      my $identifier = $object->get_identifier( );

      $self->remove( $identifier ) or
        croak( "Couldn't remove object $identifier" );
    }
  }

  return $SUCCESS;
}


sub remove
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $unique_key = Build_Unique_Key( $identifier ) or
    croak( "Couldn't build unique key" );

  my $object_path = $self->_build_object_path( $unique_key ) or
    croak( "Couldn't build object path for $unique_key" );

  Remove_File( $object_path ) or
    croak( "Couldn't remove file $object_path" );

  return $SUCCESS;
}


sub set
{
  my ( $self, $identifier, $data, $expires_in ) = @_;

  my $default_expires_in = $self->get_default_expires_in( );

  my $object =
    Build_Object( $identifier, $data, $default_expires_in, $expires_in ) or
      croak( "Couldn't build cache object" );

  my $unique_key = Build_Unique_Key( $identifier ) or
    croak( "Couldn't build unique key" );

  $self->_store( $unique_key, $object ) or
    croak( "Couldn't store $identifier" );

  return $SUCCESS;
}


sub size
{
  my ( $self ) = @_;

  my $namespace_path = $self->_build_namespace_path( ) or
    croak( "Couldn't build namespace path" );

  my $size = Recursive_Directory_Size( $namespace_path );

  return $size;
}


##
# Private instance methods
##


sub _initialize_file_cache
{
  my ( $self ) = @_;

  $self->_initialize_cache_depth( ) or
    croak( "Couldn't initialize cache depth" );

  $self->_initialize_cache_root( ) or
    croak( "Couldn't initialize cache root" );

  return $SUCCESS;
}


sub _initialize_cache_depth
{
  my ( $self ) = @_;

  my $cache_depth = 
    $self->_read_option( 'cache_depth', $DEFAULT_CACHE_DEPTH );

  $self->set_cache_depth( $cache_depth );

  return $SUCCESS;
}


sub _initialize_cache_root
{
  my ( $self ) = @_;

  my $optional_cache_root = $self->_read_option( 'cache_root' );

  my $cache_root = _Build_Cache_Root( $optional_cache_root );

  $self->set_cache_root( $cache_root );

  return $SUCCESS;
}


sub _store
{
  my ( $self, $unique_key, $object ) = @_;

  $unique_key or
    croak( "unique_key required" );

  my $object_path = $self->_build_object_path( $unique_key ) or
    croak( "Couldn't build object path" );

  my $data_dumper = new Data::Dumper( [$object] );

  $data_dumper->Deepcopy( 1 );

  my $object_dump = $data_dumper->Dump( );

  Make_Path( $object_path ) or
    croak( "Couldn't make path: $object_path" );

  Write_File( $object_path, \$object_dump ) or
    croak( "Couldn't write file $object_path" );

  return $SUCCESS;
}


sub _restore
{
  my ( $self, $unique_key ) = @_;

  $unique_key or
    croak( "unique_key required" );

  my $object_path = $self->_build_object_path( $unique_key ) or
    croak( "Couldn't build object path" );

  my $object_dump_ref = Read_File( $object_path ) or
    return undef;

  no strict 'refs';

  my $VAR1;

  eval $$object_dump_ref;

  my $object = $VAR1;

  use strict;

  return $object;
}


sub _list_unique_keys
{
  my ( $self, $unique_keys_ref ) = @_;

  my $namespace_path = $self->_build_namespace_path( ) or
    croak( "Couldn't build namespace path" );

  my @unique_keys;

  Recursively_List_Files( $namespace_path, $unique_keys_ref ) or
    croak( "Couldn't recursively list files at $namespace_path" );

  return $SUCCESS;
}


sub _build_object_path
{
  my ( $self, $unique_key ) = @_;

  ( $unique_key !~ m|[0-9][a-f][A-F]| ) or
    croak( "unique_key '$unique_key' contains illegal characters'" );

  $unique_key or
    croak( "unique_key required" );

  my $cache_depth = $self->get_cache_depth( );

  my @prefix;

  Split_Word( $unique_key, $cache_depth, \@prefix ) or
    croak( "Couldn't split word $unique_key" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $cache_root = $self->get_cache_root( ) or
    croak( "Couldn't get cache root" );

  my $object_path = 
    Build_Path( $cache_root, $namespace, @prefix, $unique_key ) or
      croak( "Couldn't build object_path" );

  return $object_path;
}


sub _build_namespace_path
{
  my ( $self ) = @_;

  my $cache_root = $self->get_cache_root( ) or
    croak( "Couldn't get cache root" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $namespace_path = 
    Build_Path( $cache_root, $namespace ) or
      croak( "Couldn't build namespace path" );

  return $namespace_path;
}


##
# Properties
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

=item C<$optional_cache_root>

If specified, this indicates the root on the filesystem of the cache
to be cleared.

=item B<Purge( $optional_cache_root )>

See Cache::Cache

=item C<$optional_cache_root>

If specified, this indicates the root on the filesystem of the cache
to be purged.

=item B<Size( $optional_cache_root )>

See Cache::Cache

=item C<$optional_cache_root>

If specified, this indicates the root on the filesystem of the cache
to be sized.

=item B<new( $options_hash_ref )>

Constructs a new FileCache.

=item C<$options_hash_ref>

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=item B<clear(  )>

See Cache::Cache

=item B<get( $identifier )>

See Cache::Cache

=item B<get_object( $identifier )>

See Cache::Cache

=item B<purge( )>

See Cache::Cache

=item B<remove( $identifier )>

See Cache::Cache

=item B<set( $identifier, $data, $expires_in )>

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

=back

=head1 PROPERTIES

See Cache::Cache for default properties.

=over 4

=item B<get_cache_root>

The root on the filesystem of this cache.

=item B<get_cache_depth>

The number of subdirectories deep to cache each object.

=back

=head1 SEE ALSO

Cache::Cache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
