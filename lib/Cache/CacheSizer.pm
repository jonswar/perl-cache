######################################################################
# $Id: SizeAwareMemoryCache.pm,v 1.15 2001/11/29 18:12:55 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::CacheSizer;

use strict;

use Cache::Cache;
use Cache::CacheMetaData;
use Cache::CacheUtils qw ( Assert_Defined );
use Cache::SizeAwareCache qw ( $NO_MAX_SIZE );


# take a Cache reference and a CacheMetaData reference and
# limit the cache's size to new_size

sub Limit_Size
{
  my ( $p_cache, $p_cache_meta_data, $p_new_size ) = @_;

  Assert_Defined( $p_cache );
  Assert_Defined( $p_cache_meta_data );
  Assert_Defined( $p_new_size );

  $p_new_size >= 0 or
    throw Error::Simple( "p_new_size >= 0 required" );

  my $size_estimate = $p_cache_meta_data->get_cache_size( );

  return if $size_estimate <= $p_new_size;

  foreach my $key ( $p_cache_meta_data->build_removal_list( ) )
  {
    return if $size_estimate <= $p_new_size;
    $size_estimate -= $p_cache_meta_data->build_object_size( $key );
    $p_cache->remove( $key );
    $p_cache_meta_data->remove( $key );
  }

  warn( "Couldn't limit size to $p_new_size" );
}


sub new
{
  my ( $proto, $p_cache, $p_max_size ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  bless( $self, $class );
  Assert_Defined( $p_cache );
  Assert_Defined( $p_max_size );
  $self->_set_cache( $p_cache );
  $self->set_max_size( $p_max_size );
  return $self;
}


sub update_access_time
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  my $object = $self->_get_cache( )->get_object( $p_key );

  if ( defined $object )
  {
    $object->set_accessed_at( time( ) );
    $self->_get_cache( )->set_object( $p_key, $object );
  }
}


sub limit_size
{
  my ( $self, $p_new_size ) = @_;

  Assert_Defined( $p_new_size );

  return if $p_new_size == $NO_MAX_SIZE;

  Limit_Size( $self->_get_cache( ),
              $self->_build_cache_meta_data( ),
              $p_new_size );
}


sub _build_cache_meta_data
{
  my ( $self ) = @_;

  my $cache_meta_data = new Cache::CacheMetaData( );

  foreach my $key ( $self->_get_cache( )->get_keys( ) )
  {
    my $object = $self->_get_cache( )->get_object( $key ) or
      next;

    $cache_meta_data->insert( $object );
  }

  return $cache_meta_data;
}



sub _get_cache
{
  my ( $self ) = @_;

  return $self->{_Cache};
}


sub _set_cache
{
  my ( $self, $p_cache ) = @_;

  $self->{_Cache} = $p_cache;
}


sub get_max_size
{
  my ( $self ) = @_;

  return $self->{_Max_Size};
}


sub set_max_size
{
  my ( $self, $p_max_size ) = @_;

  $self->{_Max_Size} = $p_max_size;
}




1;
