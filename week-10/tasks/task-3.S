.syntax unified
.global main

.type main, %function
main:

  @ 0: init leds
  push {lr} 
  bl init_leds
  pop {lr}

  @ setup RING 0, 2
  push {lr} 
  bl setupRING
  pop {lr}

  @ setup SysTick
  push {lr} 
  bl setupSYSTICK
  pop {lr}

  b loop
.size main, .-main

loop:

  b loop

.global GPIOTE_IRQHandler
.type GPIOTE_IRQHandler, %function
GPIOTE_IRQHandler:
  push {lr}

  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_IN
  ldr r2, [r0, r1]

  ldr r3, =0x40010
  cmp r2, r3
  IT EQ
  bleq led_center_on

  ldr r3, =0x40000
  cmp r2, r3
  IT EQ
  bleq led_center_off

  @ clear NVIC pending interrupt
  @ NVIC_ICPR0: B3.4.7 in ARMv7-M Reference Manual
  ldr r0, =NVIC_ICPR0
  ldr r1, =(1 << 6) @ set the 6th bit since NVIC_GPIOTE_ID = 6
  str r1, [r0]

  @ @ 3: disable GPIOTE (interrupt #6 = NVIC_GPIOTE_ID) in NVIC_ICER0
  @ @ NVIC_ICER0: B3.4.5 in ARMv7-M Reference Manual
  @ ldr r0, =NVIC_ICER0
  @ ldr r1, =(1 << 6) @ set the 6th bit since NVIC_GPIOTE_ID = 6
  @ str r1, [r0]

  nop
  pop {lr}
  bx lr
.size GPIOTE_IRQHandler, .-GPIOTE_IRQHandler

.global SysTick_Handler
.type SysTick_Handler, %function
@ Interrupts and toggle led
@ --parameters--
@ none
@ --return--
@ none
SysTick_Handler:
  nop
  push {lr}
  ldr r0, =systic_repeat
  ldr r1, [r0]
  ldr r2, [r0, 8]
  cmp r1, r2
  IT LT
  bllt SysTick_Handler_pass
SysTick_Handler_do:

  push {r2, r3}
  @ set the output state of Ring 0
  @ Read output state of RING 0
  @ pin = 2 and port = 0 (P0.02 = Ring 0)
  ldr r0, =packet_repeat
  ldr r1, [r0]
  ldr r2, [r0, 8]
  cmp r1, r2
  IT EQ
  ldreq r1, [r0, 4]
  str r1, [r0]

  mov r2, 4
  mul r2, r1, r2

  ldr r0, =p2300_1w_packet
  ldr r1, [r0, r2]
  lsl r2, r1, 2

  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_OUT
  str r2, [r0, r1]

  pop {r2, r3}

  @ to next packet
  ldr r0, =packet_repeat
  ldr r1, [r0]
  add r1, 1
  str r1, [r0]

  @ reset systic repeat to 0
  ldr r0, =systic_repeat
  ldr r2, [r0, 4]
  str r2, [r0]

  b SysTick_Handler_end
SysTick_Handler_pass:
  add r1, r1, 1
  ldr r0, =systic_repeat
  str r1, [r0]
  b SysTick_Handler_end
SysTick_Handler_end:
  pop {lr}
  bx lr
.size SysTick_Handler, .-SysTick_Handler

.type led_center_on, %function
led_center_on:
  push {r0, r1, lr}
  mov r0, 2
  mov r1, 2
  bl led_on
  pop {r0, r1, lr}
  bx lr
.size led_center_on, .-led_center_on

.type led_center_off, %function
led_center_off:
  push {r0, r1, lr}
  mov r0, 2
  mov r1, 2
  bl led_off
  pop {r0, r1, lr}
  bx lr
.size led_center_off, .-led_center_off

.type led_on, %function
@ --parameters--
@ r0: row index (0-4 with 0 being the top row)
@ r1: column index (0-4 with 0 being the left most column)
@ --return--
@ none
led_on:
  push {r2}
  ldr r2, =0b1
  lsl r0, r2, r0
  push {r1, lr}
  bl write_row_pins
  pop {r1, lr}

  ldr r2, =0b1
  lsl r1, r2, r1
  ldr r0, =0b11111
  eor r0, r0, r1
  push {lr}
  bl write_column_pins
  pop {lr}

  pop {r2}

  bx lr
.size led_on, .-led_on

.type led_off, %function
@ Interrupts and toggle led
@ --parameters--
@ none
@ --return--
@ none
led_off:
  push {r2}
  ldr r0, =0b00000
  push {lr}
  bl write_row_pins
  pop {lr}

  ldr r0, =0b11111
  push {lr}
  bl write_column_pins
  pop {lr}
  pop {r2}

  bx lr
.size led_off, .-led_off

.type setupRING, %function
setupRING:
  @ Configure RING 0 : setting RING0 as output 
  @ pin = 2 and port = 0 (P0.02 = Ring 0)
  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_DIR
  ldr r2, [r0, r1]
  ldr r3, =(1 << 2)
  orr r2, r2, r3
  str r2, [r0, r1]

  @ 1: Configure GPIOTE_CONFIG[2]
  @ Need to setup: mode, pin, port, polarity in the configuration register for GPIOTE[2]
  @ Section 6.9.4.8 in nRF52833 reference manual
  @ mode = 1 (event), pin = 4 and port = 0 (P0.04 = Ring 2), polarity = 1 (LoToHi)
  ldr r0, =GPIOTE_CONFIG2
  ldr r1, =(1 | 4 << 8 | 0 << 13 | 1 << 16)
  str r1, [r0]

  @ 2: Enable Interrupt for GPIOTE[2] (id = 6)
  @ S6.9.4.6 in nRF52833 reference manual
  ldr r0, =GPIOTE_INTENSET
  ldr r1, =(1 << 2)
  str r1, [r0]

  @ 3: enable GPIOTE (interrupt #6 = NVIC_GPIOTE_ID) in NVIC_ISER0
  @ NVIC_ISER0: B3.4.4 in ARMv7-M Reference Manual
  ldr r0, =NVIC_ISER0
  ldr r1, =(1 << 6) @ set the 6th bit since NVIC_GPIOTE_ID = 6
  str r1, [r0]

  bx lr
.size setupRING, .-setupRING

.type setupSYSTICK, %function
setupSYSTICK:
  @ set SYST_CSR_ENABLE - bit 0
  @ set SYST_CSR_TICKINT - bit 1
  @ set SYST_CSR_CLKSOURCE - bit 2 (default)
  ldr r0, =SYST_CSR
  ldr r1, =(1 << 0 | 1 << 1)
  str r1, [r0]

  @ SysTick to interrupt at a constant rate
  @ count down from ONE_MILLISECONDS (64K cycles) repeating 0 times
  ldr r0, =SYST_RVR
  ldr r1, =ONE_MILLISECOND
  str r1, [r0]

  @ @ set priority of SYSTICK
  @ @ SHPR3: B3.2.12 in ARMv7-M Reference Manual
  @ ldr r0, =SHPR3
  @ ldr r1, =(1 << 30) @ set the 29-31th bit priority 2 (lower priority)
  @ str r1, [r0]

  bx lr
.size setupSYSTICK, .-setupSYSTICK

.data
systic_repeat:
.word 0, 0, 0

.data
packet_repeat:
.word 0, 0, 10

.data
p2300_1w_packet:
.word 0, 0, 1, 0, 0, 0, 0, 0, 1, 0

.data
.set ONE_MILLISECOND, 0xFA00 @ 64K cycles
.set TEN_MILLISECOND, 0x9C400 @ 0.64M cycles
.set FIFTY_MILLISECOND, 0xF42400 @ 3.2M cycles

@ SysTick register
.set SYST_CSR, 0xE000E010
.set SYST_RVR, 0xE000E014
.set SYST_CVR, 0xE000E018
.set SYST_CALIB, 0xE000E01C
.set SHPR3, 0xE000ED20

@ GPIOTE register
.set GPIOTE_EVENTS_IN0, 0x40006100
.set GPIOTE_EVENTS_IN1, 0x40006104
.set GPIOTE_EVENTS_IN2, 0x40006108
.set GPIOTE_TASKS_OUT0, 0x40006000
.set GPIOTE_TASKS_SET0, 0x40006030
.set GPIOTE_TASKS_CLR0, 0x40006060
.set GPIOTE_INTENSET, 0x40006304
.set GPIOTE_INTENCLR, 0x40006308
.set GPIOTE_CONFIG0, 0x40006510
.set GPIOTE_CONFIG1, 0x40006514
.set GPIOTE_CONFIG2, 0x40006518

@ NVIC Constants
.set NVIC_ISER0, 0xE000E100
.set NVIC_ICER0, 0xE000E180
.set NVIC_ICPR0, 0xE000E280
.set NVIC_IPR1, 0xE000E404