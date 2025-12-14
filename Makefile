NASM = nasm
DD = dd
RM = rm -f
QEMU = qemu-system-x86_64
MKISO = genisoimage

.PHONY: all floppy iso qemu clean

all: peacedos.img

peacedos.img: boot.bin
	@echo "Creating 1.44MB floppy image..."
	$(DD) if=/dev/zero of=peacedos.img bs=512 count=2880
	$(DD) if=boot.bin of=peacedos.img conv=notrunc
	@echo "PeaceDOS image created: peacedos.img"

boot.bin: boot.asm
	@echo "Assembling PeaceDOS..."
	$(NASM) -f bin boot.asm -o boot.bin
	@echo "Bootloader size: $$(stat -c%s boot.bin) bytes"

iso: peacedos.img
	@echo "Creating bootable ISO..."
	$(MKISO) -o peacedos.iso -b peacedos.img -no-emul-boot -boot-load-size 4 -input-charset utf-8 .
	@echo "ISO image created: peacedos.iso"

qemu: peacedos.img
	@echo "Starting PeaceDOS in QEMU..."
	$(QEMU) -fda peacedos.img -m 16M -soundhw pcspk -rtc base=localtime

qemu-debug: peacedos.img
	@echo "Starting PeaceDOS with debug output..."
	$(QEMU) -fda peacedos.img -m 16M -d cpu_reset,int,guest_errors -D qemu.log -no-reboot

qemu-iso: iso
	$(QEMU) -cdrom peacedos.iso -m 16M

size: boot.bin
	@echo "=== Size Analysis ==="
	@echo "Boot sector: 512 bytes"
	@echo "Kernel size: $$(expr $$(stat -c%s boot.bin) - 512) bytes"
	@echo "Total: $$(stat -c%s boot.bin) bytes"
	@echo "Free space: $$(expr 1474560 - $$(stat -c%s boot.bin)) bytes"

clean:
	$(RM) boot.bin peacedos.img peacedos.iso qemu.log

deps:
	sudo apt-get update
	sudo apt-get install nasm qemu-system-x86 genisoimage

quick: clean all qemu

help:
	@echo "=== PeaceDOS Build System ==="
	@echo "make all      - Build floppy image"
	@echo "make iso      - Build bootable ISO"
	@echo "make qemu     - Run in QEMU"
	@echo "make clean    - Clean build files"
	@echo "make size     - Show size information"
	@echo "make deps     - Install dependencies"
	@echo "make quick    - Clean build and run"
