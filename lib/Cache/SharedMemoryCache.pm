######################################################################
# $Id: SharedMemoryCache.pm,v 1.2 2001/03/06 18:26:30 dclinton Exp $
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
use Cache::CacheUtils qw( Static_Params );
use Carp;
use IPC::Shareable;


@ISA = qw ( Cache::MemoryCache );


my $IPC_IDENTIFIER = 'ipcc';


my %_Cache_Hash;



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


sub _Delete_Namespace
{
  my ( $namespace ) = Static_Params( @_ );

  defined $namespace or
    croak( "Namespace required" );

  delete $_Cache_Hash{ $namespace };

  return $SUCCESS;
}


sub _Namespaces
{
  return keys %_Cache_Hash;
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

  my %ipc_options = ( 'key' =>  $IPC_IDENTIFIER,
		      'create' => 'yes' );

  tie( %_Cache_Hash, 'IPC::Shareable', \%ipc_options ) or
    croak( "Couldn't tie _Cache_Hash" );

  my $cache_hash_ref = \%_Cache_Hash;

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
