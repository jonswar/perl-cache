######################################################################
# $Id: CacheTester.pm,v 1.1.1.1 2001/02/13 01:30:42 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::CacheTester;

use strict;
use Carp;
use Cache::AbstractCacheTester;
use Cache::Cache qw( $SUCCESS );

use vars qw( @ISA $EXPIRES_DELAY );

@ISA = qw ( Cache::AbstractCacheTester );

$EXPIRES_DELAY = 1;

sub test
{
  my ( $self, $cache ) = @_;

  $self->_test_one( $cache );
  $self->_test_two( $cache );
  $self->_test_three( $cache );
  $self->_test_four( $cache );
  $self->_test_five( $cache );
  $self->_test_six( $cache );
  $self->_test_seven( $cache );
  $self->_test_eight( $cache );
  $self->_test_nine( $cache );
  $self->_test_ten( $cache );
  $self->_test_eleven( $cache );
  $self->_test_twelve( $cache );
}


# Test the getting, setting, and removal of a scalar

sub _test_one
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_status = $cache->set( $key, $value );

  ( $set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );

  my $fetched_value = $cache->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );

  my $remove_status = $cache->remove( $key );

  ( $remove_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$remove_status eq $SUCCESS' );

  my $fetched_removed_value = $cache->get( $key );

  ( not defined $fetched_removed_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_removed_value' );
}


# Test the getting, setting, and removal of a list

sub _test_two
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my @value_list = ( 'One', 'Two', 'Three' );

  my $set_status = $cache->set( $key, \@value_list );

  ( $set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );

  my $fetched_value_list_ref = $cache->get( $key );

  if ( ( $fetched_value_list_ref->[0] eq 'One' ) and
       ( $fetched_value_list_ref->[1] eq 'Two' ) and
       ( $fetched_value_list_ref->[2] eq 'Three' ) )
  {
    $self->ok( );
  }
  else
  {
    $self->not_ok( 'fetched list does not match set list' );
  }

  my $remove_status = $cache->remove( $key );

  ( $remove_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$remove_status eq $SUCCESS' );

  my $fetched_removed_value = $cache->get( $key );

  ( not defined $fetched_removed_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_removed_value' );
}


# Test the getting, setting, and removal of a blessed object

sub _test_three
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_value_status = $cache->set( $key, $value );

  ( $set_value_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_value_status eq $SUCCESS' );

  my $cache_key = 'Cache Key';

  my $set_cache_status = $cache->set( $cache_key, $cache );

  ( $set_cache_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_cache_status eq $SUCCESS' );

  my $fetched_cache = $cache->get( $cache_key );

  ( defined $fetched_cache ) ?
    $self->ok( ) : $self->not_ok( 'defined $fetched_cache' );

  my $fetched_value = $fetched_cache->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );
}


# Test the expiration of an object

sub _test_four
{
  my ( $self, $cache ) = @_;

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_status = $cache->set( $key, $value, $expires_in );

  ( $set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );

  my $fetched_value = $cache->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );

  sleep( $EXPIRES_DELAY );

  my $fetched_expired_value = $cache->get( $key );

  ( not defined $fetched_expired_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_expired_value' );
}



# Test that caches make deep copies of values

sub _test_five
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my @value_list = ( 'One', 'Two', 'Three' );

  my $set_status = $cache->set( $key, \@value_list );

  ( $set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );

  @value_list = ( );

  my $fetched_value_list_ref = $cache->get( $key );

  if ( ( $fetched_value_list_ref->[0] eq 'One' ) and
       ( $fetched_value_list_ref->[1] eq 'Two' ) and
       ( $fetched_value_list_ref->[2] eq 'Three' ) )
  {
    $self->ok( );
  }
  else
  {
    $self->not_ok( 'fetched deep list does not match set deep list' );
  }
}



# Test clearing a cache

sub _test_six
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_status = $cache->set( $key, $value );

  ( $set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );

  my $clear_status = $cache->clear( );

  ( $clear_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$clear_status eq $SUCCESS' );

  my $fetched_cleared_value = $cache->get( $key );

  ( not defined $fetched_cleared_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $fetched_cleared_value' );
}


# Test sizing of the cache

sub _test_seven
{
  my ( $self, $cache ) = @_;

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $first_key = 'First Test Key';

  my $value = 'Test Value';

  my $first_set_status = $cache->set( $first_key, $value );

  ( $first_set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$first_set_status eq $SUCCESS' );

  my $first_size = $cache->size( );

  ( $first_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$first_size > $empty_size' );

  my $second_key = 'Second Test Key';

  my $second_set_status = $cache->set( $second_key, $value );

  ( $second_set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$second_set_status eq $SUCCESS' );

  my $second_size = $cache->size( );

  ( $second_size > $first_size ) ?
    $self->ok( ) : $self->not_ok( '$second_size > $first_size' );
}


# Test purging the cache

sub _test_eight
{
  my ( $self, $cache ) = @_;

  my $clear_status = $cache->clear( );

  ( $clear_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$clear_status eq $SUCCESS' );

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_status = $cache->set( $key, $value, $expires_in );

  ( $set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );

  my $pre_purge_size = $cache->size( );

  ( $pre_purge_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$pre_purge_size > $empty_size' );

  sleep( $EXPIRES_DELAY );

  my $purge_status = $cache->purge( );

  ( $purge_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$purge_status eq $SUCCESS' );

  my $post_purge_size = $cache->size( );

  ( $post_purge_size == $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$post_purge_size == $empty_size' );
}


# Test the getting, setting, and removal of a scalar across cache instances

sub _test_nine
{
  my ( $self, $cache1 ) = @_;

  $cache1 or
    croak( "cache required" );

  my $cache2 = $cache1->new( ) or
    croak( "Couldn't construct new cache" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_status = $cache1->set( $key, $value );

  ( $set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );

  my $fetched_value = $cache2->get( $key );

  ( $fetched_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$fetched_value eq $value' );
}


# Test Clear() and Size() as instance methods

sub _test_ten
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_status = $cache->set( $key, $value );

  $set_status eq $SUCCESS ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );


  my $full_size = $cache->Size( );

  ( $full_size > 0 ) ?
    $self->ok( ) : $self->not_ok( '$full_size > 0' );

  my $clear_status = $cache->Clear( );

  ( $clear_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$clear_status eq $SUCCESS' );

  my $empty_size = $cache->Size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );
}


# Test Purge(), Clear(), and Size() as instance methods

sub _test_eleven
{
  my ( $self, $cache ) = @_;

  my $clear_status = $cache->Clear( );

  ( $clear_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$clear_status eq $SUCCESS' );

  my $empty_size = $cache->Size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_status = $cache->set( $key, $value, $expires_in );

  $set_status eq $SUCCESS ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );


  my $pre_purge_size = $cache->Size( );

  ( $pre_purge_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$pre_purge_size > $empty_size' );

  sleep( $EXPIRES_DELAY );

  my $purge_status = $cache->Purge( );

  ( $purge_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$purge_status eq $SUCCESS' );

  my $post_purge_size = $cache->Size( );

  ( $post_purge_size == $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$post_purge_size == $empty_size' );
}


# Test Purge(), Clear(), and Size() as static methods

# TODO:  If someone knows the syntax for calling methods statically
# without resorting to the two step process I used below, please
# let me know!

sub _test_twelve
{
  my ( $self, $cache ) = @_;

  my $class = ref $cache or
    croak( "Couldn't get ref \$cache" );

  no strict 'refs';

  my $clear_method = "$class\:\:Clear";

  my $clear_status = &$clear_method( );

  ( $clear_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$clear_status eq $SUCCESS' );

  my $size_method = "$class\:\:Size";

  my $empty_size = &$size_method( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $expires_in = $EXPIRES_DELAY;

  my $key = 'Test Key';

  my $value = 'Test Value';

  my $set_status = $cache->set( $key, $value, $expires_in );

  $set_status eq $SUCCESS ?
    $self->ok( ) : $self->not_ok( '$set_status eq $SUCCESS' );


  my $pre_purge_size = &$size_method( );

  ( $pre_purge_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$pre_purge_size > $empty_size' );

  sleep( $EXPIRES_DELAY );

  my $purge_method = "$class\:\:Purge";

  my $purge_status = &$purge_method( );

  ( $purge_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$purge_status eq $SUCCESS' );

  my $post_purge_size = &$size_method( );

  ( $post_purge_size == $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$post_purge_size == $empty_size' );

  use strict;
}



1;


