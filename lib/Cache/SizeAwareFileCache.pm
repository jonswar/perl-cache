######################################################################
# $Id: SizeAwareFileCache.pm,v 1.25 2001/11/29 18:33:21 dclinton Exp $
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
use Cache::CacheSizer;
use Cache::CacheUtils qw( Static_Params );
use Cache::FileCache;
use Cache::SizeAwareCache qw( $NO_MAX_SIZE );


@ISA = qw ( Cache::FileCache Cache::SizeAwareCache );


my $DEFAULT_MAX_SIZE = $NO_MAX_SIZE;


sub Clear
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  Cache::FileCache::Clear( $p_optional_cache_root );
}


sub Purge
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  Cache::FileCache::Purge( $p_optional_cache_root );
}


sub Size
{
  my ( $p_optional_cache_root ) = Static_Params( @_ );

  return Cache::FileCache::Size( $p_optional_cache_root );
}


sub new
{
  my ( $self ) = _new( @_ );
  $self->_complete_initialization( );
  return $self;
}


sub get
{
  my ( $self, $p_key ) = @_;

  $self->_get_cache_sizer( )->update_access_time( $p_key );
  return $self->SUPER::get( $p_key );
}


sub limit_size
{
  my ( $self, $p_new_size ) = @_;

  $self->_get_cache_sizer( )->limit_size( $p_new_size );
}



sub set
{
  my ( $self, $p_key, $p_data, $p_expires_in ) = @_;

  $self->SUPER::set( $p_key, $p_data, $p_expires_in );
  $self->_get_cache_sizer( )->limit_size( $self->get_max_size( ) );
}



sub _new
{
  my ( $proto, $p_options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  =  $class->SUPER::_new( $p_options_hash_ref );
  $self->_initialize_cache_sizer( );
  return $self;
}


sub _initialize_cache_sizer
{
  my ( $self ) = @_;

  my $max_size = $self->_read_option( 'max_size', $DEFAULT_MAX_SIZE );
  $self->_set_cache_sizer( new Cache::CacheSizer( $self, $max_size ) );
}


sub get_max_size
{
  my ( $self ) = @_;

  return $self->_get_cache_sizer( )->get_max_size( );
}


sub set_max_size
{
  my ( $self, $p_max_size ) = @_;

  $self->_get_cache_sizer( )->set_max_size( $p_max_size );
}


sub _get_cache_sizer
{
  my ( $self ) = @_;

  return $self->{_Cache_Sizer};
}


sub _set_cache_sizer
{
  my ( $self, $p_cache_sizer ) = @_;

  $self->{_Cache_Sizer} = $p_cache_sizer;
}




1;


__END__

=pod

=head1 NAME

Cache::SizeAwareFileCache -- extends the Cache::FileCache module

=head1 DESCRIPTION

The Cache::SizeAwareFileCache module adds the ability to dynamically
limit the size (in bytes) of a file system based cache.  It offers the
new 'max_size' option and the 'limit_size( $size )' method.  Please
see the documentation for Cache::FileCache for more information.

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

=item B<get( $key )>

See Cache::Cache

=item B<get_object( $key )>

See Cache::Cache

=item B<limit_size( $new_size )>

See Cache::SizeAwareCache.  NOTE: This is not 100% accurate, as the
current size is calculated from the size of the objects in the cache,
and does not include the size of the directory inodes.

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

=item B<get_keys>

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
