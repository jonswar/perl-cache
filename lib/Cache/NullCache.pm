######################################################################
# $Id: NullCache.pm,v 1.3 2001/11/07 13:10:56 dclinton Exp $
# Copyright (C) 2001 Jay Sachs  All Rights Reserved
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either expressed or
# implied. See the License for the specific language governing
# rights and limitations under the License.
######################################################################


package Cache::NullCache;

use strict;
use vars qw( @ISA );
use Cache::Cache qw( $EXPIRES_NOW  );

@ISA = qw ( Cache::BaseCache );


sub Clear
{
}


sub Purge
{
}


sub Size
{
  return 0;
}


sub new
{
  my ( $proto ) = @_;

  return bless( {}, ref( $proto ) || $proto );
}


sub clear
{
}


sub get
{
  return undef;
}


sub get_object
{
  return undef;
}


sub purge
{
}


sub remove
{
}


sub set
{
}


sub set_object
{
}


sub size
{
  return 0;
}


sub get_default_expires_in
{
  return $EXPIRES_NOW;
}


sub get_keys
{
  return ( );
}


sub get_auto_purge_interval
{
  return 0;
}


sub set_auto_purge_interval
{
}


sub get_auto_purge_on_set
{
}


sub set_auto_purge_on_set
{
}


sub get_auto_purge_on_get
{
}


sub set_auto_purge_on_get
{
}


