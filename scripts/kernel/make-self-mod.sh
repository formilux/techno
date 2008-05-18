#!/bin/bash

########
# if EXTRAVERSION is not set, keep those from the config
# eg: EXTRAVERSION=smp-wt3-inj1 $0

EXTRAVERSION=${EXTRAVERSION:-}

#cmd_gzip="gzip -9"
cmd_gzip="7za a -tgzip -mx9 -mpass=4 -si -so ."

tmpdir="$PWD/.tmp_mod"
rm -rf "${tmpdir}"/2.6* "${tmpdir}/System.map*"

if [ -z "${0##*/*}" ]; then
  DIR="${0%/*}"
else
  DIR="$PWD"
fi

tools26="$DIR/inst-mod26"

#make oldconfig ${EXTRAVERSION:+EXTRAVERSION=$EXTRAVERSION} LOCALVERSION='' CONFIG_LOCALVERSION=''
#make prepare ${EXTRAVERSION:+EXTRAVERSION=$EXTRAVERSION} LOCALVERSION='' CONFIG_LOCALVERSION=''
#make -j 4 vmlinux modules CONFIG_INITRAMFS_SOURCE="" CC=${CC:-gcc} HOSTCC=${HOSTCC:-gcc} ${EXTRAVERSION:+EXTRAVERSION=$EXTRAVERSION LOCALVERSION='' CONFIG_LOCALVERSION=''}
make modules_install INSTALL_MOD_STRIP="--strip-unneeded" INSTALL_MOD_PATH="${tmpdir}" CC=${CC:-gcc} HOSTCC=${HOSTCC:-gcc} ${EXTRAVERSION:+EXTRAVERSION=$EXTRAVERSION LOCALVERSION='' CONFIG_LOCALVERSION=''}

version=$(\ls "${tmpdir}/lib/modules/")
echo "Preparing initramfs for kernel $version..."
rm -rf initramfs && mkdir initramfs

rm -f "${tmpdir}/lib/modules/${version}/build" "${tmpdir}/lib/modules/${version}/source"

du -sc "${tmpdir}/lib/modules"
# WARNING! compressing modules slightly enlarges image but reduces RAMFS footprint
if [ -z "$DONT_GZIP_MODULES" ]; then
  echo "Compressing modules for kernel $version ..."
  find "${tmpdir}/lib/modules" -name '*.ko'| while read; do 
    ${cmd_gzip} <$REPLY >$REPLY.gz 2>/dev/null && rm -f $REPLY
  done
  du -sc "${tmpdir}/lib/modules"
fi

echo "Running depmod on compressed modules..."
depmod -ae -F System.map -b "${tmpdir}" -r $version

# It really looks like System.map serves no purpose at all on embedded systems.
#cp System.map "${tmpdir}/lib/modules/${version}/System.map"
#ln -s "${version}/System.map" "${tmpdir}/lib/modules/System.map-$version"
#tar --owner=root --group=root --mode=a+r,go-w -C "${tmpdir}/lib/modules" -cf - "${version}" "System.map-${version}" > initramfs/modules.tar
tar --owner=root --group=root --mode=a+r,go-w -C "${tmpdir}/lib/modules" -cf - "${version}" > initramfs/modules.tar

mkdir initramfs/{dev,proc,root}
cp "${tools26}/.preinit" initramfs/
cp "${tools26}/init" initramfs/
cp "${tools26}/busybox" initramfs/tar

make -j 4 bzImage CONFIG_INITRAMFS_SOURCE=$PWD/initramfs CC=${CC:-gcc} HOSTCC=${HOSTCC:-gcc} ${EXTRAVERSION:+EXTRAVERSION=$EXTRAVERSION LOCALVERSION='' CONFIG_LOCALVERSION=''}
rm "${tmpdir}" -rf

################
exit 0
################
# minimum requis
/dev
/.preinit
/init

/bin
/bin/busybox

################
A faire sur le .preinit :

# soit copie sur ram0 (respecte le root=)
cp /initrd.image /dev/ram0
rm /initrd.image
mt ${root-/dev/ram0} /flash ${rootfstype-squashfs} ${ro+ro} ${rw+rw}

# ou bien mount -o loop
mount -o loop /initrd.image /flash
rm /initrd.image

mount -t ramfs initrd /flash/boot
mv /boot/* /flash/boot/

################
Preinit minimaliste pour entrer des commandes, à exécuter en PID 1 :

cat >/cmd <<EOF
#!/init <
rd
br /bin/sh
EOF
chmod 755 /cmd
exec /cmd

REM: le pivot root ne fonctionne plus, et on ne peut pas faire de
mount --bind depuis le rootfs

=> on ne peut donc pas libérer la RAM utilisée par le / :-(

ex:
um /dev
pr /flash /mnt/floppy
in /sbin/init

Donc avec les nouvelles commandes :
mv /dev /flash/dev
/purge_root
sw /flash
in /sbin/init


> mt ${root-/dev/ram0} /flash ${rootfstype-squashfs} ${ro+ro} ${rw+rw}

