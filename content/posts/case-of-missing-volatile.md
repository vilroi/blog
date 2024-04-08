---
title: "Case of the Forgotten \'volatile\' Qualifier"
date: 2024-04-07T11:38:59-07:00
draft: true
---
## Background
I had gotten back into tinkering with embedded stuff recently, and was writing some test code to get a better understanding of how timers work.

Specifically, I had written something like the following to be run on the [EK-TM4C123GXL Evaluation Board](https://www.ti.com/tool/EK-TM4C123GXL):

```c
int main(void) {
    init();

    init_timer();

    while (1) {
        if (SYSTICK_STCTRL_R & SYSTICK_COUNT_FLAG) 
            toggle_led();
    }
}
```
where
```c
#define SYSTICK_COUNT_FLAG      0x10000
#define SYSTICK_STCTRL_R        DEFINE_SYSTICK_REGISTER(0x10)

```
and
```c
#define SYSTICK_BASE_R                      (0xe000e000)
#define DEFINE_SYSTICK_REGISTER(offset)     *((uint32_t *) (SYSTICK_BASE_R + offset))
```

which basically becomes the following after going through the pre-processor:
```c
int main(void) {
    init();

    init_timer();

    while (1) {
        if (*((uint32_t *) ((0xe000e000) + 0x10)) & 0x10000)
            toggle_led();
    }
}
```


While most of the code has been left out for the sake of brevity, elsewhere in the code the systick timer is configured and enabled. 

Every five seconds the bit 16 of the STCTRL register (address 0x000e010) is set by the timer, and an on-board LED is toggled when this is detected.

The following is an excerpt from the [data sheet](https://www.ti.com/lit/ds/spms376e/spms376e.pdf?ts=1712554526265&ref_url=https%253A%252F%252Fwww.ti.com%252Ftool%252FEK-TM4C123GXL):

![](/static/systick_register.png)

## The Strange Infinite Loop
I built the code and loaded it onto the board, but the LED doesn't blink at all.

Okay, cool. What did I mess up? 

Perhaps I'm checking the wrong bit? 

Maybe I configured the timer incorrectly, or maybe it's not enabled at all.

After checking my code and stepping through it with ```gdb```, however, I noticed that it was stuck in an infinite loop at a single address.

I tried disassembling the code, and saw the following:
```console
(remote) gef➤  x/5i $pc
=> 0x2e0 <main+20>:     b.n     0x2e0 <main+20>     <-- infinite loop, stuck at address 0x2e0
   0x2e2 <main+22>:     bl      0x288 <toggle_led>
   0x2e6 <main+26>:     b.n     0x2da <main+14>
   0x2e8 <NmiSR>:       b.n     0x2e8 <NmiSR>
   0x2ea <FaultISR>:    b.n     0x2ea <FaultISR>
```

???

I then disassembled the whole `main()` function:
```console
(remote) gef➤  disassemble main
Dump of assembler code for function main:
   0x000002cc <+0>:     push    {r3, lr}
   0x000002ce <+2>:     bl      0x298 <init>
   0x000002d2 <+6>:     bl      0x26c <init_timer>
   0x000002d6 <+10>:    mov.w   r1, #3758153728 @ 0xe000e000
   0x000002da <+14>:    ldr     r3, [r1, #16]
   0x000002dc <+16>:    lsls    r3, r3, #15
   0x000002de <+18>:    bmi.n   0x2e2 <main+22>
=> 0x000002e0 <+20>:    b.n     0x2e0 <main+20>     <-- infinite loop
   0x000002e2 <+22>:    bl      0x288 <toggle_led>
   0x000002e6 <+26>:    b.n     0x2da <main+14>
```
?????

How did that happen?

After bashing my head on the wall for a good hour or so, I tried looking through the libraries provied by TI.

Eventually, I came accross the following:
```c
 #define HWREG(x)                                                              \
          (*((volatile uint32_t *)(x)))
```

This is the macro used by the library to do memory-mapped IO.

I had defined something similar, except without the ```volatile``` qualifier.

Could this be it?

I added the `volatile` qualifier and rebuilt the code:

```c
#define DEFINE_SYSTICK_REGISTER(offset)     *((volatile uint32_t *) (SYSTICK_BASE_R + offset))
```

```console
$ arm-none-eabi-objdump -D bin/test.axf
000002cc <main>:
 2cc:   b508            push    {r3, lr}
 2ce:   f7ff ffe3       bl      298 <init>
 2d2:   f7ff ffcb       bl      26c <init_timer>
 2d6:   f04f 21e0       mov.w   r1, #3758153728 @ 0xe000e000
 2da:   690b            ldr     r3, [r1, #16]
 2dc:   03db            lsls    r3, r3, #15
 2de:   d5fc            bpl.n   2da <main+0xe>
 2e0:   f7ff ffd2       bl      288 <toggle_led>
 2e4:   e7f9            b.n     2da <main+0xe>
.....
```

...and sure enough the LED started to blink.

## What is "volatile" Anyways?
According to [Chapter 5 of Embedded Systems -- Shape the World](https://users.ece.utexas.edu/~valvano/Volume1/IntroToEmbSys/Ch2_SoftwareDesign.html):
> The volatile qualifier modifies a variable disabling compiler optimization, forcing the compiler to fetch a new value each time. We will use volatile when defining I/O ports because the value of ports can change outside of software action. We will also use volatile when sharing a global variable between the main program and an interrupt service routine.

If we go back to the code (**no** `volatile`):
```c
while (1) {
    if (*((uint32_t *) ((0xe000e000) + 0x10)) & 0x10000)
        toggle_led();
}
```
...as far as the compiler is concerned, the contents of the address is only read, and never modified within the loop.

It is oblivious to the fact that the value at the address can (and will) be modified by some outside factor; in this case, the hardware peripheral.

```console
   0x000002cc <+0>:     push    {r3, lr}
   0x000002ce <+2>:     bl      0x298 <init>
   0x000002d2 <+6>:     bl      0x26c <init_timer>
   0x000002d6 <+10>:    mov.w   r1, #3758153728 @ 0xe000e000
   0x000002da <+14>:    ldr     r3, [r1, #16]
   0x000002dc <+16>:    lsls    r3, r3, #15
   0x000002de <+18>:    bmi.n   0x2e2 <main+22>
=> 0x000002e0 <+20>:    b.n     0x2e0 <main+20>     <-- infinite loop
   0x000002e2 <+22>:    bl      0x288 <toggle_led>
   0x000002e6 <+26>:    b.n     0x2da <main+14>
```

If in the inital check the flag is not set, the code locks itself into an infinite loop at `0x000002e0`, preventing it from taking the path of `0x000002e2`, which toggles the LED and loops back to `0x000002da`.

From the compiler's point of view, there is no point in re-checking the bit, as it is never modified.

I have tried modifying the code in the following way, and tried disassembling it again.
```c
while (1) {
    if (SYSTICK_STCTRL_R & SYSTICK_COUNT_FLAG) 
        toggle_led();
    SYSTICK_STCTRL_R ^= 0x4;
}
```

The results are as follows:
```console
 2cc:   b508            push    {r3, lr}
 2ce:   f7ff ffe3       bl      298 <init>
 2d2:   f7ff ffcb       bl      26c <init_timer>
 2d6:   f04f 21e0       mov.w   r1, #3758153728 @ 0xe000e000
 2da:   690b            ldr     r3, [r1, #16]
 2dc:   03db            lsls    r3, r3, #15
 2de:   d501            bpl.n   2e4 <main+0x18>
 2e0:   f7ff ffd2       bl      288 <toggle_led>
 2e4:   690b            ldr     r3, [r1, #16]
 2e6:   f083 0304       eor.w   r3, r3, #4
 2ea:   610b            str     r3, [r1, #16]
 2ec:   e7f5            b.n     2da <main+0xe>
```
While this modification is utterley pointless, it did get rid of the infinite loop.

I do wonder what would happen if the bit was set before the first check, however.

I assume it will just loop until the bit is unset again, and then go into the infinite loop once the bit is unset (which is kind of weird in my opinion).

## Closing Remarks
What makes this experience somewhat absurd is that I had actually read about the necessity of `volatile` when accessing memory-mapped peripherals in the past.

However I had glossed over the details of why it was necessary, and had kind of forgotten about it.

Although this resulted in a fun tangent of researching and learning some ARM-related stuff --as well as a blog post : ) -- I probably should have paid more attention to it.

## Additional Resources
[Embedded Systems -- Shape The World Chapter 5](https://users.ece.utexas.edu/~valvano/Volume1/E-Book/C5_IntroductionToC.htm)

[GNU Manual: volatile Variables and Fields](https://www.gnu.org/software/c-intro-and-ref/manual/html_node/volatile.html)

[Explaining the C Keyword Volatile](https://embedded.fm/blog/2017/2/23/explaining-the-c-keyword-volatile)
