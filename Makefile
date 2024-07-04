# BIOS file names
SM1?=bin/sm1.sm1
LO?=bin/000-lo.lo
SFIX?=bin/sfix.sfix
SP?=bin/sp-s2.sp1

VASM?=vasm/vasmm68k_mot
VASM_OBJCOPY?=/usr/bin/m68k-linux-gnu-objcopy

# VASM
$(VASM):
	wget http://sun.hasenbraten.de/vasm/release/vasm.tar.gz
	tar -xzf vasm.tar.gz
	cd vasm && make CPU=m68k SYNTAX=mot -j 8

###############
# NeoGeo BIOS #
###############
bios: $(SP) $(SFIX) $(LO) $(SM1) | /usr/bin/zip
	zip -j -u neogeo.zip $^

# Empty Graphic ROM, this should be 128 KiB.
# This is the Fix map when no cartridge is inserted.
# TODO: Make a default sfix one.
$(SFIX): | bin
	dd if=/dev/zero bs=1024 count=128 of=$@

# Zoom ROM, this tells the program ROM how to scale the sprites.
# TODO: Make a script to generate this.
$(LO): | bin
	dd if=/dev/zero bs=1024 count=128 of=$@

# The default sound driver when no cartridge is inserted.
# TODO: Make a default one.
$(SM1): | bin
	dd if=/dev/zero bs=1024 count=64 of=$@

# The BIOS ROM.
SPSIZE:=524288
$(SP): bios/main.asm | $(VASM) $(VASM_OBJCOPY) bin
	$(VASM) -no-opt -Fbin -o $@ $<
	$(VASM_OBJCOPY) -I binary -O binary -S --gap-fill 0xff --pad-to $(SPSIZE) $@ $@
	dd if=$@ of=$@ conv=notrunc,swab

bin:
	mkdir bin

# Clean everything we built.
clean:
	rm -rf bin neogeo.zip
# Clean everything, even vasm.
cleanall:
	rm -rf bin neogeo.zip vasm*