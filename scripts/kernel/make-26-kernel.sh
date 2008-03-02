#!/bin/sh

# UP kernel
/data/projets/dev/linux/scripts/build-kernel-26-list config-2.6.22-wt3-inj1-flx0.1-i686
ver=$(grep KERNELVERSION include/linux/autoconf.h|cut -f2 -d"'")
EXTRAVERSION=$ver sh ../make-self-mod.sh
/data/projets/dev/linux/scripts/build-kernel-26-list -i config-2.6.22-wt3-inj1-flx0.1-i686

# SMP kernel
/data/projets/dev/linux/scripts/build-kernel-26-list config-2.6.22smp-wt3-inj1-flx0.1-i686
ver=$(grep KERNELVERSION include/linux/autoconf.h|cut -f2 -d"'")
EXTRAVERSION=$ver sh ../make-self-mod.sh
/data/projets/dev/linux/scripts/build-kernel-26-list -i config-2.6.22smp-wt3-inj1-flx0.1-i686

# package it
/data/projets/dev/linux/scripts/kernel-to-pkg KERNEL-PKG kernel-2.6.22-wt3-inj1-flx0.1

