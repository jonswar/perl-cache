######################################################################
# $Id:  $
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
use Carp;
use IPC::Shareable;

my $IPC_IDENTIFIER = 'ipcc';

my %Cache_Hash;

@ISA = qw ( Cache::MemoryCache );

sub new
{
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  =  $class->SUPER::new( $options_hash_ref ) or
    croak( "Couldn't run super constructor" );
  return $self;
}

sub _initialize_cache_hash_ref
{
  my ( $self ) = @_;

  my %ipc_options = ( 'key' =>  $IPC_IDENTIFIER,
		      'create' => 'yes' );

  tie( %Cache_Hash, 'IPC::Shareable', \%ipc_options ) or
    croak( "Couldn't tie Cache_Hash" );

  my $cache_hash_ref = \%Cache_Hash;

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


sub _Delete_Namespace
{
  my ( $namespace ) = @_;

  defined $namespace or
    croak( "Namespace required" );

  delete $Cache_Hash{ $namespace };

  return $SUCCESS;
}



sub _Namespaces
{
  return keys %Cache_Hash;
}

1;



=pod

=head1 NAME

Cache::SharedMemoryCache -- extends the MemoryCache.

=head1 DESCRIPTION

The SharedMemoryCache extends the MemoryCache class and binds the
data store to shared memory.

=head1 SYNOPSIS

  use Cache::SharedMemoryCache;
  
  my %cache_options_= ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600 );

  my $shared_memory_cache = new Cache::SharedMemoryCache( \%cache_options ) or
    croak( "Couldn't instantiate SharedMemoryCache" );

=head1 SEE ALSO

Cache::Cache, Cache::MemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dewitt $

Copyright (C) 2001 DeWitt Clinton

=cut
