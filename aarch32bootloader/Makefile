
CC_PREFIX   := /home/vmitrofanov/cm_tools/gcc-arm-none-eabi-7-2018-q2-update/bin
CC          := $(CC_PREFIX)/arm-none-eabi-gcc
CC_FLAGS    := -Wall -O0 -g -std=c99 -mcpu=cortex-a9 -nostartfiles
OBJDUMP     := $(CC_PREFIX)/arm-none-eabi-objdump
OBJCOPY     := $(CC_PREFIX)/arm-none-eabi-objcopy
LINK_SCRIPT := -T link_script.ld

target.elf: startup.s uart.s
	$(CC) $(CC_FLAGS) $(LINK_SCRIPT) $^ -o $@
	$(OBJDUMP) -D $@ > $@.dis
	$(OBJCOPY) -O binary $@ $@.bin
	
.PHONY: clean
clean: 
	rm -rf *.elf
	rm -rf *.dis
	rm -rf *.bin


