######################################################################
# $Id: SizeAwareSharedMemoryCache.pm,v 1.9 2001/03/23 00:15:06 dclinton Exp $
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
use Cache::Cache qw( $EXPIRES_NEVER $SUCCESS $FAILURE $TRUE $FALSE );
use Cache::CacheUtils qw( Static_Params );
use Cache::SharedCacheUtils qw( Restore_Shared_Hash_Ref
                                Restore_Shared_Hash_Ref_With_Lock
                                Store_Shared_Hash_Ref
                                Store_Shared_Hash_Ref_And_Unlock
                              );
use Cache::SizeAwareMemoryCache;
use Cache::SharedMemoryCache;
use Carp;
use Exporter;
use IPC::Shareable;


@ISA = qw ( Cache::SizeAwareMemoryCache Exporter );
@EXPORT_OK = qw( $NO_MAX_SIZE );


$NO_MAX_SIZE = $Cache::SizeAwareMemoryCache::NO_MAX_SIZE;


my $IPC_IDENTIFIER = 'ipcc';


##
# Public class methods
##


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



##
# Private class methods
##




sub _Restore_Cache_Hash_Ref
{
  return Cache::SharedMemoryCache::_Restore_Cache_Hash_Ref( @_ );
}


sub _Restore_Cache_Hash_Ref_With_Lock
{
  return Cache::SharedMemoryCache::_Restore_Cache_Hash_Ref_With_Lock( @_ );
}


sub _Store_Cache_Hash_Ref
{
  return Cache::SharedMemoryCache::_Store_Cache_Hash_Ref( @_ );
}


sub _Store_Cache_Hash_Ref_And_Unlock
{
  return Cache::SharedMemoryCache::_Store_Cache_Hash_Ref_And_Unlock( @_ );
}


sub _Delete_Namespace
{
  return Cache::SharedMemoryCache::_Delete_Namespace( @_ );
}


sub _Namespaces
{
  return Cache::SharedMemoryCache::_Namespaces( @_ );
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

  return $self;
}



sub remove
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref( ) or
    croak( "Couldn't restore cache hash ref" );

  delete $cache_hash_ref->{$namespace}->{$identifier};

  _Store_Cache_Hash_Ref( $cache_hash_ref ) or
    croak( "Couldn't store cache hash ref" );

  return $SUCCESS;
}


##
# Private instance methods
##


sub _build_object_size
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref( ) or
    croak( "Couldn't restore cache hash ref" );

  my $object_dump = $cache_hash_ref->{$namespace}->{$identifier} or
    return 0;

  my $size = length $object_dump;

  return $size;
}


sub _store
{
  my ( $self, $identifier, $object ) = @_;

  $identifier or
    croak( "identifier required" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $object_dump = $self->_freeze( $object ) or
    croak( "Couldn't freeze object" );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref_With_Lock( ) or
    croak( "Couldn't restore cache hash ref" );

  $cache_hash_ref->{$namespace}->{$identifier} = $object_dump;

  _Store_Cache_Hash_Ref( $cache_hash_ref ) or
    croak( "Couldn't store cache hash ref" );

  return $SUCCESS;
}


sub _restore
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref( ) or
    croak( "Couldn't restore cache hash ref" );

  my $object_dump = $cache_hash_ref->{$namespace}->{$identifier} or
    return undef;

  my $object = $self->_thaw( $object_dump ) or
    croak( "Couldn't thaw object" );

  return $object;
}


sub _delete_namespace
{
  my ( $self, $namespace ) = @_;

  _Delete_Namespace( $namespace ) or
    croak( "Couldn't delete namespace $namespace" );

  return $SUCCESS;
}


##
# Instance properties
##


sub get_identifiers
{
  my ( $self ) = @_;

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref( ) or
    croak( "Couldn't restore cache hash ref" );

  return ( ) unless defined $cache_hash_ref->{ $namespace };

  return keys %{ $cache_hash_ref->{ $namespace } };
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

=item C<$options_hash_ref>

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=item B<clear(  )>

See Cache::Cache

=item B<get( $identifier )>

See Cache::Cache

=item B<get_object( $identifier )>

See Cache::Cache

=item B<limit_size( $new_size )>

See Cache::SizeAwareMemoryCache

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
