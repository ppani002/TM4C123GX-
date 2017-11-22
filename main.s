	;Include constants I define to main	
	INCLUDE my_Constants.s	
	IMPORT PB5_MASK
	
	
	AREA |.text|, CODE, READONLY
	THUMB
	EXPORT __main
	ENTRY
	
;Input arguments:
;	r0: IRQn
;	r1: 1 = Enable, 0 = Disable
NVIC_Init	PROC
	PUSH {r4, LR} ;Push context onto stack
	
	AND r2, r0, #0x1F	;Bitoffset
	MOV r3, #1
	LSL r3, r3, r2 ;Shift enable/disable bit to correct bit position
	LDR r4, =SYS_PERIPH ;NVIC base address
	
	CMP r1, #0 ;Want to enable to disable?
	LDRNE r1, =NVIC_ENn
	LDREQ r1, =NVIC_DISn
	
	ADD r1, r4, r1 ;add offset to base address
	LSR r2, r0, #5 ;find register number n. IRQn/32
	LSL r2, r2, #2 ;Wordoffset with 0 extend. Finds register n address
	
	STR r3, [r1, r2]
	
	POP {r4,LR}
	BX LR
	
	ENDP

;Input Arguments:
;	r0: IRQn
;	r1: Priority level 0~7
NVIC_Priority	PROC
	PUSH {r4, LR} ;Push context onto stack
	
	AND r2, r0, #0x03 ;Bitoffset for TBB (case index)
	
	LDR r3, =SYS_PERIPH
	LDR r4, =NVIC_PRIn
	ADD r3, r3, r4
	LSR r4, r0, #2 
	LSL r4, r4, #2
	
	;TBB might only work in THUMB2 
	TBB [PC, r2]

BranchTable
	DCB (Case_0 - BranchTable)/2 ;index 0: Case_0
	DCB (Case_1 - BranchTable)/2 ;index 1: Case_1
	DCB (Case_2 - BranchTable)/2 ;index 2: Case_2
	DCB (Case_3 - BranchTable)/2 ;index 3: Case_3
	ALIGN
		
Case_0
	LSL r1, r1, #5 ;Shift to [7:5]
	B exit
Case_1
	LSL r1, r1, #13 ;Shift to [15:13]
	B exit
Case_2
	LSL r1, r1, #21 ;Shift to [23:21]
	B exit
Case_3
	LSL r1, r1, #29 ;Shift to [31:29]
	B exit
	
exit
	STR r1, [r3, r4]
	
	POP {r4,LR}
	BX LR
	
	ENDP
	
	
GPIO_Init	PROC
	;Save context
	PUSH {LR}
	
	;select APB. GPIOHBCTL
	LDR r0, =SYS_CONTROL
	LDR r1,[r0, #GPIOHBCTL]
	ORR r1, r1, #(1<<1) ;Enable port B AHB instead. "Note that GPIO can only be accessed through the AHB aperture
	STR r1,[r0, #GPIOHBCTL]
	
	;set to output. GPIODIR
	LDR r0, =AHB_PORTB
	LDR r1,[r0,#GPIODIR]
	ORR r1, r1, #(1<<5);pin5
	STR r1,[r0,#GPIODIR]
	
	;set mode to GPIO (nor alternate function). GPIOAFSEL
	LDR r0, =AHB_PORTB
	LDR r1,[r0,#GPIOAFSEL]
	BFC r1,#0,#8 ;clears fields. 0 = GPIO
	STR r1,[r0,#GPIOAFSEL]
	
	;to drive strength to 2mA. GPIODR2R
	LDR r0, =AHB_PORTB
	LDR r1,[r0,#GPIODR2R]
	ORR r1, r1, #(1<<5);pin5
	STR r1,[r0,#GPIODR2R]
	
	;set to pull up. GPIOPUR
	LDR r0, =AHB_PORTB
	LDR r1,[r0,#GPIOPUR]
	ORR r1, r1, #(1<<5) ;pin5
	STR r1,[r0,#GPIOPUR]
	
	;enable digital output. GPIODEN
	LDR r0, =AHB_PORTB
	LDR r1,[r0,#GPIODEN]
	ORR r1,r1, #(1<<5);pin 1 = digital output enable
	STR r1,[r0,#GPIODEN]
	
	;write "high" to data register for port B pin 5 to turn on red LED. GPIODATA
	LDR r0, =AHB_PORTB
	LDR r1,[r0,#GPIODATAPB5]
	LDR r2, =PB5_MASK	;get RAM address of PB5 mask (pointer)
	LDR r3,[r2]	;get the value of PB5 mask
	ORR r1, r1, r3	;Set PB5 to 'high'
	STR r1,[r0,#GPIODATAPB5]
	
	;Restore context
	POP {LR}
	BX LR
	ENDP
		
		
;Initializes RCGC for GPIO and Timer0 at run-time
RCGC_Init	PROC
	;Save context
	PUSH {LR}
	
	;Initialize Timer0 for run-time via RCGC
	LDR r0, =SYS_CONTROL
	LDR r1,[r0, #RCGCTIMER]
	BFC r1,#0,#6 ;clear fields [5:0]
	ORR r1, r1, #1 ;R0 = 1: enable Timer0
	STR r1,[r0, #RCGCTIMER]
	
	
	;Initialize GPIO PortB for run-time via RCGC
	;Enable clock. RCGCGPIO
	LDR r0, =SYS_CONTROL 
	LDR r1,[r0,#RCGCGPIO]
	ORR r1, r1, #(1<<1) ;enable port B clock(bit 5)
	STR r1,[r0,#RCGCGPIO]
	
	
	;Restore context
	POP {LR}
	BX LR
	ENDP
		

;This subroutine initialies SysTick
SysTick_Init	PROC
	
	;Push LR onto stack first
	PUSH {LR}
	
	;Clear ENABLE bit. STCTRL
	LDR r0, =SYS_PERIPH
	LDR r1, [r0,#STCTRL]
	AND r1, r1, #0	;Clear bit 0
	STR r1, [r0, #STCTRL]
	
	;Set reload value. STRELOAD
	LDR r0, =SYS_PERIPH
	LDR r1, [r0,#STRELOAD]
	ORR r1, r1, #(1<<5);23) ;Set interrupt period here
	STR r1, [r0,#STRELOAD]
	
	;Clear timer and interrupt flag. STCURRENT
	LDR r0, =SYS_PERIPH
	LDR r1, [r0,#STCURRENT]
	ORR r1, r1, #1 ;Write any value to reset
	STR r1, [r0,#STCURRENT]
	LDR r1, [r0,#STCURRENT]
	
	;Set CLK_SRC bit to use the system clock (PIOSC). STCTRL
	LDR r0, =SYS_PERIPH
	LDR r1, [r0,#STCTRL]
	ORR r1, r1, #(1<<2) ;bit 2
	STR r1, [r0,#STCTRL]
	
	;Set INTEN bit to enable interrupts. STCTRL
	LDR r0, =SYS_PERIPH
	LDR r1, [r0,#STCTRL]
	ORR r1, r1, #(1<<1) ;bit 1
	STR r1, [r0,#STCTRL]
	
	;Set ENABLE bit to turn SysTick on again. STCTRL
	
	
	;Set TICK priority field. SYSPRI3
	LDR r0, =SYS_PERIPH
	LDR r1, [r0,#SYSPRI3]
	ORR r1, r1, #(1<<29) ;priority 1. TICK begins at bit 29
	STR r1, [r0,#SYSPRI3]
	
	;Set ENABLE bit to turn SysTick on again. STCTRL
	LDR r0, =SYS_PERIPH
	LDR r1, [r0,#STCTRL]
	ORR r1, r1, #1 ;bit 0
	STR r1, [r0,#STCTRL]
	
	
	;Pop LR and return to __main
	POP {LR}
	BX LR
	
	ENDP


;Specifically for Timer0. Generalize this function		
TIMER_Init	PROC
	;Save context
	PUSH {LR}
	
	;Disable Timer0A
	LDR r1, =TIMER16_0
	LDR r2,[r1, #GPTMCTL]
	BFC r2,#0,#1 ;clear TAEN to disable Timer0A
	STR r2,[r1, #GPTMCTL]
	
	
	;Concatanate withh 0x0. Seperate with 0x4
	LDR r1, =TIMER16_0
	LDR r2,[r1, #GPTMCFG]
	BFC r2,#0,#3 ;Clear bits
	ORR r2, r2, #0x0 ;Concatanate timers
	STR r2,[r1, #GPTMCFG]
	
	
	;Configure Timer mode
	LDR r1, =TIMER16_0
	LDR r2,[r1, #GPTMTAMR]
	
	;No snapshot mode
	BFC r2,#7,#1 
	
	;Disable interrupts when counter == CCR
	BFC r2,#5,#1 
	;ORR r2,r2,#(1<<5);Enable interrupts when counter == CCR
	
	;count down
	BFC r2,#4,#1 
	
	;Set periodic mode
	BFC r2,#0,#2
	ORR r2, r2,#(0x2)
	
	STR r2,[r1, #GPTMTAMR]
	
	
	;Set ARR value
	LDR r1, =TIMER16_0
	LDR r2,[r1, #GPTMTAILR]
	BFC r2,#0,#32 ;
	MOV r2,#0x00FFFFFF ;#0x3E42
	STR r2,[r1, #GPTMTAILR]
	
	
	;Set Prescale value
	LDR r1, =TIMER16_0
	LDR r2,[r1, #GPTMTAPR]
	BFC r2,#0,#8
	;ORR r2,r2,#0xFF
	STR r2,[r1, #GPTMTAPR]
	
	
	;Set interrupts at timeout
	LDR r1, =TIMER16_0
	LDR r2,[r1, #GPTMIMR]
	BFC r2,#0,#1
	ORR r2,r2,#1;Enable interrupts at timeout
	STR r2,[r1, #GPTMIMR]
	
	
	
	;Prevents Timer0A from freezing during debug
	LDR r1, =TIMER16_0
	LDR r2,[r1, #GPTMCTL]
	BFC r2,#9,#1
	ORR r2,r2,#(1<<9) ;Set TASTAL to 1 to prevent stopping during debug
	BFC r2,#4,#1
	ORR r2,r2,#(1<<4) ;Set RCTEN to 1 to prevent stopping during debug
	STR r2,[r1, #GPTMCTL]
	
	
	
	;Enable Timer0A
	LDR r1, =TIMER16_0
	LDR r2,[r1, #GPTMCTL]
	BFC r2,#0,#1 
	ORR r2,r2,#1 ;Set TAEN to enable Timer0A
	STR r2,[r1, #GPTMCTL]
	
	;Restore context
	POP {LR}
	BX LR
	ENDP
		
__main	PROC
	
	;Setup clocks for GPIO and GPTM at run-time
	BL RCGC_Init
	
	;Setup GPIO first
	BL GPIO_Init
	
	;Setup priority level for Timer0A
	MOV r0, #19; Timer0A is IRQn = 19
	MOV r1, #1 ;priority #1
	BL NVIC_Priority
	
	;Enable Timer0A interrupt
	MOV r0, #19; Timer0A is IRQn = 19
	MOV r1, #1; r1 = 1: Enable
	BL NVIC_Init
	
	;Setup Timer0A
	BL TIMER_Init
	
while
	
	B while
	
	ENDP
		
	END