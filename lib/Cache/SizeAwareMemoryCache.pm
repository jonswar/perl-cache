######################################################################
# $Id: SizeAwareMemoryCache.pm,v 1.2 2001/03/13 01:27:42 dclinton Exp $
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
use Cache::Cache qw( $EXPIRES_NEVER $SUCCESS $FAILURE $TRUE $FALSE );
use Cache::CacheUtils qw ( Build_Object
                           Freeze_Object
                           Object_Has_Expired
                           Thaw_Object );
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


# _build_removal_list creates a list of all of the identifiers in the
# cache Each identifier appears twice in the list.  First, ordered by the
# the time in which they will expire (skipping those that will not
# expire), and second, in the order by which they were most recently
# accessed
#
# NOTE:  I aplogize if this method is confusing.  This was an area
# of significant performance issues, so it is written to be optimized
# in terms of run time speed, not clarity


sub _build_removal_list
{
  my ( $self, $removal_list_ref ) = @_;

  defined( $removal_list_ref ) or
    croak( "removal_list_ref required" );

  my %next_expiration_hash;

  my %least_recently_accessed_hash;

  my @identifiers = $self->_identifiers( );

  foreach my $identifier ( @identifiers )
  {
    my $object = $self->get_object( $identifier ) or
      next;

    my $expires_at = $object->get_expires_at( );

    my $last_access_time = $object->get_accessed_at( );

    $next_expiration_hash{ $identifier } = $expires_at if
      $expires_at ne $EXPIRES_NEVER;

    $least_recently_accessed_hash{ $identifier } = $last_access_time;
  }


  my @next_expiring_list =
    sort
    {
      $next_expiration_hash{$b} <=> $next_expiration_hash{$a}
    } keys %next_expiration_hash;


  my @least_recently_accessed_list =
    sort
    {
      $least_recently_accessed_hash{$b} <=> $least_recently_accessed_hash{$a}
    } keys %least_recently_accessed_hash;


  @$removal_list_ref = ( @next_expiring_list, @least_recently_accessed_list );

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

  $self->_initialize_size_aware_memory_cache( ) or
    croak( "Couldn't initialize Cache::SizeAwareMemoryCache" );

  return $self;
}


##
# Public instance methods
##


sub get
{
  my ( $self, $identifier ) = @_;

  $identifier or
    croak( "identifier required" );

  my $object = $self->get_object( $identifier ) or
    return undef;

  my $has_expired = Object_Has_Expired( $object );

  if ( $has_expired eq $TRUE )
  {
    $self->remove( $identifier ) or
      croak( "Couldn't remove object $identifier" );

    return undef;
  }

  my $time = time( );

  $object->set_accessed_at( $time );

  $self->_store( $identifier, $object ) or
    croak( "Couldn't store $identifier" );

  return $object->get_data( );
}


sub set
{
  my ( $self, $identifier, $data, $expires_in ) = @_;

  my $default_expires_in = $self->get_default_expires_in( );

  my $object =
    Build_Object( $identifier, $data, $default_expires_in, $expires_in ) or
      croak( "Couldn't build cache object" );

  $self->_store( $identifier, $object ) or
    croak( "Couldn't store $identifier" );

  my $max_size = $self->get_max_size();

  if ( $max_size != $NO_MAX_SIZE )
  {
    $self->limit_size( $max_size );
  }

  return $SUCCESS;
}


sub limit_size
{
  my ( $self, $new_size ) = @_;

  $new_size >= 0 or
    croak( "size >= 0 required" );

  my $current_size = $self->size( );

  my $size_difference = $self->size( ) - $new_size;

  return $SUCCESS if ( $size_difference <= 0 );

  my @removal_list;

  $self->_build_removal_list( \@removal_list );

  foreach my $identifier ( @removal_list )
  {
    my $size = $self->_build_object_size( $identifier );

    $self->remove( $identifier ) or
      croak( "Couldn't remove identifier" );

    $size_difference -= $size;

    last if ( $size_difference <= 0 );
  }

  if ( $size_difference > 0 )
  {
    warn("Couldn't limit size to $new_size\n");

    return $FAILURE;
  }

  return $SUCCESS;
}


##
# Private instance methods
##



sub _initialize_size_aware_memory_cache
{
  my ( $self, $options_hash_ref ) = @_;

  $self->_initialize_max_size( ) or
    croak( "Couldn't initialize max size" );

  return $SUCCESS;
}


sub _initialize_max_size
{
  my ( $self ) = @_;

  my $max_size = $self->_read_option( 'max_size', $DEFAULT_MAX_SIZE );

  $self->set_max_size( $max_size );

  return $SUCCESS;
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
limit the size of a memory based cache.  It offers the new
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
