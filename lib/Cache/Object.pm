######################################################################
# $Id: Object.pm,v 1.3 2001/03/12 19:18:33 dclinton Exp $
# Copyright (C) 2001 DeWitt Clinton  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################

package Cache::Object;


##
# Constructor
##


sub new
{
  my ( $proto ) = @_;
  my $class = ref( $proto ) || $proto;
  my $self  = {};
  bless ( $self, $class );
  return $self;
}


##
# Instance properties
##


sub get_created_at
{
  my ( $self ) = @_;

  return $self->{_Created_At};
}

sub set_created_at
{
  my ( $self, $created_at ) = @_;

  $self->{_Created_At} = $created_at;
}


sub get_accessed_at
{
  my ( $self ) = @_;

  return $self->{_Accessed_At};
}

sub set_accessed_at
{
  my ( $self, $accessed_at ) = @_;

  $self->{_Accessed_At} = $accessed_at;
}


sub get_data
{
  my ( $self ) = @_;

  return $self->{_Data};
}

sub set_data
{
  my ( $self, $data ) = @_;

  $self->{_Data} = $data;
}


sub get_expires_at
{
  my ( $self ) = @_;

  return $self->{_Expires_At};
}


sub set_expires_at
{
  my ( $self, $expires_at ) = @_;

  $self->{_Expires_At} = $expires_at;
}


sub get_identifier
{
  my ( $self ) = @_;

  return $self->{_Identifier};
}


sub set_identifier
{
  my ( $self, $identifier ) = @_;

  $self->{_Identifier} = $identifier;
}


sub get_size
{
  my ( $self ) = @_;

  return $self->{_Size};
}


sub set_size
{
  my ( $self, $size ) = @_;

  $self->{_Size} = $size;
}


1;


__END__

=pod

=head1 NAME

Cache::Object -- the data stored in a Cache.

=head1 DESCRIPTION

Object is used by classes implementing the Cache interface as an
object oriented wrapper around the data.  End users will not normally
use Object directly, but it can be retrieved via the get_object method
on the Cache::Cache interface.

=head1 SYNOPSIS

 use Cache::Object;

 my $object = new Cache::Object( );

 $object->set_identifier( $identifier );
 $object->set_data( $data );
 $object->set_expires_at( $expires_at );
 $object->set_created_at( $created_at );


=head1 METHODS

=over 4

=item B<new(  )>

Construct a new Cache::Object.

=back

=head1 PROPERTIES

=over 4

=item B<(get|set)_accessed_at>

The time at which the object was last accessed.  Various cache
implementations will use the accessed_at property to store information
for LRU algorithms.  There is no guarentee that all caches will update
this field, however.

=item B<(get|set)_created_at>

The time at which the object was created.

=item B<(get|set)_data>

A scalar containing or a reference pointing to the data to be stored.

=item B<(get|set)_expires_at>

The time at which the object should expire from the cache.

=item B<(get|set)_identifier>

The key under which the object was stored.

=item B<(get|set)_size>

The size of the frozen version of this object

=back

=head1 SEE ALSO

Cache::Cache

=head1 AUTHOR

Original author: DeWitt Clinton <dewitt@unto.net>

Last author:     $Author: dclinton $

Copyright (C) 2001 DeWitt Clinton

=cut

