######################################################################
# $Id: SharedMemoryCache.pm,v 1.5 2001/03/19 16:02:54 dclinton Exp $
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
use Cache::Cache qw( $TRUE $FALSE $SUCCESS $FAILURE );
use Cache::MemoryCache;
use Cache::CacheUtils qw( Restore_Shared_Hash_Ref
                          Static_Params
                          Store_Shared_Hash_Ref
                          Clone_Object );
use Carp;


@ISA = qw ( Cache::MemoryCache );


my $IPC_IDENTIFIER = 'ipcc';


##
# Public class methods
##


sub Clear
{
  my $empty_cache_hash_ref = { };

  _Store_Cache_Hash_Ref( $empty_cache_hash_ref ) or
    croak( "Couldn't store empty cache hash ref" );

  return $SUCCESS;
}


sub Purge
{
  foreach my $namespace ( _Namespaces( ) )
  {
    my $cache =
      new Cache::SharedMemoryCache( { 'namespace' => $namespace } ) or
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
      new Cache::SharedMemoryCache( { 'namespace' => $namespace } ) or
	croak( "Couldn't construct cache with namespace $namespace" );

    $size += $cache->size( );
  }

  return $size;
}



##
# Private class methods
##


sub _Restore_Cache_Hash_Ref
{
  return Restore_Shared_Hash_Ref( $IPC_IDENTIFIER );
}


sub _Store_Cache_Hash_Ref
{
  my ( $cache_hash_ref ) = Static_Params( @_ );

  return Store_Shared_Hash_Ref( $IPC_IDENTIFIER, $cache_hash_ref );
}


sub _Delete_Namespace
{
  my ( $namespace ) = Static_Params( @_ );

  defined $namespace or
    croak( "Namespace required" );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref( ) or
    croak( "Couldn't restore cache hash ref" );

  delete $cache_hash_ref->{ $namespace };

  _Store_Cache_Hash_Ref( $cache_hash_ref ) or
    croak( "Couldn't store cache hash ref" );

  return $SUCCESS;
}


sub _Namespaces
{
  my $cache_hash_ref = _Restore_Cache_Hash_Ref( ) or
    croak( "Couldn't restore cache hash ref" );

  return keys %{ $cache_hash_ref };
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


sub _store
{
  my ( $self, $identifier, $object ) = @_;

  $identifier or
    croak( "identifier required" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $object_dump;

  Clone_Object( \$object, \$object_dump ) or
    croak( "Couldn't freeze object" );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref( ) or
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

  my $object = $cache_hash_ref->{$namespace}->{$identifier};

  return $object;
}


sub _identifiers
{
  my ( $self ) = @_;

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $cache_hash_ref = _Restore_Cache_Hash_Ref( ) or
    croak( "Couldn't restore cache hash ref" );

  return ( ) unless defined $cache_hash_ref->{$namespace};

  return keys %{$cache_hash_ref->{$namespace}};
}


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


sub _delete_namespace
{
  my ( $self, $namespace ) = @_;

  _Delete_Namespace( $namespace ) or
    croak( "Couldn't delete namespace $namespace" );

  return $SUCCESS;
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

=item C<$options_hash_ref>

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=item B<clear(  )>

See Cache::Cache

=item B<get( $identifier )>

See Cache::Cache

=item B<get_object( $identifier )>

See Cache::Cache

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
