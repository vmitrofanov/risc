@@@
@@@ AUTHOR: vmitrofanov
@@@
    .arm
    .global _reset
    
    @@ Extern
    .extern uart_init
    .extern uart_read_str
    .extern uart_write_str
    .extern uart_write
    .extern uart_read

    @@ CPU registers    
    .equ    RCC_BASE, 0x40023800
    .equ    RCC_CR1, 0x00 + RCC_BASE
    .equ    PLL_CFGR, 0x04 + RCC_BASE
   
    @@ Areas restriction
    .equ    RAM_LEN, _ram_length
    .equ    RAM_TOP, _ram_top
    .equ    FLASH_TOP, _rom_top
    .equ    FLASH_LEN, _rom_length
    
    @@ Macros
    .equ    CMD_WRITE, 87
    .equ    CMD_READ, 82
    .equ    CMD_SET_WRITER, 83
    .equ    CMD_HELP, 72

    @@ Register synonym
    POINTER_TO_WRITER .req R12
    
    @@ Variables
    .text
greeting_msg:
    .asciz "\n*** Bootloader console ***"
input_symbol:
    .asciz "\n>"
cmd_err_msg:
    .asciz "Error, invalid command"
help_rd_msg:
    .asciz "Read memory. Output memory to UART...........: R [hex_addr] [hex_len_bytes]\n"
help_wr_msg:
    .asciz "Write memory. Get writable date from UART....: W [hex_addr] [hex_len_bytes]\n"
help_st_msg:
    .asciz "Set writer pointer...........................: S [hex_addr] phex_len_bytes]\n"


    
@@@ Vectors table     
    .section .vec_table, "a"
    ldr     pc, =_reset 
    ldr     pc, =_dummy     @ Undefined
    ldr     pc, =_dummy     @ SWI
    ldr     pc, =_dummy     @ Prefetch abort
    ldr     pc, =_dummy     @ Data abort
    ldr     pc, =_dummy     @ IRQ
    ldr     pc, =_dummy     @ FIQ
    
    @@ Reset vector
    .section .text
    .align 4
_reset:
    @@ Set stack
    ldr     sp, =_stack_top

    @@ Prepare CPU to work
    bl      cpu_acc         @ Accelerate CPU
    bl      uart_init       @ Initialize UART
    
    @@ Implement main logic
    bl      _main_
    b       .
    


    @@ Dummy function for undescribed interrupts
    .type _dummy, %function
    .func _dummy
_dummy:
    ldr     r0, =0xB002C0DE     @ Indicate we are in trap
    b .
    .endfunc 

    
    
@@@ Main logic
@@@ Implement reading iHex and loading it into FLASH or CRAM
    .func _main_
    .type _main_, %function
_main_:
    @@ Output greeting
    ldr     r0, =greeting_msg
    bl      uart_write_str
        
    @@ Get command
read_input:    
    ldr     r0, =input_symbol   @ Output input symbol
    bl      uart_write_str      @ Output input symbol
    bl      uart_read_str       @ Waiting input string
    
    @@ Parse string to get command
    mov     r0, r1
    bl      parse_cmd           @ R0 - result, R1 - cmd code, R2 - addr, R3 - len
    cmp     r0, #0
    bne     output_err_msg
    
    @@ Procees result
    cmp     r1, #CMD_READ   
    ldr     r0, =read_mem
    beq     do_cmd
    
    cmp     r1, #CMD_WRITE   
    ldr     r0, =write_mem
    beq     do_cmd
    
    cmp     r1, #CMD_SET_WRITER   
    ldr     r0, =set_writer
    beq     do_cmd
    
    cmp     r1, #CMD_HELP   
    ldr     r0, =help
    beq     do_cmd

    @@ If we here invalid opcod occur
    ldr     r0, =cmd_err_msg    @ Output message
    bl      uart_write_str      @ Output message
    b       read_input          @ Next iteration
    
do_cmd:    
    mov     r1, r2              @ Move addr argument
    mov     r2, r3              @ Move len argument
    
    blx     r0                  @ Jump to command hendler
    b       read_input          @ Next iteration
    
output_err_msg:
    ldr     r0, =cmd_err_msg
    bl      uart_write_str
    b       read_input    
    
    @@ By this moment R1 contain pointer to the result msg string
exit:
    mov     r0, r1
    bl      uart_write_str      
    b .
    
    pop     {r4}
    bx      lr
    .endfunc
    
    
    
    @@ Output help
    .func help
    .type help, %function
help:
    ldr     r0, =help_rd_msg
    bl      uart_write_str
    ldr     r0, =help_wr_msg
    bl      uart_write_str
    ldr     r0, =help_st_msg
    bl      uart_write_str
    ldr     r0, =input_symbol
    bl      uart_write_str
    
    bx      lr
    .endfunc    
    


    @@ Set pointer to writer
    .func set_writer
    .type set_writer, %function
set_writer:
    mov     POINTER_TO_WRITER, r1
    bx      lr
    .endfunc    
    
    
    
    @@ Write memory. Input len bytes from UART 
    @@ R0 - return result
    @@ R1 - addr 
    @@ R2 - length
    .func write_mem
    .type write_mem, %function
write_mem:  
    push    {r4}
    mov     r4, sp                  @ Save SP
    mov     r3, r2                  @ Save length
    
    @@ Read data from UART to inner buffer. Inner buffer store in stack
write_mem_get_data:
    cmp     r2, #0
    blt     do_write_mem
    bl      uart_read               @ Read symbol
    strb    r0, [r3]                @ Store symbol into buffer
    sub     r3, #1                  @ Move next 
    b       write_mem_get_data

do_write_mem:      
    mov     r2, r3                  @ Restore length
    mov     sp, r4                  @ Restore SP
    blx     POINTER_TO_WRITER       @ Do write to memory
    pop     {r4}
    bx      lr
    .endfunc
    
    
    
    @@ Read memory. Output to UART
    @@ R0 - return result
    @@ R1 - addr 
    @@ R2 - length
    .func read_mem
    .type read_mem, %function
read_mem:
    cmp     r2, #0              @ Check whether we transfer all bytes
    beq     read_mem_exit       @ If all bytes transfer exit
    ldrb    r0, [r1]            @ Read byte to transger
    bl      uart_write          @ Output byte
    sub     r2, #1              @ Decrease num of bytes to transfer
    b       read_mem            @ Next iteration    

read_mem_exit:
    mov     r0, #0              @ Read with success
    bx      lr
    .endfunc
    
    
    
    @@ Parse cmd
    @@ R0 - strore pointer to cmd string
    @@ R0 - Return 0 - if success, 1 - if failure
    @@ R1 - opcode
    @@ R2 - address
    @@ R3 - length
    .func parse_cmd
    .type parse_cmd, %function
parse_cmd:
    push     {r4-r7}
    bl      ascii_to_sym    @ Convert opcode
    mov     r6, r1          @ Save opcode
    add     r0, #2          @ Move ptr to address
    bl      ascii_to_int    @ Convert address
    mov     r5, r1          @ Save address
    add     r0, #9          @ Move ptr to length
    bl      ascii_to_int    @ Convert length
    mov     r3, r1          @ Length
    mov     r2, r5          @ Address
    mov     r1, r5          @ Opcode
    mov     r0, #0          @ Success
    pop     {r4-r7}
    bx      lr
    .endfunc
       
        
    
    @@ Increase CPU frequency up to max
    .func cpu_acc
    .type cpu_acc, %function
cpu_acc:
    @@ Enable PLL 
    ldr     r0, =RCC_CR1
    mov     r1, #0x1
    lsr     r1, #24             @ PLL_ON
    str     r1, [r0]            @ Set PLL_ON
    lsr     r1, #0x1            @ PLL_RDY
pll_rdy:
    ldr     r2, [r0]   
    tst     r2, r1              @ Check if it is ready
    beq     pll_rdy             @ Wait while pll is getting up

    @@ Configure PLL
    ldr     r0, =PLL_CFGR
    ldr     r1, =0xA7           @ Confugure PLL to rise up max freq
    str     r1, [r0]            @ Confugure PLL to rise up max freq
    bx      lr
    .endfunc   



    @@ HEX to symbol. Convert 1 HEX symbol to 1 hexademical symbol
    @@ R0 - pointer to HEX symbol
    .func ascii_to_sym
    .type ascii_to_sym, %function
ascii_to_sym:
    @@ Check sym [0;9]
    ldrb    r1, [r0]
    cmp     r1, #'0'
    blo     check_letter
    cmp     r1, #'9'
    bhi     check_letter

    @@ Calculate if sym [0;9]
    sub     r1, #'0'
    b       ascii_exit

check_letter:
    cmp     r1, #'A'
    blo     ascii_exit
    cmp     r1, #'F'
    bhi     ascii_exit

    @@ Calculate if sym [A;F]
    sub     r1, #'A'
    add     r1, #0xA

ascii_exit:
    bx      lr
    .endfunc



    @@ HEX to char. Convert 1 HEX symbol to char
    .func ascii_to_char
    .type ascii_to_char, %function
ascii_to_char:
    push    {r0}
    mov     r3, #0          @ Zero tmp buffer
    b       ascii_to_sym    @ Convert
    orr     r3, r1          @ Save result
    lsl     r3, #4          @ Get high part
    add     r0, #1
    b       ascii_to_sym
    orr     r3, r1          @ Get low part
    mov     r1, r3          @ Mov result to R1
    pop     {r0}
    bx      lr
    .endfunc



    @@ HEX to int. Convert 8 HEX symbol to 4 byte int
    .func ascii_to_int
    .type ascii_to_int, %function
ascii_to_int:
    push    {r0}
    mov     r2, #4
    mov     r3, #0          @ Zero tmp buffer
ascii_to_int_calc:
    b       ascii_to_char   @ Convert
    orr     r3, r1          @ Save result
    lsl     r3, #8          @ Get high part
    add     r0, #2          @ Move to next byte
    b       ascii_to_char
    orr     r3, r1          @ Get low part

    sub     r2, #1          @ Decrement iterator
    cmp     r2, #0           
    blt     ascii_int_exit  @ If 4 bytes calculated then exit
    lsl     r3, #8          @ Prepare to next iteration
    add     r0, #2          @ Prepare to next iteration
    b       ascii_to_int_calc

ascii_int_exit:
    mov     r1, r3          @ Mov result to R1
    pop     {r0}
    bx      lr
    .endfunc
    
