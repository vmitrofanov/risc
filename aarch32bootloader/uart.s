 @@@   
 @@@ SUBJECT: This is file implement simple UART functions
 @@@ AUTHOR: vmitrofanov
 @@@
 
    .text
    .global uart_init
    .global uart_read_str
    .global uart_write_str
    .global uart_write
    .global uart_read

    @@ Macro    
    .equ    UART_ISR_RXNE, 0x80
    .equ    UART_ISR_TXE, 0x20
    .equ    UART_CR1_TE, 0x1
    .equ    UART_CR1_RE, 0x4
    .equ    UART_CR1_UE, 0x8    

    @@ UART RCC
    .equ    RCC_BASE, 0x40023800
    .equ    RCC_APB1ENR, 0x40 + RCC_BASE

    @@ UART3 registers
    .equ    UART3_BASE, 0x40004800
    .equ    UART3_CR1, 0x00 + UART3_BASE
    .equ    UART3_ISR, 0x1C + UART3_BASE
    .equ    UART3_RDR, 0x24 + UART3_BASE
    .equ    UART3_TDR, 0x28 + UART3_BASE
    .equ    UART3_BRR, 0x0C + UART3_BASE

    @@ GPIO registers
    .equ    GPIOD_BASE, 0x40020C00 
    .equ    GPIOD_AFRH, 0x28 + GPIOD_BASE
    .equ    GPIOD_MODER, 0x00 + GPIOD_BASE
    
    @@ Settings
    .equ    UART_MAX_BUF_LEN, 0xFF
    
    
    @@ Init UART
    @@ 9600/8-N-1
    .func uart_init
    .type uart_init, %function
uart_init:
    @@ Enable UART clock
    ldr     r0, =RCC_APB1ENR
    mov     r1, #0x1
    lsr     r1, #0x8
    str     r1, [r0]            

    @@ Set GPIO as UART
    ldr     r0, =GPIOD_MODER
    mov     r1, #0x0
    mov     r2, #0x3            @ Alternative config
    orr     r1, r2, lsr #16     @ Set GPIO as alternative
    orr     r1, r2, lsr #18     @ Set GPIO as alternative
    str     r1, [r0]
    ldr     r0, =GPIOD_AFRH
    mov     r1, #0
    mov     r2, #0xB            @ UART config
    orr     r1, r2              @ Set GPIO as Tx
    orr     r1, r2, lsr #4      @ Set GPIO as Rx
    str     r1, [r0]

    @@ Set baudrate
    ldr     r0, =UART3_BRR      @ UART baud rate register
    mov     r1, #0x0            @ Zero register
    orr     r1, #0x64           @ Set PSC
    mov     r2, #0x3C           @ Set GT
    orr     r1, r2, lsr #8      @ Set GT

    @@ Enable UART
    ldr     r0, =UART3_CR1      @ Control register 1
    mov     r1, #0x0            @ Zero register
    orr     r1, #UART_CR1_TE    @ Transmit enable
    orr     r1, #UART_CR1_RE    @ Receive enable
    orr     r1, #UART_CR1_UE    @ UART enable
    str     r1, [r0]

    bx      lr
    .endfunc
    
    
    
    @@ Read symbol from UART
    .macro UART_READ
    ldr     r1, =UART3_ISR
1:    
    ldr     r2, [r1]
    tst     r2, #UART_ISR_RXNE
    beq     1b                      @ Wait while read buffer is empty
    ldr     r0, =UART3_RDR          @ Get received value
    ldr     r0, [r0]                @ Get received value
    .endm
    
    
    
    @@ Write symbol to UART
    .macro UART_WRITE  
    ldr     r1, =UART3_ISR
1:    
    ldr     r2, [r1]
    tst     r2, #UART_ISR_TXE
    beq     1b                      @ Wait while transfer buffer is full
    ldr     r1, =UART3_TDR          @ Send value
    str     r0, [r1]                @ Get received value
    .endm
    

    @@ This function is used as wripper to be called from other modules
    .func uart_write
    .type uart_write, %function
uart_write:
    UART_WRITE
    .endfunc


    @@ This function is used as wripper to be called from other modules
    .func uart_read
    .type uart_read, %function
uart_read:
    UART_READ
    .endfunc

    
    
    @@ Wait string from UART. The end of string is \n symbol
    @@ R0 - 0 if success, 1 - if failure
    @@ R1 - pointer to input string buffer
    @@ This function echo input symbols
    .func uart_read_str
    .type uart_read_str, %function
uart_read_str:
    mov     r2, #UART_MAX_BUF_LEN   @ Init protection counter
    push    {r1}
    UART_READ                       @ Wait symbol in blocking mode
    subs     r2, #1                 @ Decrement protection iterator
    blt     uart_read_str_exit      @ If overflow occur exit
    strb    r0, [r1]                @ Store read value to input buffer
    add     r1, #1                  @ Step to next byte
    UART_WRITE                      @ Echo input symbol
    cmp     r0, #'\n'
    bne     uart_read_str           @ Read until the end of str occur
    
uart_read_str_exit:    
    pop     {r1}
    bx lr
    .endfunc
    
    
    
    @@ Write UART string
    @@ R0 store pointer to transmit string
    .func uart_write_str
    .type uart_write_str, %function
uart_write_str:
    mov     r2, #UART_MAX_BUF_LEN
    push    {r1}                    @ push pointer
    ldrb    r0, [r1]                @ Read byte from buffer
    UART_WRITE                      @ Output char
    subs    r2, #1                  @ Decrement protection iterator
    blt     uart_write_str_exit     @ If overflow occur exit
    add     r1, #1                  @ Move pointer
    cmp     r0, #'\n'               @ Check if it was last symbol
    bne     uart_write_str          @ Loop until last symbol occur
    
uart_write_str_exit:    
    pop     {r1}
    bx      lr
    .endfunc


 
