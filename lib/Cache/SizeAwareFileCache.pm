######################################################################
# $Id: SizeAwareFileCache.pm,v 1.4 2001/02/16 02:11:36 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::SizeAwareFileCache;

use strict;
use vars qw( @ISA @EXPORT_OK $NO_MAX_SIZE );
use Cache::Cache qw( $EXPIRES_NEVER $SUCCESS $FAILURE $TRUE $FALSE );
use Cache::CacheUtils qw ( Make_Path
                           Recursively_List_Files_With_Paths
                           Read_File_Without_Time_Modification
                           Static_Params
                           Write_File );
use Cache::FileCache;
use Carp;
use Data::Dumper;
use Exporter;

@ISA = qw ( Cache::FileCache );

@EXPORT_OK = qw( $NO_MAX_SIZE );


# Exported Constants

$NO_MAX_SIZE = -1;


# Static Constants

my $DEFAULT_MAX_SIZE = $NO_MAX_SIZE;


sub new
{
  my ( $proto, $options_hash_ref ) = @_;
  my $class = ref( $proto ) || $proto;

  my $self  =  $class->SUPER::new( $options_hash_ref ) or
    croak( "Couldn't run super constructor" );

  $self->_initialize_size_aware_file_cache( ) or
    croak( "Couldn't initialize Cache::SizeAwareFileCache" );

  return $self;
}



sub Clear
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  return Cache::FileCache::Clear( $optional_cache_root );
}


sub Purge
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  return Cache::FileCache::Purge( $optional_cache_root );
}


sub Size
{
  my ( $optional_cache_root ) = Static_Params( @_ );

  return Cache::FileCache::Size( $optional_cache_root );
}


sub _store
{
  my ( $self, $unique_key, $object ) = @_;

  $unique_key or
    croak( "unique_key required" );

  my $object_path = $self->_build_object_path( $unique_key ) or
    croak( "Couldn't build object path" );

  my $data_dumper = new Data::Dumper( [$object] );

  $data_dumper->Deepcopy( 1 );

  my $object_dump = $data_dumper->Dump( );

  Make_Path( $object_path ) or
    croak( "Couldn't make path: $object_path" );

  my $max_size = $self->get_max_size();

  if ( $max_size != $NO_MAX_SIZE )
  {
    my $new_size = $max_size - length $object_dump;

    $new_size = 0 if $new_size < 0;

    $self->limit_size( $new_size );
  }

  Write_File( $object_path, \$object_dump ) or
    croak( "Couldn't write file $object_path" );

  return $SUCCESS;
}


sub limit_size
{
  my ( $self, $new_size ) = @_;

  $new_size >= 0 or
    croak("size >= 0 required");

  my $namespace_path = $self->_build_namespace_path( ) or
    croak( "Couldn't build namespace path" );

  while ( $self->size() > $new_size )
  {
    my $identifier_to_remove = _Choose_Identifier_To_Remove( $namespace_path );

    if ( not defined $identifier_to_remove )
    {
      warn("Couldn't limit size to $new_size\n");

      return $FAILURE;
    }

    $self->remove( $identifier_to_remove ) or
      croak( "Couldn't remove identifier $identifier_to_remove" );
  }

  return $SUCCESS;
}


sub _Choose_Identifier_To_Remove
{
  my ( $namespace_path ) = @_;

  defined( $namespace_path ) or
    croak( "namespace_path required" );

  my $next_expiring_indentifier = 
    _Find_Next_Expiring_Identifier( $namespace_path );

  if ( defined $next_expiring_indentifier )
  {
    return $next_expiring_indentifier;
  }

  my $least_recently_accessed_identifier =
    _Find_Least_Recently_Accessed_Identifier( $namespace_path );

  if ( defined $least_recently_accessed_identifier )
  {
    return $least_recently_accessed_identifier;
  }

  return undef;
}



sub _Find_Next_Expiring_Identifier
{
  my ( $namespace_path ) = @_;

  defined( $namespace_path ) or
    croak( "namespace_path required" );

  my $next_expiring_indentifier = undef;

  my $next_expires_at = undef;

  my @filenames;

  Recursively_List_Files_With_Paths( $namespace_path, \@filenames );

  foreach my $filename ( @filenames )
  {
    my $object = _Restore_Object_Without_Time_Modication( $filename ) or
      next;

    my $expires_at = $object->get_expires_at( );

    next if $expires_at = $EXPIRES_NEVER;

    if ( ( not defined $next_expires_at ) or
         ( $expires_at < $next_expires_at ) )
    {
      $next_expires_at = $expires_at;

      $next_expiring_indentifier = $object->get_identifier( ) or
        croak( "Couldn't get identifier" );
    }
  }

  return $next_expiring_indentifier;
}


sub _Find_Least_Recently_Accessed_Identifier
{
  my ( $namespace_path ) = @_;

  defined( $namespace_path ) or
    croak( "namespace_path required" );

  my $least_recently_accessed_identifier = undef;

  my $least_recent_access_time = undef;

  my @filenames;

  Recursively_List_Files_With_Paths( $namespace_path, \@filenames );

  foreach my $filename ( @filenames )
  {
    my $last_access_time = ( stat( $filename ) )[8];

    if ( ( not defined $least_recent_access_time ) or
         ( $least_recent_access_time < $last_access_time ) )
    {
      my $object = _Restore_Object_Without_Time_Modication( $filename ) or
        next;

      $least_recent_access_time = $last_access_time;

      $least_recently_accessed_identifier = $object->get_identifier( ) or
        croak( "Couldn't get identifier" );
    }
  }

  return $least_recently_accessed_identifier;
}


sub _Restore_Object_Without_Time_Modication
{
  my ( $filename ) = @_;

  defined( $filename ) or
    croak( "filename required" );

  if ( not -e $filename )
  {
    warn( "filename $filename does not exist" );
    return undef;
  }

  my $object_dump_ref = Read_File_Without_Time_Modification( $filename ) or
    return undef;

  no strict 'refs';

  my $VAR1;

  eval $$object_dump_ref;

  my $object = $VAR1;

  use strict;

  return $object;
}


sub _initialize_size_aware_file_cache
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

Cache::SizeAwareFileCache -- extends the Cache::FileCache module

=head1 DESCRIPTION

The Cache::SizeAwareFileCache module adds the ability to dynamically
limit the size of a file system based cache.  It offers the new
'max_size' option and the 'limit_size( $size )' method.  Please see
the documentation for Cache::FileCache for more information.

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

=item B<limit_size( $new_size )>

Attempt to resize the cache such that the total disk usage is under
the 'new_size' parameter.  NOTE: This is not 100% accurate, as the
current size is calculated from the size of the objects in the cache,
and does not include the size of the directory inodes.

=item C<$new_size>

The size (in bytes) that the cache should be limited to.  This is
only a one time adjustment.  To maintain the cache size, consider using
the 'max_size' option, although it is considered very expensive.

=item Returns

Either $SUCCESS or $FAILURE

=back

=head1 OPTIONS

The options are set by passing in a reference to a hash containing any
of the following keys.  Also, all of the options available to
Cache::FileCache apply to this class as well.

=over 4

=item max_size

Sets the max_size property, which is described in detail below.
Defaults to $NO_MAX_SIZE.

=back

=head1 PROPERTIES

=over 4

=item B<(get|set)_max_size>

If this property is set, then the cache will try not to exceed the max
size value specified.  NOTE: This causes the size of the cache to be
checked on every set, and can be considered *very* expensive.  A good
alternative approach is leave max_size as $NO_MAX_SIZE and to
periodically limit the size of the cache by calling the
limit_size( $size ) method.

=back

=head1 SEE ALSO

Cache::Cache, Cache::FileCache


=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Also: Portions of this code are a rewrite of David Coppit's excellent
extentions to the original File::Cache

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
