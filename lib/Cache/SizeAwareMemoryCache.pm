######################################################################
# $Id: SizeAwareMemoryCache.pm,v 1.11 2001/11/05 13:34:45 dclinton Exp $
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

  foreach my $identifier ( $self->get_identifiers( ) )
  {
    my $object = $self->get_object( $identifier ) or
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
  my ( $self, $p_identifier ) = @_;

  Assert_Defined( $p_identifier );

  $self->_conditionally_auto_purge_on_get( );

  my $object = $self->get_object( $p_identifier ) or
    return undef;

  if ( Object_Has_Expired( $object ) )
  {
    $self->remove( $p_identifier );
    return undef;
  }

  $object->set_accessed_at( time( ) );

  $self->_store( $p_identifier, $object );

  return $object->get_data( );
}


sub set
{
  my ( $self, $p_identifier, $p_data, $p_expires_in ) = @_;

  $self->_conditionally_auto_purge_on_set( );

  $self->set_object( $p_identifier, 
                     Build_Object( $p_identifier, 
                                   $p_data, 
                                   $self->get_default_expires_in( ), 
                                   $p_expires_in ) );

  if ( $self->get_max_size( ) != $NO_MAX_SIZE )
  {
    $self->limit_size( $self->get_max_size( ) );
  }
}


sub set_object
{
  my ( $self, $p_identifier, $p_object ) = @_;

  $self->_store( $p_identifier, $p_object );
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

=item B<get( $identifier )>

See Cache::Cache

=item B<get_object( $identifier )>

See Cache::Cache

=item B<limit_size( $new_size )>

See Cache::SizeAwareCache

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

=back

=head1 SEE ALSO

Cache::Cache, Cache::MemoryCache, Cache::SizeAwareFileCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
