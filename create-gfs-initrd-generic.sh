#!/bin/bash
#
# $Id: create-gfs-initrd-generic.sh,v 1.4 2005-01-03 08:23:21 marc Exp $
#
# @(#)$File$
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
. `dirname $0`/create-gfs-initrd-lib.sh

function usage() {
  echo "$0 -d dep_filename [-s initrdsize] [-m mountpoint] [-r rpm-list-file] [-b build-date-file] initrdname [kernel-version]"
}

function getoptions() {
    while getopts vhm:fd:s:r:b: option ; do
	case "$option" in
	    v) # version
		echo "$0 Version "'$Revision: 1.4 $'
		exit 0
		;;
	    h) # help
		usage
		exit 0
		;;
	    m) # tempmount
		mountpoint="$OPTARG"
		;;
	    f) # force
		force=1
		;;
	    d) # depfile
		dep_filename="$OPTARG"
		;;
	    s) # size
		size="$OPTARG"
		;;
	    r ) # rpm-list
		rpm_list="$OPTARG"
		;;
	    b) # release file
		build_file="$OPTARG"
		;;
	    *)
		echo "Error wrong option."
		exit 1
		;;
	esac
    done
    shift $(($OPTIND - 1))
    initrdname=$(echo $1 | sed s/.gz$//)
    if [ -n "$2" ]; then kernel=$2; fi
}

if [ -z "$1" ]; then
  usage
  exit
fi

cfg_file=/etc/comoonics/comoonics-bootimage.cfg

cwd=$(pwd)
force=0
TMPDIR=/tmp
mountpoint=$(mktemp -d ${TMPDIR}/initrd.mnt.XXXXXX)
#size=32768
size=120000
kernel=$(uname -r)

if [ ${1:0:1} = "--" ]; then
    echo "detected request for old version of mkinitrd."
    echo "Params: $*"
    /sbin/mkinitrd $*
    exit $?
fi

source ${cfg_file}
getoptions $*

touch ./.building_initrd
#if [ -e $netenv_file ]; then . $netenv_file; fi

if [ -z "$dep_filename" ] || [ ! -e "$dep_filename" ]; then
  echo "No depfile given. A dep_file is required."
  usage
  exit 1
fi

echo -n "Makeing initrd ..."
make_initrd $initrdname $size || (echo "(FAILED)" && exit $?)
echo "(OK)"

echo -n "Mounting initrd ..."
mount_initrd $initrdname $mountpoint || (echo "(FAILED)" && exit $?)
echo "(OK)"

# extracting rpms
if [ -n "$rpm_list" ]; then
  echo -n "Extracting rpms..."
  extract_all_rpms $rpm_list $mountpoint || (echo "(FAILED)" && exit $?)
  echo "(OK)"
fi

# compiling marked perlfiles in this function
files=( $(get_all_files_dependent $dep_filename) )
# echo $files

echo -n "Copying files..."
cd $mountpoint
i=0
while [ $i -lt ${#files[@]} ]; do
  file=${files[$i]}
  if [ -d $file ]; then 
#    echo "Directory $file => ${mountpoint}/$file"
    create_dir ${mountpoint}/$file
    copy_file $file ${mountpoint}/$(dirname $file)
  elif [ ! -e "$file" ] && [ "$file" = '@map' ]; then
    i=$(( $i+1 ))
    file=${files[$i]}
    i=$(( $i+1 ))
    todir=${files[$i]}
    if [ -d $file ]; then 
#      echo "Directory mapping $file => ${mountpoint}/$todir"
      create_dir ${mountpoint}/$todir
      copy_file $file/\* ${mountpoint}/$todir/
    else
      dirname=`dirname $file`
      create_dir ${mountpoint}$todir
      copy_file $file ${mountpoint}$todir
    fi
  else
    dirname=`dirname $file`
    create_dir ${mountpoint}$dirname
    copy_file $file ${mountpoint}$dirname
  fi
  i=$(( $i+1 ))
done
echo "(OK)"

# copying kernel modules
echo -n "Copying kernelmodules ($kernel)..."
if [ ! -d ${mountpoint}/lib/modules/$kernel ]; then mkdir -p ${mountpoint}/lib/modules/; fi
cp -r /lib/modules/$kernel ${mountpoint}/lib/modules/$kernel || (echo "(FAILED)" && exit $?)
echo "(OK)"

# patching build file
if [ -n "$build_file" ]; then
    echo -n "Patching buildfile \"$build_file\"..."
    (echo "Build Date: "$(date) >> ${mountpoint}/$build_file && echo "(OK)") || echo "(FAILED)"
fi


#for module in $FC_MODULE $FC_MODULES $GFS_MODULES; do
#  dirname=`dirname ${MODULES_DIR}/${module}`
#  create_dir ${mountpoint}$dirname
#  copy_file ${MODULES_DIR}/${module} ${mountpoint}$dirname
#done

#echo "The following files reside on the image:"
#find .

cd $cwd
echo -n "Cleaning up ..."
(chown -R root:root $mountpoint && \
 sleep 1 && \
 umount_and_zip_initrd $mountpoint $initrdname $force && \
 rm ./.building_initrd) || (echo "(FAILED)" && exit $?)
echo "(OK)"
ls -lk $initrdname.gz