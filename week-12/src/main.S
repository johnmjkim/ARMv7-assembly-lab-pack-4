.syntax unified
.global main

.type main, %function
main:
  nop
  push {lr}
  bl init_leds
  pop {lr}

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