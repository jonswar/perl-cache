######################################################################
# $Id: Cache.pm,v 1.1.1.1 2001/02/13 01:30:37 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::Cache;

use strict;
use Exporter;

use vars qw( @ISA
             @EXPORT_OK
             $VERSION
             $EXPIRES_NOW
             $EXPIRES_NEVER
             $TRUE
             $FALSE
             $SUCCESS
             $FAILURE );

@ISA = qw( Exporter );

@EXPORT_OK = qw( $VERSION
                 $EXPIRES_NOW
                 $EXPIRES_NEVER
                 $TRUE
                 $FALSE
                 $SUCCESS
                 $FAILURE );

use vars @EXPORT_OK;

$VERSION = 0.02;
$EXPIRES_NOW = 0;
$EXPIRES_NEVER = -1;
$TRUE = 1;
$FALSE = 0;
$SUCCESS = 1;
$FAILURE = 0;


sub set;

sub get;

sub remove;

sub clear;

sub purge;

sub size;

sub Clear;

sub Purge;

sub Size;

1;


__END__

=pod

=head1 NAME

Cache::Cache -- the Cache interface.

=head1 DESCRIPTION

The Cache interface is implemented by classes that support the get,
set, remove, size, purge, and clear instance methods and their
corresponding static methods for persisting data across method calls.

=head1 SYNOPSIS

  use Cache::Cache;
  use vars qw( @ISA );

  @ISA = qw( Cache::Cache );

  sub get
  {
    my ( $self, $identifier ) = @_;

    # ...

    return $data;
  }

  sub set
  {
    my ( $self, $identifier, $data, $expires_in ) = @_;

    # ...

    return $SUCCESS;
  }

  sub remove
  {
    my ( $self, $identifier ) = @_;

    # ...

    return $SUCCESS;
  }

  sub size
  {
    my ( $self ) = @_;

    # ...

    return $size;
  }


  sub clear
  {
    my ( $self ) = @_;

    # ...

    return $SUCCESS;
  }


  sub purge
  {
    my ( $self ) = @_;

    # ...

    return $SUCCESS;
  }


  sub Size
  {
    my ( ) = @_;

    # ...

    return $size;
  }


  sub Clear
  {
    my ( ) = @_;

    # ...

    return $SUCCESS;
  }


  sub Purge
  {
    my ( ) = @_;

    # ...

    return $SUCCESS;
  }


=head1 CONSTANTS

=over 4

=item $EXPIRES_NOW

The item being set in the cache will expire immediately.

=item $EXPIRES_NEVER

The item being set in the cache will never expire.

=back

=head1 METHODS

=over 4

=item B<Clear(  )>

Remove all objects from all caches of this type.

=item Returns

Either $SUCCESS or $FAILURE

=item B<Purge(  )>

Remove all objects that have expired from all caches of this type.

=item Returns

Either $SUCCESS or $FAILURE

=item B<Size(  )>

Calculate the total size of all objects in all caches of this type.

=item Returns

The total size of all the objects in all caches of this type.

=item B<clear(  )>

Remove all objects from the namespace associated with this cache instance.

=item Returns

Either $SUCCESS or $FAILURE

=item B<get( $identifier )>

Fetch the data specified.

=item C<$identifier>

A string uniquely identifying the data.

=item Returns

The data specified.

=item B<remove( $identifier )>

Delete the data associated with the $identifier from the cache.

=item C<$identifier>

A string uniquely identifying the data.

=item Returns

Either $SUCCESS or $FAILURE

=item B<set( $identifier, $data, $expires_in )>

=item C<$identifier>

A string uniquely identifying the data.

=item C<$data>

A scalar or reference to the object to be stored.

=item C<$expires_in>

Either the time in seconds until this data should be erased, or the
constant $EXPIRES_NOW, or the constant $EXPIRES_NEVER.  Defaults to
$EXPIRES_NEVER.

=item Returns

Either $SUCCESS or $FAILURE

=item B<purge(  )>

Remove all objects that have expired from the namespace associated
with this cache instance.

=item Returns

Either $SUCCESS or $FAILURE

=item B<size(  )>

Calculate the total size of all objects in the namespace associated with
this cache instance.

=item Returns

The total size of all objects in the namespace associated with this
cache instance.

=back

=head1 SEE ALSO

Cache::MemoryCache, Cache::FileCache, Cache::SharedMemoryCache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut
