######################################################################
# $Id: SharedMemoryCache.pm,v 1.16 2001/11/07 13:10:56 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SharedMemoryCache;


use strict;
use vars qw( @ISA );
use Cache::Cache;
use Cache::MemoryCache;
use Cache::CacheUtils qw( Assert_Defined
                          Static_Params );
use Cache::SharedMemoryBackend;
use Error;


@ISA = qw ( Cache::MemoryCache );


##
# Public class methods
##



sub Clear
{
  foreach my $namespace ( _Namespaces( ) )
  {
    _Get_Backend( )->delete_namespace( $namespace );
  }
}


sub Purge
{
  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache = new Cache::SharedMemoryCache( { 'namespace' => $namespace } );
    $cache->purge( );
  }
}


sub Size
{
  my $size = 0;

  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache = new Cache::MemoryCache( { 'namespace' => $namespace } );

    $size += $cache->size( );
  }

  return $size;
}



##
# Private class methods
##


sub _Namespaces
{
  return _Get_Backend( )->get_namespaces( );
}



sub _Get_Backend
{
  return new Cache::SharedMemoryBackend( );
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
# Private instance methods
##


sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self = $class->SUPER::_new( $p_options_hash_ref );
  $self->_initialize_shared_memory_cache( );
  return $self;
}



sub _initialize_shared_memory_cache
{
  my ( $self ) = @_;

  $self->_set_backend( new Cache::SharedMemoryBackend( ) );
}


1;



=pod

=head1 NAME

Cache::SharedMemoryCache -- extends the MemoryCache.

=head1 DESCRIPTION

The SharedMemoryCache extends the MemoryCache class and binds the data
store to shared memory so that separate process can use the same
cache.

=head1 SYNOPSIS

  use Cache::SharedMemoryCache;

  my %cache_options_= ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600 );

  my $shared_memory_cache = 
    new Cache::SharedMemoryCache( \%cache_options ) or
      croak( "Couldn't instantiate SharedMemoryCache" );

=head1 METHODS

=over 4

=item B<Clear( )>

See Cache::Cache

=item B<Purge( )>

See Cache::Cache

=item B<Size( )>

See Cache::Cache

=item B<new( $options_hash_ref )>

Constructs a new SharedMemoryCache.

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

See Cache::Cache for standard options.

=head1 PROPERTIES

See Cache::Cache for default properties.

=head1 SEE ALSO

Cache::Cache, Cache::MemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
