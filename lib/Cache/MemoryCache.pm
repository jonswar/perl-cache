######################################################################
# $Id: MemoryCache.pm,v 1.1.1.1 2001/02/13 01:30:40 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::MemoryCache;

use strict;
use vars qw( @ISA );
use Cache::Cache qw( $EXPIRES_NEVER $TRUE $FALSE $SUCCESS $FAILURE );
use Cache::CacheUtils qw ( Build_Object Object_Has_Expired );
use Cache::Object;
use Carp;
use Data::Dumper;

@ISA = qw ( Cache::Cache );

my %Cache_Hash;

my $DEFAULT_NAMESPACE = "Default";
my $DEFAULT_EXPIRES_IN = $EXPIRES_NEVER;

sub new
{
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  bless( $self, $class );

  $self->_initialize_memory_cache( $options_hash_ref ) or
    croak( "Couldn't initialize" );

  return $self;
}


sub set
{
  my ( $self, $identifier, $data, $expires_in ) = @_;

  my $object =
    Build_Object( $identifier, $data, $DEFAULT_EXPIRES_IN, $expires_in ) or
      croak( "Couldn't build cache object" );

  $self->_store( $identifier, $object ) or
    croak( "Couldn't store $identifier" );

  return $SUCCESS;
}



sub get
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $object = $self->_restore( $identifier ) or
    return undef;

  my $has_expired = Object_Has_Expired( $object );

  if ( $has_expired eq $TRUE )
  {
    $self->remove( $identifier ) or
      croak( "Couldn't remove object $identifier" );

    return undef;
  }

  return $object->get_data( );
}



sub remove
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache_hash_ref" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  delete $cache_hash_ref->{$namespace}->{$identifier};

  return $SUCCESS;
}




sub clear
{
  my ( $self ) = @_;

  my $namespace = $self->get_namespace( ) or
    croak( "Namespace required" );

  $self->_delete_namespace( $namespace ) or
    croak( "Couldn't delete namespace $namespace" );

  return $SUCCESS;
}



sub purge
{
  my ( $self ) = @_;

  foreach my $identifier ( $self->_identifiers( ) )
  {
    $self->get( $identifier );
  }

  return $SUCCESS;
}


sub size
{
  my ( $self ) = @_;

  my $size = 0;

  foreach my $identifier ( $self->_identifiers( ) )
  {
    $size += $self->_build_object_size( $identifier );
  }

  return $size;
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
      new Cache::MemoryCache( { 'namespace' => $namespace } ) or
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
    my $cache = new Cache::MemoryCache( { 'namespace' => $namespace } ) or
      croak( "Couldn't construct cache with namespace $namespace" );

    $size += $cache->size( );
  }

  return $size;
}




sub _initialize_memory_cache
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_initialize_options_hash_ref( $options_hash_ref ) or
    croak( "Couldn't initialize options hash ref" );

  $self->_initialize_cache_hash_ref( ) or
    croak( "Couldn't initialize cache hash ref" );

  $self->_initialize_namespace( ) or
    croak( "Couldn't initialize namespace" );

  $self->_initialize_default_expires_in( ) or
    croak( "Couldn't initialize default expires in" );

  return $SUCCESS;
}


sub _initialize_cache_hash_ref
{
  my ( $self ) = @_;

  my $cache_hash_ref = \%Cache_Hash;

  $self->_set_cache_hash_ref( $cache_hash_ref );

  return $SUCCESS;
}



sub _initialize_options_hash_ref
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_set_options_hash_ref( $options_hash_ref );

  return $SUCCESS;
}


sub _initialize_namespace
{
  my ( $self ) = @_;

  my $namespace = $self->_read_option( 'namespace', $DEFAULT_NAMESPACE );

  $self->_set_namespace( $namespace );

  return $SUCCESS;
}



sub _store
{
  my ( $self, $identifier, $object ) = @_;

  $identifier or
    croak( "identifier required" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache_hash_ref" );

  my $data_dumper = new Data::Dumper( [$object] );

  $data_dumper->Deepcopy( 1 );

  my $object_dump = $data_dumper->Dump( );

  $cache_hash_ref->{$namespace}->{$identifier} = $object_dump;

  return $SUCCESS;
}



sub _restore
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache_hash_ref" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $object_dump = $cache_hash_ref->{$namespace}->{$identifier} or
    return undef;

  my $VAR1;

  eval $object_dump;

  my $object = $VAR1;

  return $object;
}


sub _initialize_default_expires_in
{
  my ( $self ) = @_;

  my $default_expires_in =
    $self->_read_option( 'default_expires_in', $DEFAULT_EXPIRES_IN );

  $self->_set_default_expires_in( $default_expires_in );

  return $SUCCESS;
}


sub _read_option
{
  my ( $self, $option_name, $default_value ) = @_;

  my $options_hash_ref = $self->_get_options_hash_ref( );

  if ( defined $options_hash_ref->{$option_name} )
  {
    return $options_hash_ref->{$option_name};
  }
  else
  {
    return $default_value;
  }
}


sub _delete_namespace
{
  my ( $self, $namespace ) = @_;

  _Delete_Namespace( $namespace ) or
    croak( "Couldn't delete namespace $namespace" );

  return $SUCCESS;
}


sub _identifiers
{
  my ( $self ) = @_;

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache_hash_ref" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  return ( ) unless defined $cache_hash_ref->{$namespace};

  return keys %{$cache_hash_ref->{$namespace}};
}


sub _build_object_size
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $cache_hash_ref = $self->_get_cache_hash_ref( ) or
    croak( "Couldn't get cache_hash_ref" );

  my $namespace = $self->get_namespace( ) or
    croak( "Couldn't get namespace" );

  my $object_dump = $cache_hash_ref->{$namespace}->{$identifier} or
    return 0;

  my $size = length $object_dump;

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




##
# Properties
##


sub _get_options_hash_ref
{
  my ( $self ) = @_;

  return $self->{_Options_Hash_Ref};
}

sub _set_options_hash_ref
{
  my ( $self, $options_hash_ref ) = @_;

  $self->{_Options_Hash_Ref} = $options_hash_ref;
}



sub get_namespace
{
  my ( $self ) = @_;

  return $self->{_Namespace};
}


sub _set_namespace
{
  my ( $self, $namespace ) = @_;

  $self->{_Namespace} = $namespace;
}


sub get_default_expires_in
{
  my ( $self ) = @_;

  return $self->{_Default_Expires_In};
}

sub _set_default_expires_in
{
  my ( $self, $default_expires_in ) = @_;

  $self->{_Default_Expires_In} = $default_expires_in;
}



sub _get_cache_hash_ref
{
  my ( $self ) = @_;

  return $self->{_Cache_Hash_Ref};
}

sub _set_cache_hash_ref
{
  my ( $self, $cache_hash_ref ) = @_;

  $self->{_Cache_Hash_Ref} = $cache_hash_ref;
}


1;



__END__

=pod

=head1 NAME

Cache::MemoryCache -- implements the Cache interface.

=head1 DESCRIPTION

The MemoryCache class implements the Cache interface.  This cache
stores data on a per-process basis.  This is the fastest of the cache
implementations, but data can not be shared between processes with the
MemoryCache.

=head1 SYNOPSIS

  use Cache::MemoryCache;

  my %cache_options_= ( 'namespace' => 'MyNamespace',
			'default_expires_in' => 600 );

  my $memory_cache = new Cache::MemoryCache( \%cache_options ) or
    croak( "Couldn't instantiate MemoryCache" );

=head1 METHODS

=over 4

=item B<new( $options_hash_ref )>

Constructs a new MemoryCache.

=item C<$options_hash_ref>

A reference to a hash containing configuration options for the cache.
See the section OPTIONS below.

=back

=head1 OPTIONS

The options are set by passing in a reference to a hash containing any
of the following keys:

=over 4

=item namespace

The namespace associated with this cache.  Defaults to "Default" if
not explicitly set.

=item default_expires_in

The default expiration time for objects place in the cache.  Defaults
to $EXPIRES_NEVER if not explicitly set.

=back

=head1 PROPERTIES

=over 4

=item B<get_default_expires_in>

The default expiration time for objects place in the cache.

=item B<get_namespace>

The namespace associated with this cache.

=back

=head1 SEE ALSO

Cache::Cache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
