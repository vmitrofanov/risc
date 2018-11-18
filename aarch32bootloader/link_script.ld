ENTRY(_reset)

_stack_top = ORIGIN(ram) + LENGTH(ram);
_ram_length = LENGTH(ram);
_ram_top = ORIGIN(ram);
_rom_length = LENGTH(rom);
_rom_top = ORIGIN(rom);

MEMORY
{
    ram : ORIGIN = 0x20000000, LENGTH = 320K
    rom : ORIGIN = 0x08000000, LENGTH = 1024K
}

SECTIONS
{
    .vec_table :
    {
        KEEP(*(.vec_table))
    } > rom

    .text : ALIGN(4)
    {
        *(.text)
    } > rom
    
    .data :
    {
        *(.data)
    } > rom
}

