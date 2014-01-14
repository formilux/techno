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
	$(Q)echo "Formilux Techno version $(VERSION) successfully installed into $(DEST)/."
	$(Q)echo "Don't forget to add the following line to your .profile or equivalent :"
	$(Q)echo
	$(Q)echo "   export FLXTECHNO=$(DEST)"
	$(Q)echo "   export PATH=\$$PATH:\$${FLXTECHNO}/bin"
	$(Q)echo
	$(Q)echo "You may also want to set up one or serveral source cache directories using"
	$(Q)echo "variable FLX_SRC_CACHE_DIRS. Directories are space-delimited and consulted"
	$(Q)echo "from left to right and may optionally be left read-only if suffixed with ':r'."
	$(Q)echo "Example:"
	$(Q)echo
	$(Q)echo "   export FLX_SRC_CACHE_DIRS=\"/cache/src /nfs/formilux/cache/src:r\""
	$(Q)echo

git-tar:
	$(Q)cd $(TOPDIR) && git archive --format=tar --prefix="$(COMPONENT)-$(VERSION)/" HEAD | gzip -9 > $(COMPONENT)-$(VERSION)$(SUBVERS).tar.gz
