######################################################################
# $Id: FileCache.pm,v 1.2 2001/02/13 02:32:03 dclinton Exp $
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
use Cache::FileCache;
use Carp;
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

