######################################################################
# $Id: CacheBenchmark.pm,v 1.7 2001/03/26 18:43:38 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::CacheBenchmark;


use strict;
use vars qw( @ISA @EXPORT_OK );
use Benchmark;
use Cache::Cache qw( $EXPIRES_NOW
                     $EXPIRES_NEVER );
use Cache::FileCache;
use Cache::MemoryCache;
use Cache::SharedMemoryCache;
use Cache::SizeAwareFileCache;
use Cache::SizeAwareMemoryCache;
use Cache::SizeAwareSharedMemoryCache;
use Carp;
use Exporter;


@ISA = qw ( Benchmark );
@EXPORT_OK = qw ( Benchmark_Cache );


my @SET_NUM_KEYS = ( 10, 100, 1000, 5000 );
my @SET_OBJECT_SIZE = ( 1, 10, 100, 1000  );
my @GET_NUM_KEYS = ( 10, 100, 1000, 5000 );
my @GET_OBJECT_SIZE = ( 1, 10, 100, 1000 );


my $MAX_SIZE = 10000;


my $UNAME_COMMAND = 'uname -a';

$| = 1;

sub Benchmark_Cache
{
  Print_System_Info( );
  Benchmark_Memory_Cache( );
  Benchmark_File_Cache( );
  Benchmark_Shared_Memory_Cache( );
  Benchmark_Size_Aware_Memory_Cache_Without_Max_Size( );
  Benchmark_Size_Aware_Memory_Cache_With_Max_Size( );
  Benchmark_Size_Aware_File_Cache_Without_Max_Size( );
  Benchmark_Size_Aware_File_Cache_With_Max_Size( );
  Benchmark_Size_Aware_Shared_Memory_Cache_Without_Max_Size( );
  Benchmark_Size_Aware_Shared_Memory_Cache_With_Max_Size( );
}


sub Print_System_Info
{
  my $uname = `$UNAME_COMMAND`;

  print "System information:\n\n";
  print $uname ? $uname : "uname unavailable\n";
  print "\n";
}


sub Benchmark_Memory_Cache
{
  print "Benchmarking Cache::MemoryCache\n\n";

  my $memory_cache = new Cache::MemoryCache( ) or
    croak( "Couldn't instantiate memory cache" );

  Benchmark_Sets( $memory_cache );
  Benchmark_Gets( $memory_cache );

  print "\n";
}


sub Benchmark_File_Cache
{
  print "Benchmarking Cache::FileCache\n\n";

  my $file_cache = new Cache::FileCache( ) or
    croak( "Couldn't instantiate file cache" );

  Benchmark_Sets( $file_cache );
  Benchmark_Gets( $file_cache );

  print "\n";

}


sub Benchmark_Shared_Memory_Cache
{
  print "Benchmarking Cache::SharedMemoryCache\n\n";

  my $shared_memory_cache = new Cache::SharedMemoryCache( ) or
    croak( "Couldn't instantiate shared memory cache" );

  Benchmark_Sets( $shared_memory_cache );
  Benchmark_Gets( $shared_memory_cache );

  print "\n";
}



sub Benchmark_Size_Aware_File_Cache_Without_Max_Size
{
  print "Benchmarking Cache::SizeAwareFileCache (with no max_size)\n\n";

  my $size_aware_file_cache = new Cache::SizeAwareFileCache( ) or
    croak( "Couldn't instantiate size aware file cache" );

  Benchmark_Sets( $size_aware_file_cache );
  Benchmark_Gets( $size_aware_file_cache );

  print "\n";
}


sub Benchmark_Size_Aware_File_Cache_With_Max_Size
{
  print "Benchmarking Cache::SizeAwareFileCache (with max_size $MAX_SIZE)\n\n";

  my $options = { 'max_size' => $MAX_SIZE };

  my $size_aware_file_cache = new Cache::SizeAwareFileCache( $options ) or
    croak( "Couldn't instantiate size aware file cache" );

  Benchmark_Sets( $size_aware_file_cache );
  Benchmark_Gets( $size_aware_file_cache );

  print "\n";
}


sub Benchmark_Size_Aware_Memory_Cache_Without_Max_Size
{
  print "Benchmarking Cache::SizeAwareMemoryCache (with no max_size)\n\n";

  my $size_aware_memory_cache = new Cache::SizeAwareMemoryCache( ) or
    croak( "Couldn't instantiate size aware memory cache" );

  Benchmark_Sets( $size_aware_memory_cache );
  Benchmark_Gets( $size_aware_memory_cache );

  print "\n";
}



sub Benchmark_Size_Aware_Memory_Cache_With_Max_Size
{
  print "Benchmarking Cache::SizeAwareMemoryCache (with max_size $MAX_SIZE)\n\n";

  my $options = { 'max_size' => $MAX_SIZE };

  my $size_aware_memory_cache = new Cache::SizeAwareMemoryCache( $options ) or
    croak( "Couldn't instantiate size aware memory cache" );

  Benchmark_Sets( $size_aware_memory_cache );
  Benchmark_Gets( $size_aware_memory_cache );

  print "\n";
}


sub Benchmark_Size_Aware_Shared_Memory_Cache_Without_Max_Size
{
  print "Benchmarking Cache::SizeAwareSharedMemoryCache (with no max_size)\n\n";

  my $size_aware_shared_memory_cache =
    new Cache::SizeAwareSharedMemoryCache( ) or
      croak( "Couldn't instantiate size aware memory cache" );

  Benchmark_Sets( $size_aware_shared_memory_cache );
  Benchmark_Gets( $size_aware_shared_memory_cache );

  print "\n";
}



sub Benchmark_Size_Aware_Shared_Memory_Cache_With_Max_Size
{
  print "Benchmarking Cache::SizeAwareSharedMemoryCache (with max_size $MAX_SIZE)\n\n";

  my $options = { 'max_size' => $MAX_SIZE };

  my $size_aware_shared_memory_cache = new Cache::SizeAwareSharedMemoryCache( $options ) or
    croak( "Couldn't instantiate size aware shared memory cache" );

  Benchmark_Sets( $size_aware_shared_memory_cache );
  Benchmark_Gets( $size_aware_shared_memory_cache );

  print "\n";
}





sub Benchmark_Sets
{
  my ( $cache ) = @_;

  defined $cache or
    croak( "cache required" );

  foreach my $num_keys ( @SET_NUM_KEYS )
  {
    foreach my $object_size ( @SET_OBJECT_SIZE )
    {
      Benchmark_Set( $cache, $num_keys, $object_size );
    }
  }
}


sub Benchmark_Set
{
  my ( $cache, $num_keys, $object_size ) = @_;

  defined $cache or
    croak( "cache required" );

  defined $num_keys or
    croak( "num_keys required" );

  defined $object_size or
    croak( "object_size required" );

  $cache->clear( );

  my $t;

  eval
  {
    $t = timeit( 1, sub { Do_Set( $cache, $num_keys, $object_size ); } );

    my ( $real, $user, $system, $cuser, $csystem, $iterations ) = @$t;

    my $per_key = $system / $num_keys;

    printf ( "set %5d keys of size %8d:  %6.2f total cpu time, %.3f per set\n",
             $num_keys,
             $object_size,
             $system,
             $per_key );
  };

  if ( $@ )
  {
    print "   error: $@";
  }

  $cache->clear( );
}


sub Do_Set
{
  my ( $cache, $num_keys, $object_size ) = @_;

  my $object = 'x' x ( $object_size );

  for ( my $i = 1; $i <= $num_keys; $i++ )
  {
    $cache->set( $i, $object );
  }
}


sub Benchmark_Gets
{
  my ( $cache ) = @_;

  defined $cache or
    croak( "cache required" );

  foreach my $num_keys ( @GET_NUM_KEYS )
  {
    foreach my $object_size ( @GET_OBJECT_SIZE )
    {
      Benchmark_Get( $cache, $num_keys, $object_size );
    }
  }
}


sub Benchmark_Get
{
  my ( $cache, $num_keys, $object_size ) = @_;

  defined $cache or
    croak( "cache required" );

  defined $num_keys or
    croak( "num_keys required" );

  defined $object_size or
    croak( "object_size required" );

  $cache->clear( );

  my $t;

  eval
  {
    my $object = 'x' x ($object_size - 1);

    for ( my $i = 1; $i <= $num_keys; $i++ )
    {
      $cache->set( $i, $object );
    }

    $t = timeit( 1, sub { Do_Get( $cache, $num_keys, $object_size ); } );

    my ( $real, $user, $system, $cuser, $csystem, $iterations ) = @$t;

    my $per_key = $system / $num_keys;

    printf ( "get %5d keys of size %8d:  %6.2f total cpu time, %.3f per get\n",
             $num_keys,
             $object_size,
             $system,
             $per_key );
  };

  if ( $@ )
  {
    print "   error: $@";
  }

  $cache->clear( );
}


sub Do_Get
{
  my ( $cache, $num_keys, $object_size ) = @_;

  for ( my $i = 1; $i <= $num_keys; $i++ )
  {
    my $object = $cache->get( $i );
  }
}


1;

