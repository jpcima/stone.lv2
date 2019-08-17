PREFIX ?= /usr/local
PLUGINS := stone_phaser.lv2 stone_phaser_stereo.lv2
LV2_URI_PREFIX := http://jpcima.sdf1.org/experimental-lv2

SED ?= sed # use gsed on BSD or Mac computer
# HACK: delete epp:rangeSteps from LV2 manifest, it confuses Ardour

all: $(PLUGINS)

clean:
	rm -rf $(PLUGINS)

stone_phaser.lv2: stone_phaser.dsp
	faust2lv2 -uri-prefix $(LV2_URI_PREFIX) $<
	$(SED) -i '/epp:rangeSteps/d' stone_phaser.lv2/stone_phaser.ttl

stone_phaser_stereo.lv2: stone_phaser_stereo.dsp stone_phaser.dsp
	faust2lv2 -uri-prefix $(LV2_URI_PREFIX) $<
	$(SED) -i '/epp:rangeSteps/d' stone_phaser_stereo.lv2/stone_phaser_stereo.ttl

install: all
	install -d $(DESTDIR)$(PREFIX)/lib/lv2
	$(foreach p,$(PLUGINS),cp -rfd $(p) $(DESTDIR)$(PREFIX)/lib/lv2;)

install-user: all
	test ! -z $(HOME)
	install -d $(HOME)/.lv2
	$(foreach p,$(PLUGINS),cp -rfd $(p) $(HOME)/.lv2;)
