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

  @@@@ Set Systick Defaults
  @ Set reload value for 1ms interrupt
  ldr r0, =RVR_1MS
  bl set_SysTick
  @ Start SysTick interrupt
  bl start_SysTick

  b ledblink
.size main, .-main

ledblink:
  push {lr}
  bl leds_toggle
  pop {lr}

  ldr r0, =0x30D400
  push {lr}
  bl delay
  pop {lr}

  b ledblink

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