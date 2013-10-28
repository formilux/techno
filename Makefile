COMPONENT := formilux-techno
VERSION   := 2.0
SUBVERS   :=

# set this to non-empty to enable verbose execution
V :=

ifneq ($(V),)
Q=
else
Q=@
endif

# Find the path to the directory containing this Makefile. This method
# works even with old versions of GNU make.
TOPDIR := $(dir $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST)))

all:
	$(Q)echo "Usage: make install DEST=<target dir>"; echo "Eg: make install DEST=/opt/flx2";echo

install:
	$(Q)test -n "$(DEST)" || { echo "Usage: make install DEST=<target dir>"; echo "Eg: make install DEST=/opt/flx2"; exit 1; }
	$(Q)mkdir -p "$(DEST)"
	$(Q)cp -R scripts build "$(DEST)/"

git-tar:
	$(Q)cd $(TOPDIR) && git archive --format=tar --prefix="$(COMPONENT)-$(VERSION)/" HEAD | gzip -9 > $(COMPONENT)-$(VERSION)$(SUBVERS).tar.gz
