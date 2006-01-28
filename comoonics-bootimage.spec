# @(#)$File:$
#
# Copyright (c) 2001 ATIX GmbH.
# Einsteinstrasse 10, 85716 Unterschleissheim, Germany
# All rights reserved.
#
# This software is the confidential and proprietary information of ATIX
# GmbH. ("Confidential Information").  You shall not
# disclose such Confidential Information and shall use it only in
# accordance with the terms of the license agreement you entered into
# with ATIX.
#
# %define _initrddir /etc/init.d
# $Id: comoonics-bootimage.spec,v 1.9 2006-01-28 15:01:49 marc Exp $
#
##
# TO DO
# etc/rc.sysinit:
#  #if [ -z "$fastboot" -a "$READONLY" != "yes" -a "X$ROOTFSTYPE" != "Xnfs" -a "X$ROOTFSTYPE" != "Xnfs4" ]; then
#  if [ -z "$fastboot" -a "$READONLY" != "yes" -a "X$ROOTFSTYPE" != "Xnfs" -a "X$ROOTFSTYPE" != "Xnfs4" -a "X$ROOTFSTYPE" != "Xgfs" ]; then
##


%define _user root
%define         CONFIGDIR       /%{_sysconfdir}/comoonics
%define         APPDIR       /opt/atix/comoonics_bootimage


Name: comoonics-bootimage
Summary: Comoonics Bootimage. Scripts for creating an initrd in a gfs shared root environment
Version: 0.3
Release: 13
Vendor: ATIX GmbH
Packager: Marc Grimme (grimme@atix.de)
ExclusiveArch: noarch
URL:     http://www.atix.de/
Source:  http://www.atix.de/software/downloads/comoonics/comoonics-bootimage-%{version}.tar.gz
License: GPL
Group:   Storage/Management
BuildRoot: %{_tmppath}/%{name}-%{version}-buildroot

%description
Comoonics Bootimage. Scripts for creating an initrd in a gfs shared root environment

%prep
%setup -q

%build

%install
make PREFIX=$RPM_BUILD_ROOT install

%post

echo "Starting postinstall.."
if ! $(grep '%{APPDIR}' /etc/profile.d/atix.sh > /dev/null 2>&1); then
    echo "Patching path.."
    echo 'PATH=%{APPDIR}:${PATH}' >> /etc/profile.d/atix.sh
fi
echo "Creating mkinitrd link..."
ln -sf %{APPDIR}/create-gfs-initrd-generic.sh %{APPDIR}/mkinitrd

echo "Analysing config files..."
cfg_files="gfs6-es30-files.i686.list gfs61-es40-files.i686.list"
for cfg_file in $cfg_files; do
  if ! $(grep "%{APPDIR}/boot-scripts" /etc/comoonics/bootimage/$cfg_file >/dev/null 2>&1); then
    (echo "# START: RPM-post install added "$(date); echo "@map %{APPDIR}/boot-scripts /"; echo "# END:RPM-post install added ") >> /etc/comoonics/bootimage/$cfg_file
  else
    echo "Please verify that there is at least a line in your config file /etc/comoonics/bootimage/$cfg_file of the following type:"
    echo "@map %{APPDIR}/boot-scripts /"
  fi
done
if [ ! -e /etc/comoonics/bootimage/files-$(uname -r).list ]; then
  uname -r | grep "^2.4" > /dev/null
  if [ $? -eq 0 ]; then
	ln -s /etc/comoonics/bootimage/gfs6-es30-files.i686.list /etc/comoonics/bootimage/files-$(uname -r).list
  else
	ln -s /etc/comoonics/bootimage/gfs61-es40-files.i686.list /etc/comoonics/bootimage/files-$(uname -r).list
  fi
fi
root_fstype=$(mount | grep "/ " | awk 'BEGIN { exit_c=1; } { if ($5) { print $5; exit_c=0; } } END{ exit exit_c}')
if [ "$root_fstype" = "gfs" ]; then
  /sbin/chkconfig --add bootsr &>/dev/null
  /sbin/chkconfig bootsr on
  /sbin/chkconfig --list bootsr
  /sbin/chkconfig --add fenced-chroot &>/dev/null
  /sbin/chkconfig fenced-chroot off
  /sbin/chkconfig --list fenced-chroot
  /sbin/chkconfig fenced off
  /sbin/chkconfig --del fenced &>/dev/null
  grep "^FENCE_CHROOT=" /etc/sysconfig/cluster &>/dev/null
  [ $? -ne 0 ] &&	echo "FENCE_CHROOT=/var/lib/fence_tool" >> /etc/sysconfig/cluster
  grep "^FENCE_CHROOT_SOURCE=" /etc/sysconfig/cluster &>/dev/null
  [ $? -ne 0 ] && echo "FENCE_CHROOT_SOURCE=/var/lib/fence_tool.tmp" >> /etc/sysconfig/cluster
fi
#echo "Creating linuxrc link.."
#cd %{APPDIR}/boot-scripts/ && ln -sf linuxrc.generic.sh linuxrc

%postun
echo "Postuninstalling comoonics-bootimage.."
rm -f /etc/comoonics/bootimage/files-* &>/dev/null
root_fstype=$(mount | grep "/ " | awk 'BEGIN { exit_c=1; } { if ($5) { print $5; exit_c=0; } } END{ exit exit_c}')
if [ "$root_fstype" = "gfs" ]; then
  /sbin/chkconfig --del bootsr &>/dev/null
  /sbin/chkconfig bootsr off
  /sbin/chkconfig --list bootsr
  /sbin/chkconfig --del fenced-chroot &>/dev/null
  /sbin/chkconfig fenced-chroot off
  /sbin/chkconfig --list fenced-chroot
  /sbin/chkconfig --add fenced &>/dev/null
  /sbin/chkconfig --list fenced
fi


%changelog
* Wed Jan 25 2006  <grimme@atix.de> - 0.3-12
- First stable 0.3 version


* Mon Jan  3 2005 Marc Grimme <grimme@atix.de> - 0.1-16
- first offical rpm version

%files

%dir %{APPDIR}/boot-scripts/sys
%dir %{APPDIR}/boot-scripts/var/log
%dir %{APPDIR}/boot-scripts/var/lib/dhcp
%dir %{APPDIR}/boot-scripts/var/run/netreport
%dir %{APPDIR}/boot-scripts/proc
%attr(750, root, root) /etc/init.d/bootsr
%attr(750, root, root) /etc/init.d/fenced-chroot
%attr(750, root, root) %{APPDIR}/create-gfs-initrd-generic.sh
%attr(750, root, root) %{APPDIR}/boot-scripts/linuxrc.generic.sh
%attr(750, root, root) %{APPDIR}/boot-scripts/exec_part_from_bash.sh
%attr(750, root, root) %{APPDIR}/boot-scripts/detectHardware.sh
%attr(750, root, root) %{APPDIR}/boot-scripts/rescue.sh
%attr(750, root, root) %{APPDIR}/boot-scripts/myifup.sh
%attr(750, root, root) %{APPDIR}/boot-scripts/linuxrc
%attr(750, root, root) %{APPDIR}/boot-scripts/linuxrc.bash
%attr(640, root, root) %{APPDIR}/create-gfs-initrd-lib.sh 
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/atix.txt
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/modules.conf
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/boot-lib.sh
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/gfs-lib.sh
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/comoonics-release
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/iscsi-lib.sh
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/lock_gulmd_mv_files.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/lock_gulmd_cp_files.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/lock_gulmd_dirs.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/fence_tool_mv_files.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/fence_tool_cp_files.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/fence_tool_dirs.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/syslogd_mv_files.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/syslogd_cp_files.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/syslogd_dirs.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/ccsd_mv_files.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/ccsd_cp_files.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/ccsd_dirs.list
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/sysconfig/comoonics
%attr(640, root, root) %{APPDIR}/boot-scripts/etc/inittab
%attr(640, root, root) %{APPDIR}/boot-scripts/linuxrc.part.bash.sh
%attr(640, root, root) %{APPDIR}/boot-scripts/linuxrc.part.gfs.sh
%attr(640, root, root) %{APPDIR}/boot-scripts/linuxrc.part.livecd.sh
%attr(640, root, root) %{APPDIR}/boot-scripts/linuxrc.part.urlsource.sh
%attr(640, root, root) %{APPDIR}/boot-scripts/linuxrc.part.iscsi.sh
%attr(640, root, root) %{APPDIR}/boot-scripts/linuxrc.part.install.sh
%config(noreplace) %{CONFIGDIR}/bootimage/gfs6-es30-files.i686.list
%config(noreplace) %{CONFIGDIR}/bootimage/gfs61-es40-files.i686.list
%config(noreplace) %{CONFIGDIR}/comoonics-bootimage.cfg

# ------
# $Log: comoonics-bootimage.spec,v $
# Revision 1.9  2006-01-28 15:01:49  marc
# fenced is restarted in the initrd
#
# Revision 1.8  2006/01/25 14:55:51  marc
# first stable 0.3
#
# Revision 1.7  2006/01/23 14:05:30  mark
# added bootsr
#
# Revision 1.6  2005/07/08 13:15:57  mark
# added some files
#
# Revision 1.5  2005/06/27 14:24:20  mark
# added gfs 61, rhel4 support
#
# Revision 1.4  2005/06/08 13:33:22  marc
# new revision
#
# Revision 1.3  2005/01/05 10:57:07  marc
# new release and added the latest files.
#
# Revision 1.2  2005/01/03 08:34:16  marc
# added new subversion for first offical rpm version
#
# Revision 1.1  2005/01/03 08:33:17  marc
# first offical rpm version
# - initial revision
#
#
