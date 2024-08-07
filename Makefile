# BIOS file names
SM1?=bin/sm1.sm1
LO?=bin/000-lo.lo
SFIX?=bin/sfix.sfix
SP?=bin/sp-s2.sp1

OBJCOPY?=/usr/bin/objcopy
VASM_M68K?=vasm/vasmm68k_mot
VASM_Z80?=vasm/vasmz80_oldstyle
VASM_OBJCOPY?=/usr/bin/m68k-linux-gnu-objcopy

# VASM
# Download VASM repo.
vasm:
	wget http://sun.hasenbraten.de/vasm/release/vasm.tar.gz
	tar -xzf vasm.tar.gz

$(VASM_M68K): | vasm
	cd vasm && make CPU=m68k SYNTAX=mot -j 8

$(VASM_Z80): | vasm
	cd vasm && make CPU=z80 SYNTAX=oldstyle -j 8

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
SM1SIZE=65536
$(SM1): bios/sm1.asm | $(VASM_Z80) $(OBJCOPY) bin
	$(VASM_Z80) -Fbin -o $@ $<
	$(OBJCOPY) -I binary -O binary -S --gap-fill 0xff --pad-to $(SM1SIZE) $@ $@

# The BIOS ROM.
SPSIZE:=524288
$(SP): bios/main.asm | $(VASM_M68K) $(VASM_OBJCOPY) bin
	$(VASM_M68K) -no-opt -Fbin -o $@ $<
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