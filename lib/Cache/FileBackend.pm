######################################################################
# $Id: MemoryBackend.pm,v 1.1 2001/11/08 23:01:23 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::FileBackend;

use strict;

sub new
{
  my ( $proto, $p_cache_root, $p_cache_depth, $p_directory_umask ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  $self = bless( $self, $class );
  $self->set_cache_root( $p_cache_root );
  $self->set_cache_depth( $p_cache_depth );
  $self->set_directory_umask( $p_directory_umask );
  return $self;
}


sub store
{
  my ( $self, $p_namespace, $p_key, $p_value ) = @_;
}


sub restore
{
  my ( $self, $p_namespace, $p_key ) = @_;
}


sub delete_key
{
  my ( $self, $p_namespace, $p_key ) = @_;
}


sub delete_namespace
{
  my ( $self, $p_namespace ) = @_;
}


sub get_keys
{
  my ( $self, $p_namespace ) = @_;
}


sub get_namespaces
{
  my ( $self ) = @_;
}


sub get_object_size
{
  my ( $self, $p_namespace, $p_key ) = @_;
}



sub get_cache_depth
{
  my ( $self ) = @_;

  return $self->{_Cache_Depth};
}

sub set_cache_depth
{
  my ( $self, $cache_depth ) = @_;

  $self->{_Cache_Depth} = $cache_depth;
}


sub get_cache_root
{
  my ( $self ) = @_;

  return $self->{_Cache_Root};
}


sub set_cache_root
{
  my ( $self, $cache_root ) = @_;

  $self->{_Cache_Root} = $cache_root;
}


sub get_directory_umask
{
  my ( $self ) = @_;

  return $self->{_Directory_Umask};
}


sub set_directory_umask
{
  my ( $self, $directory_umask ) = @_;

  $self->{_Directory_Umask} = $directory_umask;
}


1;
