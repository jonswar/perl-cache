######################################################################
# $Id: SizeAwareCacheTester.pm,v 1.4 2001/03/12 19:20:59 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::SizeAwareCacheTester;

use strict;
use Carp;
use Cache::BaseCacheTester;
use Cache::Cache qw( $SUCCESS );

use vars qw( @ISA $EXPIRES_DELAY );

@ISA = qw ( Cache::BaseCacheTester );


sub test
{
  my ( $self, $cache ) = @_;

  $self->_test_one( $cache );
  $self->_test_two( $cache );
  $self->_test_three( $cache );
}


# Test the limit_size( ) method, which should automatically purge the
# first object added (with the closer expiration time)

sub _test_one
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $clear_status = $cache->clear( );

  ( $clear_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$clear_status eq $SUCCESS' );

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $first_key = 'Key 1';

  my $first_expires_in = '10';

  my $value = $self;

  my $first_set_status = $cache->set( $first_key, $value, $first_expires_in );

  ( $first_set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$first_set_status eq $SUCCESS' );

  my $first_size = $cache->size( );

  ( $first_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$first_size > $empty_size' );

  my $size_limit = $first_size;

  my $second_key = 'Key 2';

  my $second_expires_in = $first_expires_in * 2;

  my $second_set_status = 
    $cache->set( $second_key, $value, $second_expires_in );

  ( $second_set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$second_set_status eq $SUCCESS' );

  my $second_size = $cache->size( );

  ( $second_size > $first_size ) ?
    $self->ok( ) : $self->not_ok( '$second_size > $first_size' );

  $cache->limit_size( $size_limit );

  my $first_value = $cache->get( $first_key );

  ( not defined $first_value ) ?
    $self->ok( ) : $self->not_ok( 'not defined $first_value' );

  my $third_size = $cache->size( );

  ( $third_size <= $size_limit ) ?
    $self->ok( ) : $self->not_ok( '$third_size <= $size_limit' );
}



# Test the limit_size method when a number of objects can expire
# simultaneously

sub _test_two
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $clear_status = $cache->clear( );

  ( $clear_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$clear_status eq $SUCCESS' );

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $value = "A very short string";

  my $first_key = 'Key 0';

  my $first_expires_in = 20;

  my $first_set_status = 
    $cache->set( $first_key, $value, $first_expires_in );

  ( $first_set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$first_set_status eq $SUCCESS' );

  my $first_size = $cache->size( );

  ( $first_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$first_size > $empty_size' );

  my $second_expires_in = $first_expires_in / 2;

  my $num_keys = 5;

  for ( my $i = 1; $i <= $num_keys; $i++ )
  {
    my $key = 'Key ' . $i;

    sleep ( 1 );

    my $set_status = $cache->set( $key, $value, $second_expires_in );

    ( $set_status eq $SUCCESS ) ?
      $self->ok( ) : $self->not_ok( 'set_status eq $SUCCESS' );
  }

  my $second_size = $cache->size( );

  ( $second_size > $first_size ) ?
    $self->ok( ) : $self->not_ok( '$second_size > $first_size' );

  my $size_limit = $first_size;

  $cache->limit_size( $size_limit );

  my $first_value = $cache->get( $first_key );

  ( $first_value eq $value ) ?
    $self->ok( ) : $self->not_ok( '$first_value eq $value' );

  my $third_size = $cache->size( );

  ( $third_size <= $size_limit ) ?
    $self->ok( ) : $self->not_ok( '$third_size <= $size_limit' );
}


# Test the max_size( ) method, which should keep the cache under
# the given size

sub _test_three
{
  my ( $self, $cache ) = @_;

  $cache or
    croak( "cache required" );

  my $clear_status = $cache->clear( );

  ( $clear_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$clear_status eq $SUCCESS' );

  my $empty_size = $cache->size( );

  ( $empty_size == 0 ) ?
    $self->ok( ) : $self->not_ok( '$empty_size == 0' );

  my $first_key = 'Key 1';

  my $value = $self;

  my $first_set_status = $cache->set( $first_key, $value );

  ( $first_set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$first_set_status eq $SUCCESS' );

  my $first_size = $cache->size( );

  ( $first_size > $empty_size ) ?
    $self->ok( ) : $self->not_ok( '$first_size > $empty_size' );

  my $max_size = $first_size;

  $cache->set_max_size( $max_size );

  my $second_key = 'Key 2';

  my $second_set_status = $cache->set( $second_key, $value );

  ( $second_set_status eq $SUCCESS ) ?
    $self->ok( ) : $self->not_ok( '$second_set_status eq $SUCCESS' );

  my $second_size = $cache->size( );

  ( $second_size <= $max_size ) ?
    $self->ok( ) : $self->not_ok( '$second_size <= $max_size' );
}


1;
