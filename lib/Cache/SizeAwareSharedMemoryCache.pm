######################################################################
# $Id: SizeAwareSharedMemoryCache.pm,v 1.2 2001/03/13 01:28:35 dclinton Exp $
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
use Cache::SizeAwareMemoryCache;
use Carp;
use Exporter;
use IPC::Shareable;


@ISA = qw ( Cache::SizeAwareMemoryCache Exporter );
@EXPORT_OK = qw( $NO_MAX_SIZE );


$NO_MAX_SIZE = $Cache::SizeAwareMemoryCache::NO_MAX_SIZE;


my $IPC_IDENTIFIER = 'ipcc';


my %_Shared_Cache_Hash;


##
# Public class methods
##


sub Clear
{
  foreach my $namespace ( _Namespaces( ) )
  {
    _Delete_Namespace( $namespace ) or
      croak( "Couldn't delete namespace $namespace" );
  }

  return $SUCCESS;
}


sub Purge
{
  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache =
      new Cache::SizeAwareSharedMemoryCache( { 'namespace' => $namespace } ) or
        croak( "Couldn't construct cache with namespace $namespace" );

    $cache->purge( ) or
      croak( "Couldn't purge cache with namespace $namespace" );
  }

  return $SUCCESS;
}


sub Size
{
  my $size = 0;

  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache =
      new Cache::SizeAwareSharedMemoryCache( { 'namespace' => $namespace } ) or
	croak( "Couldn't construct cache with namespace $namespace" );

    $size += $cache->size( );
  }

  return $size;
}



##
# Private class methods
##


sub _Delete_Namespace
{
  my ( $namespace ) = Static_Params( @_ );

  defined $namespace or
    croak( "Namespace required" );

  _Tie_Shared_Cache_Hash( ) or
    croak( "Couldn't tie shared cache hash" );

  delete $_Shared_Cache_Hash{ $namespace };

  return $SUCCESS;
}


sub _Namespaces
{
  _Tie_Shared_Cache_Hash( ) or
    croak( "Couldn't tie shared cache hash" );

  return keys %_Shared_Cache_Hash;
}


sub _Tie_Shared_Cache_Hash
{
  if ( tied %_Shared_Cache_Hash )
  {
    return $SUCCESS;
  }

  my %ipc_options = ( 'key' =>  $IPC_IDENTIFIER,
		      'create' => 'yes' );

  tie( %_Shared_Cache_Hash, 'IPC::Shareable', \%ipc_options ) or
    croak( "Couldn't tie _Shared_Cache_Hash" );

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

  return $self;
}


##
# Private instance methods
##



sub _initialize_cache_hash_ref
{
  my ( $self ) = @_;

  _Tie_Shared_Cache_Hash( ) or
    croak( "Couldn't tie shared cache hash" );

  my $cache_hash_ref = \%_Shared_Cache_Hash;

  $self->_set_cache_hash_ref( $cache_hash_ref );

  return $SUCCESS;
}


sub _delete_namespace
{
  my ( $self, $namespace ) = @_;

  _Delete_Namespace( $namespace ) or
    croak( "Couldn't delete namespace $namespace" );

  return $SUCCESS;
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
