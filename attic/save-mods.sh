KVER=2.4.27-wt6-boot
mkdir -p temp
rm -rf temp/$KVER
mkdir -p temp/$KVER

tar cf - root --exclude=root/boot | tar -C temp/$KVER/ -xpf -

tar cf - boot/$KVER/kernel/arch boot/$KVER/kernel/drivers/{ide,ieee1394,net,pcmcia,scsi} boot/$KVER/kernel/{fs,lib} boot/$KVER/{pcmcia,System.map,.config*,modules.*} boot/System.map-$KVER | tar -C temp/$KVER/root -xpf -

mksquashfs temp/$KVER/root temp/$KVER/initrd.img -2.0 -noappend

