#
# $Id: network-lib.sh,v 1.11 2009-01-28 12:54:42 marc Exp $
#
# @(#)$File$
#
# Copyright (c) 2001 ATIX GmbH, 2007 ATIX AG.
# Einsteinstrasse 10, 85716 Unterschleissheim, Germany
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#
#****h* boot-scripts/etc/network-lib.sh
#  NAME
#    network-lib.sh
#    $id$
#  DESCRIPTION
#    Libraryfunctions for general network support functions.
#*******

#****b* boot-scripts/etc/network-lib.sh/ip
#  NAME
#    ip
#  DESCRIPTION
#    The ip bootparameter holds the configuration for the ip stack of
#    the initrd. Valid modes are:
#      * cluster: the configuration is get from the cluster (default).
#      * ipstring: as defined in the standard boot paramters
#      * dhcp: ip as configured via dhcp
#********* ip

#****f* boot-lib.sh/getNetParameters
#  NAME
#    getNetParameters
#  SYNOPSIS
#    function getNetParameters()
#  DESCRIPTION
#    Gets all network relevant bootparamters. "ip" is so far the
#    only supported parameter.
#  SOURCE
#
function getNetParameters() {
   getBootParm ip "cluster"
}
#************ getNetParameters

#****f* boot-lib.sh/nicConfig
#  NAME
#    nicConfig
#  SYNOPSIS
#    function nicConfig(dev, ipConfig)
#  DESCRIPTION
#    Creates a network configuration file for the given network device
#    and the ip configuration.
#  SOURCE
function nicConfig {
#  local dev=$1
  local ipconfig=$1

  dev=$(getPosFromIPString 6, $ipconfig)

  return_c=0
  if [ "$dev" != "lo" ] && [ "$dev" != "lo0" ]; then
    echo_local -n "Loading module for $dev..."
    exec_local modprobe $dev && sleep 2 && ifconfig $dev up
    return_code
  fi

  if [ -n "$ipconfig" ] && [ "$ipconfig" != "skip" ]; then
    sleep 2
    echo_local "Creating network configuration for $dev"
    xen_dom0_detect
    if [ $? -eq 0 ]; then
      xen_ip2Config $ipconfig
    else
      exec_local ip2Config ${ipconfig}
    fi
#    exec_local ip2Config $(getPosFromIPString 1, $ipconfig):$(getPosFromIPString 2, $ipconfig):$(getPosFromIPString 3, $ipconfig):$(getPosFromIPString 4, $ipconfig):$(hostname):$dev
  fi
}
#******** nicConfig

#****f* boot-lib.sh/nicAutoUp
#  NAME
#    nicAutoUp
#  SYNOPSIS
#    function nicAutoUp ipconfig
#  DOCUMENTATION
#    Returns 0 if nic should be taken up configurated
#  SOURCE
#
function nicAutoUp() {
   local _err=0
   local onboot=$(getPosFromIPString 10, $ipconfig)
   if [ "$onboot" = "yes" ]; then
   	return 0
   else
    return 1
   fi
}
#************ nicAutoUp

#****f* boot-lib.sh/nicUp
#  NAME
#    nicUp
#  SYNOPSIS
#    function nicUp()
#  DOCUMENTATION
#    Powers up the network interface
#  SOURCE
#
function nicUp() {
   local _err=0
   local dev=$1
   /sbin/ifup $dev
   _err=$?
   return $_err

}
#************ ifup
#****f* boot-lib.sh/network_setup_bridge
#  NAME
#    network_setup_bridge
#  SYNOPSIS
#    function network_setup_bridge(bridgename, nodename, cluster_conf)
#  DOCUMENTATION
#    Powers up the network bridge
#  SOURCE
#
function network_setup_bridge {
   local bridgename=$1
   local nodename=$2
   local cluster_conf=$3

   _bridgename=$(getParameter bridgename)
   if [ -n "$_bridgename" ]; then
     bridgename=$_bridgename
   fi
   repository_store_value bridgename $bridgename
   local script=$(getParameter bridgescript "/etc/xen/scripts/network-bridge")
   local vifnum=$(getParameter bridgevifnum)
   local netdev=$(getParameter bridgenetdev)
   local antispoof=$(getParameter bridgeantispoof no)

   modprobe netloop
   $script start vifnum=$vifnum netdev=$netdev bridge=$bridgename antispoof=$antispoof
}
#************ network_setup_bridge

#****f* boot-lib.sh/ip2Config
#  NAME
#    ip2Config
#  SYNOPSIS
#    function ip2Config(ipConfig)
#    function ip2Config(ipAddr, ipGate, ipNetmask, ipHostname, ipDevice, master, slave, bridge)
#  MODIFICATION HISTORY
#  IDEAS
#  SOURCE
#
function ip2Config() {
  local distribution=$(repository_get_value distribution)

  if [ $# -eq 1 ]; then
    local ipAddr=$(getPosFromIPString 1, $1)

    #Bonding
    echo "$ipAddr" | grep "[[:digit:]][[:digit:]]*.[[:digit:]][[:digit:]]*.[[:digit:]][[:digit:]]*.[[:digit:]][[:digit:]]*" </dev/null 2>&1
    if [ -n "$ipAddr" ]; then
      local ipGate=$(getPosFromIPString 3, $1)
      local ipNetmask=$(getPosFromIPString 4, $1)
      local ipHostname=$(getPosFromIPString 5, $1)
    else
      local master=$(getPosFromIPString 2, $1)
      local slave=$(getPosFromIPString 3, $1)
    fi
    local ipDevice=$(getPosFromIPString 6, $1)
    local ipMAC=$(getPosFromIPString 7, $1)
    local type=$(getPosFromIPString 8, $1)
    local bridge=$(getPosFromIPString 9, $1)
    local onboot=$(getPosFromIPString 10, $1)
  else
    local ipAddr=$1
    local ipGate=$2
    local ipNetmask=$3
    local ipHostname=$4
    local ipDevice=$5
    local ipMAC=$6
    local master=$7
    local slave=$8
    local bridge=$9
    local type=$10
    local onboot=$11
    [ -z "$onboot" ] && onboot="yes"
  fi

  # Bonding
  if [ -n "$ipAddr" ]; then
  	echo_local -n "Generating ifcfg for ${distribution} ($ipAddr, $ipGate, $ipNetmask, $ipHostname, $ipDevice, $ipMAC)..."
    ${distribution}_ip2Config "$ipDevice" "$ipAddr" "$ipNetmask" "$ipHostname" "$ipGate" "$ipMAC" "$type" "$bridge" "$onboot"
  else
	echo_local -n "Generating ifcfg for ${distribution} ($master, $slave, $bridge, $ipDevice, $ipMAC)..."
    ${distribution}_ip2Config "$ipDevice" "" "$master" "$slave" "" "$ipMAC" "$type" "$bridge" "$onboot"
  fi
  return_code $?
}
#************ ip2Config

#****f* boot-lib.sh/auto_netconfig
#  NAME
#    auto_netconfig
#  SYNOPSIS
#    function auto_netconfig
#  MODIFICATION HISTORY
#  IDEAS
#  SOURCE
#
function auto_netconfig {
   echo_local -n "Loading modules for all found network cards"
   modules=$(cat $modules_conf | grep "alias eth[0-9]" | awk '{print $2;}')
   for module in $modules; do
      exec_local modprobe $module
   done
   return_code
}
#******** auto_netconfig

#****f* boot-lib.sh/found_nics
#  NAME
#    found_nics
#  SYNOPSIS
#    function found_nics
#  DESCRIPTION
#    Just returns how many NICs were found on this system
#
function found_nics {
  local nics=$(ifconfig -a | grep -v -i "Link encap: Local" | grep -v -i "Link encap:UNSPEC" | grep -i hwaddr | awk '{print $5;};' | wc -l)
  return $nics
}
	

#****f* boot-lib.sh/getPosFromIPString
#  NAME
#    getPosFromIPString
#  SYNOPSIS
#    function getPosFromIPString() {
#  MODIFICATION HISTORY
#  IDEAS
#  SOURCE
#
function getPosFromIPString() {
  pos=$1
  str=$2
  echo $str | awk -v pos=$pos 'BEGIN { FS=":"; }{ print $pos; }'
}
#************ getPosFromIPString

#############
# $Log: network-lib.sh,v $
# Revision 1.11  2009-01-28 12:54:42  marc
# Many changes:
# - moved some functions to std-lib.sh
# - no "global" variables but repository
# - bugfixes
# - support for step with breakpoints
# - errorhandling
# - little clean up
# - better seperation from cc and rootfs functions
#
# Revision 1.10  2008/11/18 08:41:59  marc
# cosmetic change
#
# Revision 1.9  2008/10/14 10:57:07  marc
# Enhancement #273 and dependencies implemented (flexible boot of local fs systems)
#
# Revision 1.8  2008/08/14 14:34:36  marc
# - removed xen deps
# - added bridging
#
# Revision 1.7  2008/01/24 13:33:17  marc
# - RFE#145 macaddress will be generated in configuration files
#
# Revision 1.6  2007/12/07 16:39:59  reiner
# Added GPL license and changed ATIX GmbH to AG.
#
# Revision 1.5  2007/10/10 15:08:56  mark
# fix for BZ138
#
# Revision 1.4  2007/10/05 10:07:31  marc
# - added xen-support
#
# Revision 1.3  2007/09/14 13:28:31  marc
# no changes
#
# Revision 1.2  2006/05/12 13:06:41  marc
# First stable Version 1.0 for initrd.
#
# Revision 1.1  2006/05/07 11:33:40  marc
# initial revision
#
