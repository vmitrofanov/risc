### UART Bootloader brief
This is simple bootloader and it is written on GNU assembler for ARM 32-bit arch "X" board.
It consumes symbols from UART in format [CMD] [ADDR] [DATA_LEN] [DATA]. Bootloader can load to CRAM or FLASH memory.
There is no autojump routine after flash.

### CMD format
[CMD] [ADDR] [DATA_LEN] [DATA]
CMD: R - read;
     W - write;
     S - set pointer to memory

### UART settings: 
115200n8

### Build
Call ```make``` from current directory

### License
GNU General Public License


