######################################################################
# $Id: SizeAwareFileCache.pm,v 1.16 2001/04/24 15:18:14 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SizeAwareFileCache;


use strict;
use vars qw( @ISA );
use Cache::Cache qw( $EXPIRES_NEVER $SUCCESS $FAILURE $TRUE $FALSE );
use Cache::CacheMetaData;
use Cache::CacheUtils qw ( Build_Object
                           Build_Unique_Key
                           Limit_Size
                           Make_Path
                           Object_Has_Expired
                           Recursively_List_Files
                           Remove_File
                           Static_Params
                           Write_File );
use Cache::FileCache;
use Cache::SizeAwareCache qw( $NO_MAX_SIZE );
use Carp;


@ISA = qw ( Cache::FileCache Cache::SizeAwareCache );

my $DEFAULT_MAX_SIZE = $NO_MAX_SIZE;

##
# Public class methods
##


sub Clear
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  return Cache::FileCache::Clear( $optional_cache_root );
}


sub Purge
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  return Cache::FileCache::Purge( $optional_cache_root );
}


sub Size
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  return Cache::FileCache::Size( $optional_cache_root );
}


##
# Private class methods
##



##
# Constructor
##


sub new
{
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;

  my $self  =  $class->SUPER::new( $options_hash_ref ) or
    croak( "Couldn't run super constructor" );

  $self->_initialize_size_aware_file_cache( ) or
    croak( "Couldn't initialize Cache::SizeAwareFileCache" );

  return $self;
}


##
# Public instance methods
##



sub set
{
  my ( $self, $identifier, $data, $expires_in ) = @_;

  $self->_conditionally_auto_purge_on_set( ) or
    croak( "Couldn't conditionally auto purge on set" );

  my $default_expires_in = $self->get_default_expires_in( );

  my $object =
    Build_Object( $identifier, $data, $default_expires_in, $expires_in ) or
      croak( "Couldn't build cache object" );

  my $unique_key = Build_Unique_Key( $identifier ) or
    croak( "Couldn't build unique key" );

  $self->_store( $unique_key, $object ) or
    croak( "Couldn't store $identifier" );

  my $max_size = $self->get_max_size();

  if ( $max_size != $NO_MAX_SIZE )
  {
    $self->limit_size( $max_size );
  }

  return $SUCCESS;
}



sub limit_size
{
  my ( $self, $new_size ) = @_;

  defined $new_size or
    croak( "new_size required" );

  my $cache_meta_data = $self->_build_cache_meta_data( ) or
    croak( "Couldn't build cache meta data" );

  Limit_Size( $self, $cache_meta_data, $new_size ) or
    croak( "Couldn't limit size to $new_size" );

  return $SUCCESS;
}


##
# Private instance methods
##


sub _initialize_size_aware_file_cache
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_initialize_max_size( ) or
    croak( "Couldn't initialize max size" );

  return $SUCCESS;
}


sub _initialize_max_size
{
  my ( $self ) = @_;

  my $max_size = $self->_read_option( 'max_size', $DEFAULT_MAX_SIZE );

  $self->set_max_size( $max_size );

  return $SUCCESS;
}


sub _build_cache_meta_data
{
  my ( $self ) = @_;

  my $namespace_path = $self->_build_namespace_path( ) or
    croak( "Couldn't build namespace path" );

  defined( $namespace_path ) or
    croak( "namespace_path required" );

  my $cache_meta_data = new Cache::CacheMetaData( ) or
    croak( "Couldn't instantiate new CacheMetaData" );

  my @filenames;

  Recursively_List_Files( $namespace_path, \@filenames );

  foreach my $filename ( @filenames )
  {
    my $object = $self->_restore( $filename ) or
      next;

    my $size = $object->get_size( );

    $cache_meta_data->insert( $object ) or
      croak( "Couldn't insert meta data" );
  }

  return $cache_meta_data;
}


##
# Instance properties
##


sub get_max_size
{
  my ( $self ) = @_;

  return $self->{_Max_Size};
}


sub set_max_size
{
  my ( $self, $max_size ) = @_;

  $self->{_Max_Size} = $max_size;
}



1;


__END__

=pod

=head1 NAME

Cache::SizeAwareFileCache -- extends the Cache::FileCache module

=head1 DESCRIPTION

The Cache::SizeAwareFileCache module adds the ability to dynamically
limit the size of a file system based cache.  It offers the new
'max_size' option and the 'limit_size( $size )' method.  Please see
the documentation for Cache::FileCache for more information.

=head1 SYNOPSIS

  use Cache::SizeAwareFileCache;

  my %cache_options = ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600,
                        'max_size' => 10000 );

  my $size_aware_file_cache =
    new Cache::SizeAwareFileCache( \%cache_options ) or
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

Constructs a new SizeAwareFileCache

=over 4

=item $options_hash_ref

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=back

=item B<clear(  )>

See Cache::Cache

=item B<get( $identifier )>

See Cache::Cache

=item B<get_object( $identifier )>

See Cache::Cache

=item B<limit_size( $new_size )>

See Cache::SizeAwareCache.  NOTE: This is not 100% accurate, as the
current size is calculated from the size of the objects in the cache,
and does not include the size of the directory inodes.

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

=item max_size

See Cache::SizeAwareCache

=back

=head1 PROPERTIES

See Cache::Cache for default properties.

=over 4

=item B<(get|set)_max_size>

See Cache::SizeAwareCache

=item B<get_identifiers>

See Cache::FileCache

=back

=head1 SEE ALSO

Cache::Cache, Cache::SizeAwareCache, Cache::FileCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Also: Portions of this code are a rewrite of David Coppit's excellent
extentions to the original File::Cache

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
