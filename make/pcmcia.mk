#############################################################
#
# pcmcia card services
#
#############################################################
# Copyright (C) 2001-2003 by Erik Andersen <andersen@codepoet.org>
# Copyright (C) 2002 by Tim Riker <Tim@Rikers.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Library General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
# USA

PCMCIA_SOURCE:=pcmcia-cs-3.2.3.tar.gz
PCMCIA_SITE:=http://telia.dl.sourceforge.net/sourceforge/pcmcia-cs
PCMCIA_DIR:=$(BUILD_DIR)/pcmcia-cs-3.2.3
PCMCIA_PATCH:=$(SOURCE_DIR)/pcmcia.patch
PCMCIA_CAT:=zcat

$(DL_DIR)/$(PCMCIA_SOURCE):
	$(WGET) -P $(DL_DIR) $(PCMCIA_SITE)/$(PCMCIA_SOURCE)

pcmcia-source: $(DL_DIR)/$(PCMCIA_SOURCE)

$(PCMCIA_DIR)/.unpacked: $(DL_DIR)/$(PCMCIA_SOURCE)
	$(PCMCIA_CAT) $(DL_DIR)/$(PCMCIA_SOURCE) | tar -C $(BUILD_DIR) -xvf -
	touch $(PCMCIA_DIR)/.unpacked

$(PCMCIA_DIR)/.patched: $(PCMCIA_DIR)/.unpacked
	cat $(PCMCIA_PATCH) | patch -d $(PCMCIA_DIR) -p1
	touch $(PCMCIA_DIR)/.patched

$(PCMCIA_DIR)/.configured: $(PCMCIA_DIR)/.patched
	( cd $(PCMCIA_DIR) ; ./Configure --kernel=$(LINUX_DIR) --noprompt \
		--rcdir=/etc --arch=$(ARCH) --trust --srctree --nocardbus \
		--sysv --kcc=$(HOSTCC) --ucc=$(TARGET_CC) --ld=$(TARGET_CROSS)ld \
		--target=$(TARGET_DIR))
	touch $(PCMCIA_DIR)/.configured

$(PCMCIA_DIR)/cardmgr/cardmgr: $(PCMCIA_DIR)/.configured
	$(MAKE) -C $(PCMCIA_DIR) -i all
	-A=`find $(PCMCIA_DIR) -type f -perm +111` ; \
	for fo in $$A; do \
		file $$fo | grep "ELF" | grep "executable" > /dev/null 2>&1; \
		if [ $$? = 0 ] ; then \
			$(STRIP) $$fo; \
		fi; \
	done
	touch -c $(PCMCIA_DIR)/cardmgr/cardmgr

$(TARGET_DIR)/sbin/cardmgr: $(PCMCIA_DIR)/cardmgr/cardmgr
	rm -rf $(TARGET_DIR)/etc/pcmcia;
	$(MAKE) -i -C $(PCMCIA_DIR) install
	perl -i -p -e "s/pump/udhcpc/" $(TARGET_DIR)/etc/pcmcia/network
	perl -i -p -e "s/ide_cs/ide-cs/" $(TARGET_DIR)/etc/pcmcia/config
	perl -i -p -e "s/bind \"wvlan_cs\"/bind \"orinoco_cs\"/g" $(TARGET_DIR)/etc/pcmcia/config
	perl -i -p -e "s,/var/lib/pcmcia/scheme,/etc/pcmcia/scheme," $(TARGET_DIR)/etc/pcmcia/shared
	perl -i -p -e "s,/var/run/pcmcia-scheme,/etc/pcmcia/pcmcia-scheme," $(TARGET_DIR)/etc/pcmcia/shared
	#perl -i -p -e "s/port 0x800-0x8ff, //" $(TARGET_DIR)/etc/pcmcia/config.opts ;
	echo "default" > $(TARGET_DIR)/etc/pcmcia/scheme;
	rm -rf $(TARGET_DIR)/usr/man;
	rm -rf $(TARGET_DIR)/usr/share/man;
	rm -rf $(TARGET_DIR)/usr/X11R6/man;
	rm -rf $(TARGET_DIR)/etc/rc.d;
	rm -rf $(TARGET_DIR)/etc/rc?.d;
	rm -f $(TARGET_DIR)/etc/init.d/pcmcia.N;
	rm -f $(TARGET_DIR)/sbin/dump_cis $(TARGET_DIR)/sbin/pack_cis
	rm -f $(TARGET_DIR)/usr/share/pnp.ids $(TARGET_DIR)/sbin/lspnp $(TARGET_DIR)/sbin/setpnp;
	rm -f $(TARGET_DIR)/sbin/pcinitrd
	rm -f $(TARGET_DIR)/sbin/probe
	cp $(PCMCIA_DIR)/etc/rc.pcmcia $(TARGET_DIR)/etc/init.d/S30pcmcia
	chmod a+x $(TARGET_DIR)/etc/init.d/S30pcmcia
	chmod -R u+w $(TARGET_DIR)/etc/pcmcia/*

pcmcia: uclibc $(TARGET_DIR)/sbin/cardmgr

pcmcia-clean:
	rm -f $(TARGET_DIR)/sbin/cardmgr
	-$(MAKE) -C $(PCMCIA_DIR) clean
	rm -f $(PCMCIA_DIR)/.configured $(PCMCIA_DIR)/config.out

pcmcia-dirclean:
	rm -rf $(PCMCIA_DIR)
