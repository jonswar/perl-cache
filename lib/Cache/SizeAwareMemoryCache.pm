######################################################################
# $Id: SizeAwareMemoryCache.pm,v 1.13 2001/11/07 13:10:56 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SizeAwareMemoryCache;


use strict;
use vars qw( @ISA );
use Cache::Cache qw( $EXPIRES_NEVER );
use Cache::CacheMetaData;
use Cache::CacheUtils qw ( Assert_Defined
                           Build_Object
                           Freeze_Object
                           Limit_Size
                           Object_Has_Expired
                         );
use Cache::MemoryCache;
use Cache::SizeAwareCache qw( $NO_MAX_SIZE );
use Carp;


@ISA = qw ( Cache::MemoryCache Cache::SizeAwareCache );


my $DEFAULT_MAX_SIZE = $NO_MAX_SIZE;


##
# Public class methods
##


sub Clear
{
  return Cache::MemoryCache::Clear( );
}


sub Purge
{
  return Cache::MemoryCache::Purge( );
}


sub Size
{
  return Cache::MemoryCache::Size( );
}


##
# Private class methods
##


sub _build_cache_meta_data
{
  my ( $self ) = @_;

  my $cache_meta_data = new Cache::CacheMetaData( );

  foreach my $key ( $self->get_keys( ) )
  {
    my $object = $self->get_object( $key ) or
      next;

    $cache_meta_data->insert( $object );
  }

  return $cache_meta_data;
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


sub get
{
  my ( $self, $p_key ) = @_;

  Assert_Defined( $p_key );

  $self->_update_access_time( $p_key );

  return $self->SUPER::get( $p_key );
}


sub set
{
  my ( $self, $p_key, $p_data, $p_expires_in ) = @_;

  Assert_Defined( $p_key );

  $self->SUPER::set( $p_key, $p_data, $p_expires_in );

  if ( $self->get_max_size( ) != $NO_MAX_SIZE )
  {
    $self->limit_size( $self->get_max_size( ) );
  }
}


sub limit_size
{
  my ( $self, $p_new_size ) = @_;

  Assert_Defined( $p_new_size );

  Limit_Size( $self, $self->_build_cache_meta_data( ), $p_new_size );
}


##
# Private instance methods
##



sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  =  $class->SUPER::_new( $p_options_hash_ref );
  $self->_initialize_size_aware_memory_cache( );
  return $self;
}


sub _initialize_size_aware_memory_cache
{
  my ( $self ) = @_;

  $self->_initialize_max_size( );
}


sub _initialize_max_size
{
  my ( $self ) = @_;

  $self->set_max_size( $self->_read_option( 'max_size', $DEFAULT_MAX_SIZE ) );
}


sub _update_access_time
{
  my ( $self, $p_key ) = @_;

  my $object = $self->get_object( $p_key );

  if ( defined $object )
  {
    $object->set_accessed_at( time( ) );
    $self->set_object( $p_key, $object );
  }
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

Cache::SizeAwareMemoryCache -- extends the Cache::MemoryCache module

=head1 DESCRIPTION

The Cache::SizeAwareMemoryCache module adds the ability to dynamically
limit the size (in bytes) of a memory based cache.  It offers the new
'max_size' option and the 'limit_size( $size )' method.  Please see
the documentation for Cache::MemoryCache for more information.

=head1 SYNOPSIS

  use Cache::SizeAwareMemoryCache;

  my %cache_options = ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600,
                        'max_size' => 10000 );

  my $size_aware_memory_cache =
    new Cache::SizeAwareMemoryCache( \%cache_options ) or
      croak( "Couldn't instantiate SizeAwareMemoryCache" );

=head1 METHODS

=over 4

=item B<Clear( )>

See Cache::Cache

=item B<Purge( )>

See Cache::Cache

=item B<Size( )>

See Cache::Cache

=item B<new( $options_hash_ref )>

Constructs a new SizeAwareMemoryCache

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

=item B<limit_size( $new_size )>

See Cache::SizeAwareCache

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

=item max_size

See Cache::SizeAwareCache

=back

=head1 PROPERTIES

See Cache::Cache for default properties.

=over 4

=item B<(get|set)_max_size>

See Cache::SizeAwareCache

=back

=head1 SEE ALSO

Cache::Cache, Cache::MemoryCache, Cache::SizeAwareFileCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
