.syntax unified
.global main

@ SysTick vars
.set RVR_1MS,      64000
.set RVR_0_5MS,    32000
@ Timer vars
.set TIMER0_1MS,   1000
.set TIMER0_0_5MS, 500

.type main, %function
main:
  nop
  push {lr}
  bl init_leds
  pop {lr}

  bl create_process
  bl switch_context

.size main, .-main

.type ledblink, %function
ledblink:
  push {lr}
  bl leds_toggle
  pop {lr}

  ldr r0, =0x30D400
  push {lr}
  bl delay
  pop {lr}

  push {lr}
  bl leds_toggle
  pop {lr}

  ldr r0, =0x30D400
  push {lr}
  bl delay
  pop {lr}

  b ledblink

.type create_process, %function
create_process:
  @ loads the new stack pointer address (above) into sp
  ldr sp, =0x20008000

  @ decrements the stack pointer by 32 bytes (8 registers, 4 bytes per register) 
  @ to make “room” for the things you need to put on the stack
  sub sp, sp, 32

  @ writes the correct values on the stack (see the picture above) to represent a running ledblink-loop
  @ the status register (you can use the default value of 0x01000000) goes at an offset of 28 from your new stack pointer
  ldr r1, =0x01000000
  str r1, [sp, 28]

  @ the program counter pc should point to the next instruction (which might be a label) to execute when the process is restored
  ldr r0, =ledblink
  str r0, [sp, 24]
  
  @ the link register lr should point to the instruction for the process to return to when it’s “done” 
  @ (this doesn’t matter so much for the moment, because your ledblink loop is infinite—it never bx lrs anywhere)
  ldr r0, =0x100
  str r0, [sp, 20]

  @ put whatever values you need into the slots for r12 and then r3-r0
  @ —these are just the register values (arguments, basically) for your ledblink process 
  @ (think: do you need anything particular in here, or does it not matter for how your ledblink loop runs?)
  mov r0, 12
  str r0, [sp, 16]
  mov r0, 3
  str r0, [sp, 12]
  mov r0, 2
  str r0, [sp, 8]
  mov r0, 1
  str r0, [sp, 4]
  mov r0, 0
  str r0, [sp]
  bx lr
.size create_process, .-create_process

.type switch_context, %function
switch_context:
  @ restore (i.e. put back) the flags into the xpsr register 
  @ (since this is a special register you can’t just ldr into it, 
  @ you have to load into a normal register like r0 first 
  @ and then use the “move to special register” instruction4 msr apsr_nzcvq, r0)
  ldr r0, [sp, 28]
  msr apsr_nzcvq, r0

  @ restore the rest of the registers except for pc
  ldr lr, [sp, 20]
  ldr r12, [sp, 16]
  ldr r3, [sp, 12]
  ldr r2, [sp, 8]
  ldr r1, [sp, 4]
  ldr r0, [sp]

  @ make sure the stack pointer sp points to the “new” top of the stack 
  @ (i.e. after the ledblink context has been popped off)

  @ finally, set the ledblink process running by restoring the pc. 
  @ Make sure that you have declared ledblink as a function, e.g.
  ldr pc, [sp, 24]
  bx lr
.size switch_context, .-switch_context

.global SysTick_Handler
.type SysTick_Handler, %function
SysTick_Handler:
  push {lr}
  nop

  pop {lr}
  bx lr
.size SysTick_Handler, .-SysTick_Handler

.type leds_toggle, %function
leds_toggle:
  push {lr}
  bl read_row
  pop {lr}

  eor r0, r0, 0b00100
  push {lr}
  bl write_row_pins
  pop {lr}

  push {lr}
  bl read_column
  pop {lr}

  eor r0, r0, 0b00100
  push {lr}
  bl write_column_pins
  pop {lr}

  bx lr
.size leds_toggle, .-leds_toggle

.type start_SysTick, %function
@ Starts SysTick with interrupts enabled.
@ --parameters--
@ none
start_SysTick:
  push {lr}
  @ Enable systick
  ldr r0, =ADR_SYST_CSR
  mov r1, 0b111
  mov r2, 0
  mov r3, 3
  bl copy_bits
  pop {lr}
  bx lr
.size start_SysTick, .-start_SysTick

.type stop_SysTick, %function
@ Stops SysTick.
@ --parameters--
@ none
stop_SysTick:
  push {lr}
  @ Disable systick
  ldr r0, =ADR_SYST_CSR
  mov r1, 0b100
  mov r2, 0
  mov r3, 3
  bl copy_bits
  pop {lr}
  bx lr
.size stop_SysTick, .-stop_SysTick

.type set_SysTick, %function
@ Sets the reload value for SysTick.
@ --parameters--
@ r0: SysTick reload value
set_SysTick:
  ldr r1, =ADR_SYST_RVR
  str r0, [r1]
  bx lr
.size set_SysTick, .-set_SysTick

.type reset_SysTick, %function
@ Resets the current count value for SysTick to 0.
@ --parameters--
@ none
reset_SysTick:
  @ Reset systick (any writes to CVR cause it to go to 0)
  ldr r0, =ADR_SYST_CVR
  mov r1, 1
  str r1, [r0]
  bx lr
.size reset_SysTick, .-reset_SysTick