######################################################################
# $Id: SizeAwareSharedMemoryCache.pm,v 1.18 2001/11/29 18:12:55 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::SizeAwareSharedMemoryCache;


use strict;
use vars qw( @ISA @EXPORT_OK $NO_MAX_SIZE );
use Cache::Cache qw( $EXPIRES_NEVER );
use Cache::SharedMemoryBackend;
use Cache::SizeAwareMemoryCache;
use Cache::SharedMemoryCache;
use Exporter;


@ISA = qw ( Cache::SizeAwareMemoryCache Exporter );
@EXPORT_OK = qw( $NO_MAX_SIZE );


$NO_MAX_SIZE = $Cache::SizeAwareMemoryCache::NO_MAX_SIZE;


sub Clear
{
  return Cache::SharedMemoryCache::Clear( );
}


sub Purge
{
  return Cache::SharedMemoryCache::Purge( );
}


sub Size
{
  return Cache::SharedMemoryCache::Size( );
}


sub new
{
  my ( $self ) = _new( @_ );

  $self->_complete_initialization( );

  return $self;
}


sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self = $class->SUPER::_new( $p_options_hash_ref );
  $self->_set_backend( new Cache::SharedMemoryBackend( ) );
  return $self;
}


1;


__END__

=pod

=head1 NAME

Cache::SizeAwareSharedMemoryCache -- extends the Cache::SizeAwareMemoryCache module

=head1 DESCRIPTION

The SizeAwareSharedMemoryCache extends the SizeAwareMemoryCache class
and binds the data store to shared memory so that separate process can
use the same cache.

=head1 SYNOPSIS

  use Cache::SizeAwareSharedMemoryCache;

  my %cache_options = ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600,
                        'max_size' => 10000 );

  my $size_aware_shared_memory_cache =
    new Cache::SizeAwareSharedMemoryCache( \%cache_options ) or
      croak( "Couldn't instantiate SizeAwareSharedMemoryCache" );

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

See Cache::SizeAwareMemoryCache

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

See Cache::Cache for standard options.  See Cache::SizeAwareMemory cache
for other options.

=head1 PROPERTIES

See Cache::Cache and Cache::SizeAwareMemoryCache for default
properties.

=head1 SEE ALSO

Cache::Cache, Cache::MemoryCache, Cache::SizeAwareMemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
