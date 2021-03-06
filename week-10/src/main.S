.syntax unified
.global main
.global GPIOTE_IRQHandler
.global SysTick_Handler
.global TIMER0_IRQHandler

@ SysTick vars
.set RVR_1MS,      64000
.set RVR_0_5MS,    32000
@ Timer vars
.set TIMER0_1MS,   1000
.set TIMER0_0_5MS, 500

.set MESSAGE_SIZE, 8


.type main, %function
main:
  @ GPIO 0: P0.02
  @ GPIO 1: P0.03
  @ GPIO 2: P0.04
  @ wire from 0 -> 2

  @@@@ Configure LEDS for some visual output
  bl init_leds

  @@@@ Configure interrupt priorities
  @ GPIO > Systick > Timer
  @@ GPIOTE to priority 0
  ldr r0, =ADR_NVIC
  ldr r1, =OFS_NVIC_IPR1
  add r0, r1
  mov r1, 0
  mov r2, 21
  mov r3, 3
  bl copy_bits

  @@ Systick to priority 1
  ldr r0, =ADR_SCB_SHPR3
  mov r1, 1
  mov r2, 29
  mov r3, 3
  bl copy_bits

  @ TIMER0 to priority 2
  ldr r0, =ADR_NVIC
  ldr r1, =OFS_NVIC_IPR2
  add r0, r1
  mov r1, 2
  mov r2, 5
  mov r3, 3
  bl copy_bits

  @@@@ Set GPIO Output Defaults
  @@ Set P0.02 to output mode
  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_DIR
  mov r2, 2
  bl set_bit
  @ Set P0.02 to default high
  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_OUT
  mov r2, 2
  bl set_bit

  @@@@ Set GPIO Input Defaults
  @ Enable GPIOTE Falling Edge Interrupt
  mov r0, 4 @ Pin 4
  mov r1, 0 @ Port 0
  mov r2, 2 @ HiToLo
  bl enable_GPIOTE

  @@@@ Init Timer0 (doesn't start it or set the count target)
  bl init_TIMER0

  @@@@ Set Systick Defaults
  @ Set reload value for 1ms interrupt
  ldr r0, =RVR_1MS
  bl set_SysTick
  @ Start SysTick interrupt
  bl start_SysTick

  mov r7, 0
  mov r8, 0
  mov r9, 0

loop:
  nop
  b loop
.size main, .-main


@ Sender interrupt
.type SysTick_Handler, %function
SysTick_Handler:
  push {lr}
  nop

  push {r2, r3}
  @ set the output state of Ring 0
  @ Read output state of RING 0
  @ pin = 2 and port = 0 (P0.02 = Ring 0)
  ldr r0, =packet_repeat
  ldr r1, [r0]
  ldr r2, [r0, 8]

  push {r0, lr}
  cmp r1, r2
  IT EQ
  bleq set_high
  pop {r0, lr}

  cmp r1, r2
  IT EQ
  ldreq r1, [r0, 4]
  str r1, [r0]

  mov r2, 4
  mul r2, r1, r2

  ldr r0, =SENDER_DATA
  ldr r1, [r0, r2]
  lsl r2, r1, 2

  @ to next packet
  ldr r0, =packet_repeat
  ldr r1, [r0]
  add r1, 1
  str r1, [r0]

  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_OUT
  str r2, [r0, r1]

  pop {r2, r3}
  pop {lr}

  bx lr
.size SysTick_Handler, .-SysTick_Handler

.type set_high, %function
set_high:
  push {r1-r2}
  mov r1, 1
  lsl r2, r1, 2
  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_OUT
  str r2, [r0, r1]
  pop {r1-r2}
  bx lr
.size set_high, .-set_high

@ This interrupt exists to wakeup the receiver, it can also be used to finalize the 
@ received message if you wish.
.type GPIOTE_IRQHandler, %function
GPIOTE_IRQHandler:
  push {lr}
  @ Write your wakeup etc. code here \/\/\/
  @ GPIOTE detects falling edge
  @ put variables in place for the receiver to successfully receive the message

  @ configure the TIMER0 interrupt period and enable it
  bl init_TIMER0
  ldr r0, =TIMER0_1MS
  bl set_TIMER0
  bl start_TIMER0

  @ disable the GPIOTE interrupt
  bl disable_GPIOTE

  @ clear its pending bit
  @ Clear GPIOTE event
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_EVENTS_IN0
  mov r2, 0
  bl clear_bit
  bl sync
  pop {lr}
  bx lr
.size GPIOTE_IRQHandler, .-GPIOTE_IRQHandler


.type TIMER0_IRQHandler, %function
TIMER0_IRQHandler:
  push {lr}
  @ Write your timer receive code here \/\/\/
  @ receive the current bit from Ring2 (P0.02)
TIMER0_lock:
  bl sync
  ldr r0, =packet_received
  ldr r1, [r0]
  ldr r0, =packet_repeat
  ldr r2, [r0]
  cmp r1, r2
  IT LT
  blt TIMER0_unlock
  b TIMER0_lock
TIMER0_unlock:
  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_IN
  ldr r2, [r0, r1]

  ldr r3, =0x40000
  cmp r2, r3
  IT EQ
  moveq r1, 0

  ldr r3, =0x40010
  cmp r2, r3
  IT EQ
  moveq r1, 1

  @ append the bit to the current message (in the correct location)
  ldr r0, =packet_received
  ldr r2, [r0]
  mov r3, 4
  mul r2, r2, r3
  ldr r0, =RECEIVER_DATA
  str r1, [r0, r2]
  
  ldr r0, =packet_received
  ldr r1, [r0]
  add r1, 1
  str r1, [r0]

  @ check if it has received a full message
  ldr r0, =packet_received
  ldr r1, [r0]
  ldr r2, [r0, 8]
  cmp r1, r2
  IT EQ
  beq is_full_message
  b receive_done

is_full_message:
  @ if it has received a full message it should:
  @ check the validity of the message
  @ turn off all LEDS and then turn the on the LED in the message
  push {lr}
  bl decode_message
  pop {lr}

  @ disable the TIMER0 interrupt
  bl stop_TIMER0

  @ clear the GPIOTE pending (we don’t want it interrupting immediately if one was left pending)
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_EVENTS_IN0
  mov r2, 0
  bl clear_bit
  bl sync

  @ enable the GPIOTE interrupt
  mov r0, 4 @ Pin 4
  mov r1, 0 @ Port 0
  mov r2, 2 @ HiToLo
  bl enable_GPIOTE
  
  ldr r0, =packet_received
  ldr r1, [r0, 4]
  str r1, [r0]

  @ clear the TIMER0 pending bit
  bl clear_TIMER0

  b receive_done

receive_done:
  @ Clear this event
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_EVENTS_COMPARE0
  mov r2, 0
  bl clear_bit
  bl sync
  pop {lr}
  bx lr
.size TIMER0_IRQHandler, .-TIMER0_IRQHandler


@@@@ Helper functions @@@@
.type enable_GPIOTE, %function
@ Enables the GPIOTE (config 0) interrupt and clears any pending bits for it
@ --parameters--
@ r0: pin
@ r1: port
@ r2: interrupt type (0: None, 1: LoToHi, 2: HiToLo, 3: Toggle)
enable_GPIOTE:
  push {lr}
  push {r0 - r2}
  @ Clear events incase they were pending
  @ Clear GPIOTE event
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_EVENTS_IN0
  mov r2, 0
  bl clear_bit
  @ Clear NVIC
  ldr r0, =ADR_NVIC
  ldr r1, =OFS_NVIC_ICPR0
  mov r2, 6
  bl set_bit
  bl sync
  @ Set pull down resistor
  ldr r0, =ADR_P0
  ldr r1, =OFS_GPIO_PIN_CONF4
  add r0, r1
  mov r1, 1
  mov r2, 2
  mov r3, 2
  bl copy_bits
  @ Enable the interrupt
  pop {r0 - r2}
  lsl r0, 8
  lsl r1, 13
  lsl r2, 16
  orr r2, r0
  orr r2, r1
  orr r2, 1 @ Enable
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_CONFIG0
  str r2, [r0, r1]
  @ Enable GPIOTE Interrupt
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_INTENSET
  mov r2, 0b1
  str r2, [r0, r1]
  @ Enable GPIOTE (interrupt #6 = NVIC_GPIOTE_ID) in NVIC_ISER0
  @ NVIC_ISER0: B3.4.4 in ARMv7-M Reference Manual
  ldr r0, =ADR_NVIC
  ldr r1, =OFS_NVIC_ISER0
  mov r2, 6
  bl set_bit
  pop {lr}
  bx lr
.size enable_GPIOTE, .-enable_GPIOTE


.type disable_GPIOTE, %function
@ Disables the GPIOTE interrupt.
@ --parameters--
@ none
disable_GPIOTE:
  @ Disable this interrupt
  ldr r0, =ADR_GPIOTE
  ldr r1, =OFS_GPIOTE_INTENCLR
  mov r2, 0b1
  str r2, [r0, r1] @ write to disable
  bx lr
.size disable_GPIOTE, .-disable_GPIOTE


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


.type start_TIMER0, %function
@ Starts the timer.
@ --parameters--
@ none
start_TIMER0:
  @ Start TIMER0
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_TASKS_START
  mov r2, 1
  str r2, [r0, r1]
  bx lr
.size start_TIMER0, .-start_TIMER0


.type stop_TIMER0, %function
@ Stops the timer.
@ --parameters--
@ none
stop_TIMER0:
  @ Stop TIMER0
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_TASKS_STOP
  mov r2, 1
  str r2, [r0, r1]
  bx lr
.size stop_TIMER0, .-stop_TIMER0


.type set_TIMER0, %function
@ Sets the new compare value for TIMER0.
@ Requires TIMER0 to be stopped.
@ --parameters--
@ r0: time in microseconds for interrupt rate
set_TIMER0:
  push {r0}
  @ Set prescaler to 4 to get a 1 microsecond interrupt granularity
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_PRESCALER
  mov r2, 4
  str r2, [r0, r1]

  @ Set Compare value
  pop {r0}
  mov r2, r0
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_CC0
  str r2, [r0, r1]
  bx lr
.size set_TIMER0, .-set_TIMER0


.type clear_TIMER0, %function
@ Clears the current count value of the timer.
@ --parameters--
@ none
clear_TIMER0:
  @ Clear the internal timer count register
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_TASKS_CLEAR
  mov r2, 1
  str r2, [r0, r1]
  bx lr
.size clear_TIMER0, .-clear_TIMER0


.type init_TIMER0, %function
@ Inits the timer.
@ --parameters--
@ none
init_TIMER0:
@@@@ Set Timer Defaults
  @ Timers operate slightly differently to SysTick:
  @ - SysTick counts down from a reload value to 0
  @ - Timers count up from 0 and can have multiple trigger points
  @ - Timers do not necessarily reset when they hit trigger points, this is something that can be configured
  @ - To read ther current value of a timer we need to trigger a "value capture" event
  @ - SysTick counts at a rate of 64MHz when attached to the CPU clock
  @ - Timers count at a rate of 16MHz by default, and have further configuration with a prescaler (explained below)
  @ TIMERX counts at a rate of 16MHz (1/4 of the cpu speed, so it counts by 1 every 4 cpu clock cycles)
  @ TIMERX also has a prescaler which changes the *actual* count rate (how much it will count up in 1 second) by the formula:
  @ fTIMER = 16 MHz / (2^PRESCALER)
  @ A nice default for the PRESCALER is 4, this gives us a 1000000Hz count rate, or simply each counter increment = 1 microsecond
  push {lr}
  @@ Set to timer mode
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_MODE
  mov r2, 0
  str r2, [r0, r1]

  @ Set TIMER count value to 32bit mode
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_BITMODE
  mov r2, 3
  str r2, [r0, r1]

  @ Set prescaler to 4 to get a 1 microsecond interrupt granularity
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_PRESCALER
  mov r2, 4
  str r2, [r0, r1]

  @ Clear the internal timer count register
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_TASKS_CLEAR
  mov r2, 1
  str r2, [r0, r1]

  @ Set compare event0 to trigger a clear of the timer value 
  @ (this basically means when the timer counts up to the value in CC0 it resets the count to 0 automatically)
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_SHORTS
  mov r2, 0
  bl set_bit

  @ Enable Interrupt on timer compare(0)
  ldr r0, =ADR_TIMER0
  ldr r1, =OFS_TIMER_ITENSET
  mov r2, (0b1 << 16)
  str r2, [r0, r1]

  @ Enable TIMER0 Interrupt (interrupt #8 = TIMER0_ID) in NVIC_ISER0
  @ NVIC_ISER0: B3.4.4 in ARMv7-M Reference Manual
  ldr r0, =ADR_NVIC
  ldr r1, =OFS_NVIC_ISER0
  mov r2, 8
  bl set_bit
  pop {lr}
  bx lr
.size init_TIMER0, .-init_TIMER0


.type sync, %function
@ Sometimes we just wanna wait a bit to make sure memory triggered operations 
@ run to completion before we continue.
sync:
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  nop
  bx lr
.size sync, .-sync

.type decode_message, %function
@ check the validity of the message
@ turn off all LEDS and then turn the on the LED in the message
@ --parameters--
@ none
decode_message:
  ldr r0, =RECEIVER_DATA
  @ check start, stop bit
  ldr r1, [r0]
  ldr r2, [r0, 36]
  cmp r1, r2
  IT EQ
  beq decode_message_equal
  b decode_message_reset
decode_message_equal:
  cmp r1, 0
  IT EQ
  beq decode_message_valid
  b decode_message_reset
decode_message_valid:
  push {lr}
  bl led_off
  pop {lr}

  mov r0, 5
  push {lr}
  bl get_message_index
  pop {lr}
  mov r1, r0

  mov r0, 1
  push {lr}
  bl get_message_index
  pop {lr}

  push {lr}
  bl led_on
  pop {lr}

  b decode_message_end

decode_message_reset:
  push {lr}
  bl message_reset
  pop {lr}

decode_message_end:
  bx lr
.size decode_message, .-decode_message

.type get_message_index, %function
@ r0 : start index
get_message_index:
  mov r6, r0
  push {r1-r4}
  mov r1, 4
  mov r2, 0
  add r1, r0
  add r2, r0
  ldr r0, =RECEIVER_DATA
  mov r4, 4
  mov r5, r2
get_message_index_loop:
  cmp r1, r2
  IT EQ
  beq get_message_index_end
  mul r3, r2, r4
  ldr r3, [r0, r3]
  add r2, 1
  cmp r3, 1
  IT EQ
  moveq r5, r2
  b get_message_index_loop
get_message_index_end:

  pop {r1-r4}
  sub r0, r5, r6
  bx lr
.size get_message_index, .-get_message_index

.type message_reset, %function
message_reset:
  push {r0-r5}
  ldr r0, =RECEIVER_DATA
  mov r1, 10
  mov r2, 0
  mov r3, 0
  mov r4, 4
message_reset_loop:
  cmp r2, r1
  IT EQ
  beq message_reset_end
  mul r5, r2, r4
  str r3, [r0, r5]
  add r2, 1
  b message_reset_loop
message_reset_end:
  pop {r0-r5}
  bx lr
.size message_reset, .-message_reset

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

.data
packet_repeat:
.word 0, 0, 10

.data
packet_received:
.word 0, 0, 10

.data
@ Add your state for sender and receiver here
SENDER_DATA:
  .word 0, 0, 0, 0, 1, 0, 0, 0, 0, 0

RECEIVER_DATA:
  .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0