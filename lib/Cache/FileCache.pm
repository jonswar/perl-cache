######################################################################
# $Id: FileCache.pm,v 1.2 2001/02/13 02:32:03 dclinton Exp $
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
                           Write_File );
use Cache::Object;
use Carp;
use Data::Dumper;

@ISA = qw ( Cache::Cache );

my $DEFAULT_CACHE_DEPTH = 3;
my $DEFAULT_CACHE_ROOT = "FileCache";
my $DEFAULT_EXPIRES_IN = $EXPIRES_NEVER;
my $DEFAULT_NAMESPACE = "Default";

sub new
{
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  bless( $self, $class );

  $self->_initialize_file_cache( $options_hash_ref ) or
    croak( "Couldn't initialize Cache::FileCache" );

  return $self;
}


sub set
{
  my ( $self, $identifier, $data, $expires_in ) = @_;

  my $object =
    Build_Object( $identifier, $data, $DEFAULT_EXPIRES_IN, $expires_in ) or
      croak( "Couldn't build cache object" );

  my $unique_key = Build_Unique_Key( $identifier ) or
    croak( "Couldn't build unique key" );

  $self->_store( $unique_key, $object ) or
    croak( "Couldn't store $identifier" );

  return $SUCCESS;
}



sub get
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $unique_key = Build_Unique_Key( $identifier ) or
    croak( "Couldn't build unique key" );

  my $object = $self->_restore( $unique_key ) or
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




sub clear
{
  my ( $self ) = @_;

  my $namespace_path = $self->_build_namespace_path( ) or
    croak( "Couldn't build namespace path" );

  Recursively_Remove_Directory( $namespace_path ) or
    croak( "Couldn't remove $namespace_path" );

  return $SUCCESS;
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


sub size
{
  my ( $self ) = @_;

  my $namespace_path = $self->_build_namespace_path( ) or
    croak( "Couldn't build namespace path" );

  my $size = Recursive_Directory_Size( $namespace_path );

  return $size;
}




sub Clear
{
  my ( $optional_cache_root ) = @_;

  my $cache_root = _Build_Cache_Root( $optional_cache_root ) or
    croak( "Couldn't build cache root" );

  Recursively_Remove_Directory( $cache_root ) or
    croak( "Couldn't remove $cache_root" );

  return $SUCCESS;
}



# TODO: It would be more effecient to iterate over the list of cached objects and purge them individually

sub Purge
{
  my ( $optional_cache_root ) = @_;

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
  my ( $optional_cache_root ) = @_;

  my $cache_root = _Build_Cache_Root( $optional_cache_root ) or
    croak( "Couldn't build cache root" );

  my $size = Recursive_Directory_Size( $cache_root );

  return $size;
}




sub _initialize_file_cache
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_initialize_options_hash_ref( $options_hash_ref ) or
    croak( "Couldn't initialize options hash ref" );

  $self->_initialize_namespace( ) or
    croak( "Couldn't initialize namespace" );

  $self->_initialize_cache_depth( ) or
    croak( "Couldn't initialize cache depth" );

  $self->_initialize_cache_root( ) or
    croak( "Couldn't initialize cache root" );

  $self->_initialize_default_expires_in( ) or
    croak( "Couldn't initialize default expires in" );

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


sub _initialize_options_hash_ref
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_set_options_hash_ref( $options_hash_ref );

  return $SUCCESS;
}


sub _initialize_namespace
{
  my ( $self ) = @_;

  my $namespace = $self->_read_option( 'namespace', $DEFAULT_NAMESPACE );

  $self->_set_namespace( $namespace );

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



sub _initialize_default_expires_in
{
  my ( $self ) = @_;

  my $default_expires_in =
    $self->_read_option( 'default_expires_in', $DEFAULT_EXPIRES_IN );

  $self->_set_default_expires_in( $default_expires_in );

  return $SUCCESS;
}


sub _read_option
{
  my ( $self, $option_name, $default_value ) = @_;

  my $options_hash_ref = $self->_get_options_hash_ref( );

  if ( defined $options_hash_ref->{$option_name} )
  {
    return $options_hash_ref->{$option_name};
  }
  else
  {
    return $default_value;
  }
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


sub _List_Namespaces
{
  my ( $namespaces_ref, $optional_cache_root ) = @_;

  my $cache_root = _Build_Cache_Root( $optional_cache_root ) or
    croak( "Couldn't build cache root" );

  List_Subdirectories( $cache_root, $namespaces_ref ) or
    croak( "Couldn't list subdirectories of $cache_root" );

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


sub _Build_Cache_Root
{
  my ( $self, $optional_cache_root ) = @_;

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


sub _get_options_hash_ref
{
  my ( $self ) = @_;

  return $self->{_Options_Hash_Ref};
}

sub _set_options_hash_ref
{
  my ( $self, $options_hash_ref ) = @_;

  $self->{_Options_Hash_Ref} = $options_hash_ref;
}



sub get_namespace
{
  my ( $self ) = @_;

  return $self->{_Namespace};
}


sub _set_namespace
{
  my ( $self, $namespace ) = @_;

  $self->{_Namespace} = $namespace;
}


sub get_default_expires_in
{
  my ( $self ) = @_;

  return $self->{_Default_Expires_In};
}

sub _set_default_expires_in
{
  my ( $self, $default_expires_in ) = @_;

  $self->{_Default_Expires_In} = $default_expires_in;
}



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

  my %cache_options_= ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600 );

  my $file_cache = new Cache::FileCache( \%cache_options ) or
    croak( "Couldn't instantiate FileCache" );

=head1 METHODS

=over 4

=item B<new( $options_hash_ref )>

Constructs a new FileCache.

=item C<$options_hash_ref>

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=back

=head1 OPTIONS

The options are set by passing in a reference to a hash containing any
of the following keys:

=over 4

=item namespace

The namespace associated with this cache.  Defaults to "Default" if
not explicitly set.

=item default_expires_in

The default expiration time for objects place in the cache.  Defaults
to $EXPIRES_NEVER if not explicitly set.

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

=over 4

=item B<get_default_expires_in>

The default expiration time for objects place in the cache.

=item B<get_namespace>

The namespace associated with this cache.

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
