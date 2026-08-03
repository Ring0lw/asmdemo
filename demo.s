.set MAXW,        256
.set MAXH,        160
.set MAXROWS,     80
.set FBSZ,        MAXW*MAXH*4
.set ZBSZ,        MAXW*MAXH*2
.set OUTSZ,       1<<21
.set NU,          32
.set NV,          16
.set NVERT,       NU*NV
.set NTRI,        NU*NV*2
.set NSTAR,       800
.set TEXW,        128
.set SYS_exit,    1
.set SYS_write,   4
.set SYS_sigaction, 46
.set SYS_ioctl,   54
.set SYS_select,  93
.set SYS_gettimeofday, 116
.set TIOCGWINSZ,  0x40087468
.set T_STARS,     0
.set T_TORUS,     10000
.set T_TUNNEL,    24000
.set T_ROTO,      34000
.set T_BALLS,     44000
.set T_END,       57000
.set FADEMS,      700
.set AREA_MIN,    192

.macro LEA r, s
    adrp    \r, \s@PAGE
    add     \r, \r, \s@PAGEOFF
.endm

.macro IMM32 r, v
    movz    \r, #((\v) & 0xffff)
    movk    \r, #(((\v) >> 16) & 0xffff), lsl #16
.endm

.text

.globl _main
.p2align 2
_main:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    mov     w19, w0
    mov     x20, x1

    bl      _parse_args
    bl      _term_size
    bl      _build_dec3
    bl      _build_sin
    bl      _build_pal
    bl      _build_mesh
    bl      _build_stars
    bl      _build_tunnel
    bl      _build_tex

    LEA     x0, _shotms
    ldr     w0, [x0]
    tbnz    w0, #31, Lchkbench
    bl      _render_frame
    bl      _write_bmp
    mov     x0, #0
    mov     x16, #SYS_exit
    svc     #0x80

Lchkbench:
    LEA     x0, _benchn
    ldr     w0, [x0]
    cbz     w0, Lrun
    bl      _bench
    mov     x0, #0
    mov     x16, #SYS_exit
    svc     #0x80
Lrun:
    bl      _install_sigs
    bl      _prev_reset
    bl      _term_enter
    bl      _now_ms
    LEA     x1, _t0
    str     x0, [x1]

Lframe:
    bl      _now_ms
    mov     x21, x0
    LEA     x1, _t0
    ldr     x1, [x1]
    sub     x0, x0, x1
    mov     w1, #T_END
    udiv    w2, w0, w1
    msub    w0, w2, w1, w0
    bl      _render_frame
    bl      _encode
    bl      _flush
    LEA     x1, _fpsacc
    ldr     w2, [x1]
    add     w2, w2, #1
    str     w2, [x1]
    LEA     x1, _fpst0
    ldr     x3, [x1]
    sub     x4, x21, x3
    mov     x5, #500
    cmp     x4, x5
    b.lo    1f
    mov     w5, #1000
    mul     w5, w2, w5
    udiv    w5, w5, w4
    LEA     x6, _fpsval
    str     w5, [x6]
    str     x21, [x1]
    LEA     x1, _fpsacc
    str     wzr, [x1]
1:  bl      _now_ms
    sub     x0, x0, x21
    mov     w1, #16
    subs    w1, w1, w0
    b.le    Lframe
    mov     w0, w1
    bl      _sleep_ms
    b       Lframe

.p2align 2
_parse_args:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x23, x24, [sp, #16]
    stp     x25, x26, [sp, #32]
    mov     w23, #1
Lpa:
    cmp     w23, w19
    b.ge    Lpadone
    ldr     x24, [x20, x23, lsl #3]
    mov     x0, x24
    LEA     x1, _sw256
    bl      _streq
    cbz     w0, 1f
    LEA     x0, _col256
    mov     w1, #1
    str     w1, [x0]
    b       Lpanext
1:  mov     x0, x24
    LEA     x1, _swshot
    bl      _streq
    cbz     w0, 2f
    add     w23, w23, #1
    cmp     w23, w19
    b.ge    Lpadone
    ldr     x0, [x20, x23, lsl #3]
    bl      _atoi
    LEA     x1, _shotms
    str     w0, [x1]
    b       Lpanext
2:  mov     x0, x24
    LEA     x1, _swtime
    bl      _streq
    cbz     w0, 3f
    add     w23, w23, #1
    cmp     w23, w19
    b.ge    Lpadone
    ldr     x0, [x20, x23, lsl #3]
    bl      _atoi
    LEA     x1, _tskew
    str     w0, [x1]
    b       Lpanext
3:  mov     x0, x24
    LEA     x1, _swbench
    bl      _streq
    cbz     w0, 6f
    add     w23, w23, #1
    cmp     w23, w19
    b.ge    Lpadone
    ldr     x0, [x20, x23, lsl #3]
    bl      _atoi
    LEA     x1, _benchn
    str     w0, [x1]
    b       Lpanext
6:  mov     x0, x24
    LEA     x1, _swsize
    bl      _streq
    cbz     w0, 7f
    add     w23, w23, #2
    cmp     w23, w19
    b.ge    Lpadone
    ldr     x0, [x20, x23, lsl #3]
    sub     x0, x0, #0
    ldr     x0, [x20, x23, lsl #3]
    bl      _atoi
    LEA     x1, _forceh
    str     w0, [x1]
    sub     w23, w23, #1
    ldr     x0, [x20, x23, lsl #3]
    bl      _atoi
    LEA     x1, _forcew
    str     w0, [x1]
    add     w23, w23, #1
    b       Lpanext
7:  mov     x0, x24
    LEA     x1, _swfps
    bl      _streq
    cbz     w0, 10f
    LEA     x0, _showfps
    mov     w1, #1
    str     w1, [x0]
    b       Lpanext
10: mov     x0, x24
    LEA     x1, _swhelp
    bl      _streq
    cbz     w0, Lpanext
    LEA     x0, _usage
    mov     w1, #_usage_len
    bl      _write1
    mov     x0, #0
    mov     x16, #SYS_exit
    svc     #0x80
Lpanext:
    add     w23, w23, #1
    b       Lpa
Lpadone:
    ldp     x23, x24, [sp, #16]
    ldp     x25, x26, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret

.p2align 2
_streq:
1:  ldrb    w2, [x0], #1
    ldrb    w3, [x1], #1
    cmp     w2, w3
    b.ne    2f
    cbnz    w2, 1b
    mov     w0, #1
    ret
2:  mov     w0, #0
    ret

.p2align 2
_atoi:
    mov     w1, #0
1:  ldrb    w2, [x0], #1
    sub     w3, w2, #48
    cmp     w3, #9
    b.hi    2f
    mov     w4, #10
    madd    w1, w1, w4, w3
    b       1b
2:  mov     w0, w1
    ret

.p2align 2
_term_size:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    LEA     x0, _forcew
    ldr     w0, [x0]
    cbz     w0, 8f
    LEA     x2, _wsz
    LEA     x1, _forceh
    ldr     w1, [x1]
    strh    w1, [x2]
    LEA     x1, _forcew
    ldr     w1, [x1]
    strh    w1, [x2, #2]
    b       9f
8:  mov     x0, #1
    IMM32   w1, TIOCGWINSZ
    LEA     x2, _wsz
    mov     x16, #SYS_ioctl
    svc     #0x80
9:  LEA     x2, _wsz
    ldrh    w3, [x2]
    ldrh    w4, [x2, #2]
    cmp     w3, #4
    b.hs    1f
    mov     w3, #30
    mov     w4, #100
    LEA     x0, _istty
    str     wzr, [x0]
1:  cmp     w4, #MAXW
    csel    w4, w4, wzr, lo
    b.lo    2f
    mov     w4, #MAXW
2:  cmp     w3, #MAXROWS
    b.lo    3f
    mov     w3, #MAXROWS
3:  cmp     w4, #24
    b.hs    4f
    mov     w4, #24
4:  cmp     w3, #8
    b.hs    5f
    mov     w3, #8
5:  lsl     w5, w3, #1
    LEA     x0, _fbw
    str     w4, [x0]
    LEA     x0, _fbh
    str     w5, [x0]
    LEA     x0, _rows
    str     w3, [x0]
    lsl     w6, w4, #15
    LEA     x0, _cx
    str     w6, [x0]
    lsl     w6, w5, #15
    LEA     x0, _cy
    str     w6, [x0]
    mov     w6, #5
    mul     w6, w5, w6
    lsr     w6, w6, #2
    LEA     x0, _focal
    str     w6, [x0]
    ldp     x29, x30, [sp], #32
    ret

.p2align 2
_now_ms:
    mrs     x0, cntvct_el0
    mrs     x1, cntfrq_el0
    mov     x2, #1000
    udiv    x1, x1, x2
    cbz     x1, 1f
    udiv    x0, x0, x1
    ret
1:  mov     x0, #0
    ret

.p2align 2
_sleep_ms:
    mov     w2, #1000
    mul     w2, w0, w2
    LEA     x0, _tvsleep
    mov     x1, #0
    str     x1, [x0]
    str     w2, [x0, #8]
    mov     x0, #0
    mov     x1, #0
    mov     x2, #0
    mov     x3, #0
    LEA     x4, _tvsleep
    mov     x16, #SYS_select
    svc     #0x80
    ret

.p2align 2
_install_sigs:
    LEA     x0, _sigact
    LEA     x1, _sighandler
    str     x1, [x0]
    str     x1, [x0, #8]
    str     wzr, [x0, #16]
    str     wzr, [x0, #20]
    mov     w19, #1
1:  mov     w0, w19
    LEA     x1, _sigact
    mov     x2, #0
    mov     x16, #SYS_sigaction
    svc     #0x80
    add     w19, w19, #1
    cmp     w19, #4
    b.le    1b
    mov     w0, #15
    LEA     x1, _sigact
    mov     x2, #0
    mov     x16, #SYS_sigaction
    svc     #0x80
    ret

.p2align 2
_sighandler:
    bl      _term_leave
    mov     x0, #0
    mov     x16, #SYS_exit
    svc     #0x80

.p2align 2
_term_enter:
    stp     x29, x30, [sp, #-16]!
    LEA     x0, _s_enter
    mov     w1, #_s_enter_len
    bl      _write1
    ldp     x29, x30, [sp], #16
    ret

.p2align 2
_term_leave:
    stp     x29, x30, [sp, #-16]!
    LEA     x0, _s_leave
    mov     w1, #_s_leave_len
    bl      _write1
    ldp     x29, x30, [sp], #16
    ret

.p2align 2
_write1:
    mov     x2, x1
    mov     x1, x0
    mov     x0, #1
    mov     x16, #SYS_write
    svc     #0x80
    ret

.p2align 2
_flush:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    LEA     x0, _outp
    ldr     x2, [x0]
    LEA     x1, _outbuf
    sub     x2, x2, x1
    mov     x0, #1
    mov     x16, #SYS_write
    svc     #0x80
    ldp     x29, x30, [sp], #32
    ret

.p2align 2
_rand:
    LEA     x1, _rng
    ldr     w0, [x1]
    eor     w0, w0, w0, lsl #13
    eor     w0, w0, w0, lsr #17
    eor     w0, w0, w0, lsl #5
    str     w0, [x1]
    ret

.p2align 2
_isqrt:
    mov     w1, #0
    mov     w2, #1
    lsl     w2, w2, #30
1:  cmp     w2, w0
    b.ls    2f
    lsr     w2, w2, #2
    cbnz    w2, 1b
    mov     w0, #0
    ret
2:  cbz     w2, 4f
    add     w3, w1, w2
    cmp     w0, w3
    b.lo    3f
    sub     w0, w0, w3
    lsr     w1, w1, #1
    add     w1, w1, w2
    b       5f
3:  lsr     w1, w1, #1
5:  lsr     w2, w2, #2
    b       2b
4:  mov     w0, w1
    ret

.p2align 2
_build_dec3:
    LEA     x1, _dec3
    mov     w0, #0
1:  mov     w2, #10
    udiv    w3, w0, w2
    msub    w4, w3, w2, w0
    udiv    w5, w3, w2
    msub    w6, w5, w2, w3
    add     w4, w4, #48
    add     w6, w6, #48
    add     w5, w5, #48
    cmp     w0, #10
    b.hs    2f
    mov     w7, #1
    orr     w7, w7, w4, lsl #8
    b       4f
2:  cmp     w0, #100
    b.hs    3f
    mov     w7, #2
    orr     w7, w7, w6, lsl #8
    orr     w7, w7, w4, lsl #16
    b       4f
3:  mov     w7, #3
    orr     w7, w7, w5, lsl #8
    orr     w7, w7, w6, lsl #16
    orr     w7, w7, w4, lsl #24
4:  str     w7, [x1, x0, lsl #2]
    add     w0, w0, #1
    cmp     w0, #512
    b.lo    1b
    ret

.p2align 2
_build_sin:
    LEA     x9, _sintab
    mov     w8, #0
Lbs:
    and     w0, w8, #511
    cmp     w0, #256
    b.ls    1f
    mov     w1, #512
    sub     w0, w1, w0
1:  IMM32   w1, 102944
    mul     w0, w0, w1
    lsr     w0, w0, #8
    sxtw    x0, w0
    mul     x1, x0, x0
    asr     x1, x1, #16
    mul     x2, x1, x0
    asr     x2, x2, #16
    mul     x3, x2, x1
    asr     x3, x3, #16
    mul     x4, x3, x1
    asr     x4, x4, #16
    mul     x5, x4, x1
    asr     x5, x5, #16
    mov     x6, #6
    sdiv    x2, x2, x6
    mov     x6, #120
    sdiv    x3, x3, x6
    mov     x6, #5040
    sdiv    x4, x4, x6
    IMM32   w6, 362880
    sdiv    x5, x5, x6
    sub     x0, x0, x2
    add     x0, x0, x3
    sub     x0, x0, x4
    add     x0, x0, x5
    tbz     w8, #9, 2f
    neg     x0, x0
2:  str     w0, [x9, x8, lsl #2]
    add     w8, w8, #1
    cmp     w8, #1024
    b.lo    Lbs
    ret

.p2align 2
_build_pal:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LEA     x19, _palstops
    LEA     x20, _pal
    mov     w21, #0
Lbp:
    mov     w22, #0
Lbp2:
    add     x0, x19, x21, lsl #6
    mov     w1, w22
    bl      _palsample
    add     x1, x20, x21, lsl #11
    str     w0, [x1, x22, lsl #2]
    add     w22, w22, #1
    cmp     w22, #256
    b.lo    Lbp2
    add     x1, x20, x21, lsl #11
    add     x1, x1, #1024
    mov     w2, #0
1:  str     w0, [x1, x2, lsl #2]
    add     w2, w2, #1
    cmp     w2, #256
    b.lo    1b
    add     w21, w21, #1
    cmp     w21, #4
    b.lo    Lbp
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret

.p2align 2
_palsample:
    mov     w2, #0
1:  add     x3, x0, x2, lsl #2
    ldrb    w4, [x3, #4]
    cmp     w1, w4
    b.lo    2f
    add     w2, w2, #1
    cmp     w2, #3
    b.lo    1b
    mov     w2, #3
2:  add     x3, x0, x2, lsl #2
    ldrb    w4, [x3]
    ldrb    w5, [x3, #4]
    sub     w6, w1, w4
    sub     w7, w5, w4
    cbnz    w7, 3f
    mov     w7, #1
3:  lsl     w6, w6, #8
    udiv    w6, w6, w7
    ldrb    w8, [x3, #1]
    ldrb    w9, [x3, #5]
    sub     w9, w9, w8
    mul     w9, w9, w6
    add     w8, w8, w9, asr #8
    ldrb    w9, [x3, #2]
    ldrb    w10, [x3, #6]
    sub     w10, w10, w9
    mul     w10, w10, w6
    add     w9, w9, w10, asr #8
    ldrb    w10, [x3, #3]
    ldrb    w11, [x3, #7]
    sub     w11, w11, w10
    mul     w11, w11, w6
    add     w10, w10, w11, asr #8
    and     w8, w8, #0xff
    and     w9, w9, #0xff
    and     w10, w10, #0xff
    lsl     w0, w8, #16
    orr     w0, w0, w9, lsl #8
    orr     w0, w0, w10
    ret

.p2align 2
_build_mesh:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LEA     x23, _sintab
    LEA     x21, _mvert
    LEA     x22, _mnorm
    mov     w19, #0
Lmu:
    mov     w20, #0
Lmv:
    lsl     w0, w19, #11
    ubfx    w1, w0, #6, #10
    ldr     w9, [x23, x1, lsl #2]
    add     w0, w0, #0x4000
    ubfx    w1, w0, #6, #10
    ldr     w10, [x23, x1, lsl #2]
    lsl     w0, w20, #12
    ubfx    w1, w0, #6, #10
    ldr     w11, [x23, x1, lsl #2]
    add     w0, w0, #0x4000
    ubfx    w1, w0, #6, #10
    ldr     w12, [x23, x1, lsl #2]

    mov     w2, #19661
    smull   x3, w12, w2
    asr     x3, x3, #16
    mov     w4, #40632
    add     w3, w4, w3
    smull   x5, w3, w10
    asr     x5, x5, #16
    smull   x6, w3, w9
    asr     x6, x6, #16
    smull   x7, w11, w2
    asr     x7, x7, #16
    str     w5, [x21]
    str     w6, [x21, #4]
    str     w7, [x21, #8]
    add     x21, x21, #12
    smull   x5, w12, w10
    asr     x5, x5, #16
    smull   x6, w12, w9
    asr     x6, x6, #16
    str     w5, [x22]
    str     w6, [x22, #4]
    str     w11, [x22, #8]
    add     x22, x22, #12

    add     w20, w20, #1
    cmp     w20, #NV
    b.lo    Lmv
    add     w19, w19, #1
    cmp     w19, #NU
    b.lo    Lmu

    LEA     x21, _mtri
    mov     w19, #0
Ltu:
    mov     w20, #0
Ltv:
    add     w0, w19, #1
    and     w0, w0, #NU-1
    add     w1, w20, #1
    and     w1, w1, #NV-1
    mov     w2, #NV
    madd    w3, w19, w2, w20
    madd    w4, w0, w2, w20
    madd    w5, w0, w2, w1
    madd    w6, w19, w2, w1
    strh    w3, [x21]
    strh    w4, [x21, #2]
    strh    w5, [x21, #4]
    strh    w3, [x21, #8]
    strh    w5, [x21, #10]
    strh    w6, [x21, #12]
    add     x21, x21, #16
    add     w20, w20, #1
    cmp     w20, #NV
    b.lo    Ltv
    add     w19, w19, #1
    cmp     w19, #NU
    b.lo    Ltu

    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x29, x30, [sp], #64
    ret

.p2align 2
_build_stars:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    LEA     x19, _star
    mov     w20, #0
1:  bl      _rand
    sbfx    w1, w0, #0, #17
    str     w1, [x19]
    bl      _rand
    sbfx    w1, w0, #0, #17
    str     w1, [x19, #4]
    bl      _rand
    IMM32   w2, 786432
    udiv    w3, w0, w2
    msub    w1, w3, w2, w0
    str     w1, [x19, #8]
    add     x19, x19, #12
    add     w20, w20, #1
    cmp     w20, #NSTAR
    b.lo    1b
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #32
    ret

.p2align 2
_build_tunnel:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LEA     x21, _tdist
    LEA     x22, _tang
    LEA     x23, _tshade
    mov     w19, #0
Ltny:
    mov     w20, #0
Ltnx:
    sub     w0, w20, #MAXW/2
    sub     w1, w19, #MAXH/2
    mov     w24, w0
    mov     w2, w1
    mul     w3, w0, w0
    madd    w3, w2, w2, w3
    mov     w0, w3
    bl      _isqrt
    mov     w4, w0
    cbnz    w4, 1f
    mov     w4, #1
1:  mov     w5, #6144
    udiv    w5, w5, w4
    strb    w5, [x21]
    add     x21, x21, #1
    mov     w5, w4
    lsl     w5, w5, #3
    cmp     w5, #255
    b.ls    2f
    mov     w5, #255
2:  strb    w5, [x23]
    add     x23, x23, #1
    mov     w0, w24
    sub     w1, w19, #MAXH/2
    bl      _atan2t
    lsr     w0, w0, #8
    strb    w0, [x22]
    add     x22, x22, #1
    add     w20, w20, #1
    cmp     w20, #MAXW
    b.lo    Ltnx
    add     w19, w19, #1
    cmp     w19, #MAXH
    b.lo    Ltny
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x29, x30, [sp], #64
    ret

.p2align 2
_atan2t:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    mov     w9, w0
    mov     w10, w1
    cmp     w0, #0
    cneg    w2, w0, lt
    cmp     w1, #0
    cneg    w3, w1, lt
    orr     w4, w2, w3
    cbnz    w4, 1f
    mov     w0, #0
    ldp     x29, x30, [sp], #32
    ret
1:  cmp     w2, w3
    b.lo    2f
    lsl     x5, x3, #16
    sxtw    x6, w2
    sdiv    x5, x5, x6
    mov     w0, w5
    bl      _atanp
    b       3f
2:  lsl     x5, x2, #16
    sxtw    x6, w3
    sdiv    x5, x5, x6
    mov     w0, w5
    bl      _atanp
    mov     w1, #16384
    sub     w0, w1, w0
3:  tbz     w9, #31, 4f
    mov     w1, #32768
    sub     w0, w1, w0
4:  tbz     w10, #31, 5f
    neg     w0, w0
5:  and     w0, w0, #0xffff
    ldp     x29, x30, [sp], #32
    ret

.p2align 2
_atanp:
    sxtw    x0, w0
    mov     x1, #51472
    mul     x1, x0, x1
    asr     x1, x1, #16
    mov     x2, #65536
    sub     x2, x0, x2
    mul     x2, x2, x0
    asr     x2, x2, #16
    mov     x3, #4345
    mul     x3, x3, x0
    asr     x3, x3, #16
    mov     x4, #16035
    add     x3, x3, x4
    mul     x2, x2, x3
    asr     x2, x2, #16
    sub     x0, x1, x2
    mov     x1, #10430
    mul     x0, x0, x1
    asr     x0, x0, #16
    ret

.p2align 2
_build_tex:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    LEA     x21, _tex
    LEA     x22, _sintab
    mov     w19, #0
1:  mov     w20, #0
2:  lsr     w0, w19, #3
    lsr     w1, w20, #3
    eor     w0, w0, w1
    and     w0, w0, #15
    mov     w1, #17
    mul     w0, w0, w1
    lsl     w1, w20, #10
    ubfx    w2, w1, #6, #10
    ldr     w2, [x22, x2, lsl #2]
    lsl     w1, w19, #11
    ubfx    w3, w1, #6, #10
    ldr     w3, [x22, x3, lsl #2]
    add     w2, w2, w3
    asr     w2, w2, #12
    add     w0, w0, w2
    and     w0, w0, #0xf0
    mov     w4, #TEXW
    madd    w5, w19, w4, w20
    LEA     x6, _tex
    strb    w0, [x6, x5]
    add     w20, w20, #1
    cmp     w20, #TEXW
    b.lo    2b
    add     w19, w19, #1
    cmp     w19, #TEXW
    b.lo    1b
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x29, x30, [sp], #48
    ret

.p2align 2
_clearfb:
    LEA     x0, _fbw
    ldr     w1, [x0]
    LEA     x0, _fbh
    ldr     w2, [x0]
    mul     w1, w1, w2
    LEA     x0, _fb
    lsl     w2, w1, #2
    movi    v0.16b, #0
1:  stp     q0, q0, [x0], #32
    subs    w2, w2, #32
    b.hi    1b
    ret

.p2align 2
_clearz:
    LEA     x0, _fbw
    ldr     w1, [x0]
    LEA     x0, _fbh
    ldr     w2, [x0]
    mul     w1, w1, w2
    LEA     x0, _zbuf
    lsl     w2, w1, #1
    movi    v0.16b, #0
1:  stp     q0, q0, [x0], #32
    subs    w2, w2, #32
    b.hi    1b
    ret

.p2align 2
_render_frame:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    LEA     x1, _tskew
    ldr     w1, [x1]
    add     w0, w0, w1
    mov     w1, #T_END
    udiv    w2, w0, w1
    msub    w0, w2, w1, w0
    LEA     x1, _tms
    str     w0, [x1]
    mov     w19, w0
    bl      _clearfb

    mov     w0, #T_TORUS
    cmp     w19, w0
    b.lo    Lsc0
    mov     w0, #T_TUNNEL
    cmp     w19, w0
    b.lo    Lsc1
    mov     w0, #T_ROTO
    cmp     w19, w0
    b.lo    Lsc2
    mov     w0, #T_BALLS
    cmp     w19, w0
    b.lo    Lsc3
    bl      _scene_balls
    mov     w20, #T_BALLS
    mov     w0, #T_END
    b       Lscdone
Lsc0:
    bl      _scene_stars
    mov     w20, #T_STARS
    mov     w0, #T_TORUS
    b       Lscdone
Lsc1:
    bl      _scene_torus
    mov     w20, #T_TORUS
    mov     w0, #T_TUNNEL
    b       Lscdone
Lsc2:
    bl      _scene_tunnel
    mov     w20, #T_TUNNEL
    mov     w0, #T_ROTO
    b       Lscdone
Lsc3:
    bl      _scene_roto
    mov     w20, #T_ROTO
    mov     w0, #T_BALLS
Lscdone:
    sub     w1, w19, w20
    sub     w2, w0, w19
    cmp     w1, w2
    csel    w1, w1, w2, lo
    mov     w2, #FADEMS
    cmp     w1, w2
    b.hs    Lnofade
    lsl     w1, w1, #8
    udiv    w1, w1, w2
    cmp     w1, #255
    csel    w0, w1, wzr, lo
    b.lo    1f
    mov     w0, #255
1:  bl      _fade
Lnofade:
    LEA     x0, _showfps
    ldr     w0, [x0]
    cbz     w0, 1f
    LEA     x0, _fpsval
    ldr     w0, [x0]
    bl      _fmtfps
    LEA     x0, _fpsbuf
    mov     w1, #1
    mov     w2, #1
    IMM32   w3, 0x30ff60
    mov     w4, #1
    bl      _drawstr
1:  ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #48
    ret

.p2align 2
_fmtfps:
    LEA     x1, _fpsbuf
    mov     w2, #100
    udiv    w3, w0, w2
    cbz     w3, 1f
    add     w3, w3, #48
    strb    w3, [x1], #1
1:  mov     w2, #100
    udiv    w3, w0, w2
    msub    w0, w3, w2, w0
    mov     w2, #10
    udiv    w3, w0, w2
    add     w3, w3, #48
    strb    w3, [x1], #1
    mov     w2, #10
    udiv    w3, w0, w2
    msub    w0, w3, w2, w0
    add     w0, w0, #48
    strb    w0, [x1], #1
    mov     w0, #32
    strb    w0, [x1], #1
    mov     w0, #70
    strb    w0, [x1], #1
    mov     w0, #80
    strb    w0, [x1], #1
    mov     w0, #83
    strb    w0, [x1], #1
    strb    wzr, [x1]
    ret

.p2align 2
_fade:
    dup     v1.16b, w0
    LEA     x1, _fbw
    ldr     w2, [x1]
    LEA     x1, _fbh
    ldr     w3, [x1]
    mul     w2, w2, w3
    lsl     w2, w2, #2
    LEA     x0, _fb
1:  ldr     q0, [x0]
    umull   v2.8h, v0.8b, v1.8b
    umull2  v3.8h, v0.16b, v1.16b
    shrn    v2.8b, v2.8h, #8
    shrn2   v2.16b, v3.8h, #8
    str     q2, [x0], #16
    subs    w2, w2, #16
    b.hi    1b
    ret

.p2align 2
_putadd:
    LEA     x3, _fbw
    ldr     w3, [x3]
    cmp     w0, w3
    b.hs    1f
    LEA     x4, _fbh
    ldr     w4, [x4]
    cmp     w1, w4
    b.hs    1f
    madd    w3, w1, w3, w0
    LEA     x4, _fb
    add     x4, x4, x3, lsl #2
    ldr     w5, [x4]
    fmov    s0, w5
    fmov    s1, w2
    uqadd   v0.8b, v0.8b, v1.8b
    fmov    w5, s0
    str     w5, [x4]
1:  ret

.p2align 2
_scene_stars:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    LEA     x0, _tms
    ldr     w19, [x0]
    LEA     x0, _cx
    ldr     w21, [x0]
    asr     w21, w21, #16
    LEA     x0, _cy
    ldr     w22, [x0]
    asr     w22, w22, #16
    LEA     x0, _focal
    ldr     w23, [x0]
    LEA     x24, _sintab
    mov     w0, #11
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w25, [x24, x1, lsl #2]
    add     w0, w0, #0x4000
    ubfx    w1, w0, #6, #10
    ldr     w26, [x24, x1, lsl #2]
    mov     w0, #175
    mul     w0, w19, w0
    str     w0, [sp, #96]
    LEA     x20, _star
    mov     w27, #0
Lst:
    ldr     w0, [x20]
    ldr     w1, [x20, #4]
    ldr     w2, [x20, #8]
    ldr     w3, [sp, #96]
    add     w2, w2, w3
    IMM32   w3, 786432
    udiv    w4, w2, w3
    msub    w2, w4, w3, w2
    sub     w2, w3, w2
    add     w2, w2, #16384
    smull   x3, w0, w26
    smull   x4, w1, w25
    sub     x3, x3, x4
    asr     x3, x3, #16
    smull   x4, w0, w25
    smull   x5, w1, w26
    add     x4, x4, x5
    asr     x4, x4, #16
    str     w2, [sp, #100]
    mov     w28, #0
Lstrail:
    ldr     w2, [sp, #100]
    mov     w5, #14000
    madd    w2, w28, w5, w2
    sxtw    x5, w2
    lsl     x6, x3, #16
    sdiv    x6, x6, x5
    lsl     x7, x4, #16
    sdiv    x7, x7, x5
    sxtw    x8, w23
    mul     x6, x6, x8
    mul     x7, x7, x8
    asr     w6, w6, #16
    asr     w7, w7, #16
    add     w6, w21, w6
    sub     w7, w22, w7
    mov     w8, #0x1000000
    sdiv    x8, x8, x5
    lsl     w9, w28, #1
    add     w9, w9, #2
    udiv    w8, w8, w9
    cmp     w8, #255
    csel    w8, w8, wzr, ls
    b.ls    1f
    mov     w8, #255
1:  cbz     w8, 2f
    lsr     w9, w8, #2
    sub     w9, w8, w9
    lsl     w10, w9, #16
    orr     w10, w10, w8, lsl #8
    orr     w10, w10, w8
    stp     x3, x4, [sp, #104]
    mov     w0, w6
    mov     w1, w7
    mov     w2, w10
    bl      _putadd
    ldp     x3, x4, [sp, #104]
2:  add     w28, w28, #1
    cmp     w28, #3
    b.lo    Lstrail
    add     x20, x20, #12
    add     w27, w27, #1
    cmp     w27, #NSTAR
    b.lo    Lst

    mov     w0, #34
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w1, [x24, x1, lsl #2]
    asr     w1, w1, #12
    LEA     x0, _title
    add     w2, w22, w1
    sub     w2, w2, #8
    LEA     x3, _fbw
    ldr     w3, [x3]
    lsr     w3, w3, #1
    sub     w3, w3, #40
    mov     w1, w3
    IMM32   w3, 0x9ce8ff
    mov     w4, #2
    bl      _drawstr

    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #112
    ret

.p2align 2
_setmat:
    stp     x29, x30, [sp, #-16]!
    LEA     x9, _sintab
    ubfx    w3, w0, #6, #10
    ldr     w10, [x9, x3, lsl #2]
    add     w3, w0, #0x4000
    ubfx    w3, w3, #6, #10
    ldr     w11, [x9, x3, lsl #2]
    ubfx    w3, w1, #6, #10
    ldr     w12, [x9, x3, lsl #2]
    add     w3, w1, #0x4000
    ubfx    w3, w3, #6, #10
    ldr     w13, [x9, x3, lsl #2]
    ubfx    w3, w2, #6, #10
    ldr     w14, [x9, x3, lsl #2]
    add     w3, w2, #0x4000
    ubfx    w3, w3, #6, #10
    ldr     w15, [x9, x3, lsl #2]
    LEA     x8, _mat

    smull   x0, w15, w13
    asr     x0, x0, #16
    str     w0, [x8]
    smull   x0, w15, w12
    asr     x0, x0, #16
    smull   x1, w0, w10
    asr     x1, x1, #16
    smull   x2, w14, w11
    asr     x2, x2, #16
    sub     w1, w1, w2
    str     w1, [x8, #4]
    smull   x1, w0, w11
    asr     x1, x1, #16
    smull   x2, w14, w10
    asr     x2, x2, #16
    add     w1, w1, w2
    str     w1, [x8, #8]

    smull   x0, w14, w13
    asr     x0, x0, #16
    str     w0, [x8, #12]
    smull   x0, w14, w12
    asr     x0, x0, #16
    smull   x1, w0, w10
    asr     x1, x1, #16
    smull   x2, w15, w11
    asr     x2, x2, #16
    add     w1, w1, w2
    str     w1, [x8, #16]
    smull   x1, w0, w11
    asr     x1, x1, #16
    smull   x2, w15, w10
    asr     x2, x2, #16
    sub     w1, w1, w2
    str     w1, [x8, #20]

    neg     w0, w12
    str     w0, [x8, #24]
    smull   x0, w13, w10
    asr     x0, x0, #16
    str     w0, [x8, #28]
    smull   x0, w13, w11
    asr     x0, x0, #16
    str     w0, [x8, #32]
    ldp     x29, x30, [sp], #16
    ret

.p2align 2
_xform:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    str     x0, [sp, #96]
    LEA     x19, _mat
    LEA     x20, _mnorm
    LEA     x22, _svx
    LEA     x23, _svy
    LEA     x24, _svz
    LEA     x25, _svi
    LEA     x0, _cx
    ldr     w26, [x0]
    LEA     x0, _cy
    ldr     w27, [x0]
    LEA     x0, _focal
    ldr     w28, [x0]
    mov     w21, #0
Lxf:
    ldr     x0, [sp, #96]
    add     x0, x0, x21, lsl #2
    add     x0, x0, x21, lsl #3
    ldr     w1, [x0]
    ldr     w2, [x0, #4]
    ldr     w3, [x0, #8]
    ldp     w4, w5, [x19]
    ldr     w6, [x19, #8]
    smull   x7, w4, w1
    smull   x8, w5, w2
    add     x7, x7, x8
    smull   x8, w6, w3
    add     x7, x7, x8
    asr     x7, x7, #16
    ldp     w4, w5, [x19, #12]
    ldr     w6, [x19, #20]
    smull   x8, w4, w1
    smull   x9, w5, w2
    add     x8, x8, x9
    smull   x9, w6, w3
    add     x8, x8, x9
    asr     x8, x8, #16
    ldp     w4, w5, [x19, #24]
    ldr     w6, [x19, #32]
    smull   x9, w4, w1
    smull   x10, w5, w2
    add     x9, x9, x10
    smull   x10, w6, w3
    add     x9, x9, x10
    asr     x9, x9, #16
    LEA     x10, _zdist
    ldr     w10, [x10]
    add     w9, w9, w10
    mov     w10, #26214
    cmp     w9, w10
    csel    w9, w9, w10, gt

    sxtw    x10, w9
    lsl     x11, x7, #16
    sdiv    x11, x11, x10
    lsl     x12, x8, #16
    sdiv    x12, x12, x10
    sxtw    x13, w28
    mul     x11, x11, x13
    mul     x12, x12, x13
    add     w11, w26, w11
    sub     w12, w27, w12
    str     w11, [x22, x21, lsl #2]
    str     w12, [x23, x21, lsl #2]
    mov     x11, #0x40000000
    sdiv    x11, x11, x10
    mov     w13, #65535
    cmp     w11, w13
    csel    w11, w11, w13, lo
    cmp     w11, #1
    csel    w11, w11, wzr, ge
    str     w11, [x24, x21, lsl #2]

    add     x0, x20, x21, lsl #2
    add     x0, x0, x21, lsl #3
    ldr     w1, [x0]
    ldr     w2, [x0, #4]
    ldr     w3, [x0, #8]
    ldp     w4, w5, [x19]
    ldr     w6, [x19, #8]
    smull   x7, w4, w1
    smull   x13, w5, w2
    add     x7, x7, x13
    smull   x13, w6, w3
    add     x7, x7, x13
    asr     x7, x7, #16
    ldp     w4, w5, [x19, #12]
    ldr     w6, [x19, #20]
    smull   x8, w4, w1
    smull   x13, w5, w2
    add     x8, x8, x13
    smull   x13, w6, w3
    add     x8, x8, x13
    asr     x8, x8, #16
    ldp     w4, w5, [x19, #24]
    ldr     w6, [x19, #32]
    smull   x9, w4, w1
    smull   x13, w5, w2
    add     x9, x9, x13
    smull   x13, w6, w3
    add     x9, x9, x13
    asr     x9, x9, #16

    mov     w4, #24000
    mov     w5, #36000
    mov     w6, #-46000
    smull   x13, w7, w4
    smull   x14, w8, w5
    add     x13, x13, x14
    smull   x14, w9, w6
    add     x13, x13, x14
    asr     x13, x13, #16
    cmp     x13, #0
    csel    x13, x13, xzr, gt
    mov     x14, x13
    mul     x14, x14, x14
    asr     x14, x14, #16
    mul     x14, x14, x14
    asr     x14, x14, #16
    mul     x14, x14, x14
    asr     x14, x14, #16
    mov     w15, #30
    mov     w0, #150
    mul     x13, x13, x0
    asr     x13, x13, #16
    add     w15, w15, w13
    mov     w0, #170
    mul     x14, x14, x0
    asr     x14, x14, #16
    add     w15, w15, w14
    cmp     w15, #255
    b.ls    2f
    mov     w15, #255
2:  str     w15, [x25, x21, lsl #2]

    add     w21, w21, #1
    cmp     w21, #NVERT
    b.lo    Lxf
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #112
    ret

.p2align 2
_scene_torus:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    bl      _clearz
    LEA     x0, _tms
    ldr     w19, [x0]
    mov     w0, #T_TORUS
    sub     w19, w19, w0
    LEA     x0, _zdist
    IMM32   w1, 180000
    mov     w2, #40
    mul     w2, w19, w2
    ubfx    w3, w2, #6, #10
    LEA     x4, _sintab
    ldr     w3, [x4, x3, lsl #2]
    add     w1, w1, w3, asr #1
    str     w1, [x0]
    mov     w0, #29
    mul     w0, w19, w0
    mov     w1, #17
    mul     w1, w19, w1
    mov     w2, #11
    mul     w2, w19, w2
    bl      _setmat
    LEA     x0, _mvert
    bl      _xform
    LEA     x0, _palsel
    mov     w1, #0
    str     w1, [x0]
    LEA     x19, _mtri
    mov     w20, #0
1:  ldrh    w0, [x19]
    ldrh    w1, [x19, #2]
    ldrh    w2, [x19, #4]
    add     x19, x19, #8
    bl      _raster
    add     w20, w20, #1
    cmp     w20, #NTRI
    b.lo    1b
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x29, x30, [sp], #64
    ret

.p2align 2
_raster:
    stp     x29, x30, [sp, #-240]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    str     w0, [sp, #192]
    str     w1, [sp, #196]
    str     w2, [sp, #200]

    LEA     x9, _svx
    LEA     x10, _svy
    ldr     w3, [x9, x0, lsl #2]
    ldr     w4, [x10, x0, lsl #2]
    ldr     w5, [x9, x1, lsl #2]
    ldr     w6, [x10, x1, lsl #2]
    ldr     w7, [x9, x2, lsl #2]
    ldr     w8, [x10, x2, lsl #2]
    asr     w3, w3, #12
    asr     w4, w4, #12
    asr     w5, w5, #12
    asr     w6, w6, #12
    asr     w7, w7, #12
    asr     w8, w8, #12

    sub     w11, w5, w3
    sub     w12, w8, w4
    mul     w11, w11, w12
    sub     w13, w6, w4
    sub     w14, w7, w3
    mul     w13, w13, w14
    sub     w11, w11, w13
    cmp     w11, #AREA_MIN
    b.le    Lrdone

    cmp     w3, w5
    csel    w14, w3, w5, lt
    cmp     w14, w7
    csel    w14, w14, w7, lt
    cmp     w3, w5
    csel    w15, w3, w5, gt
    cmp     w15, w7
    csel    w15, w15, w7, gt
    cmp     w4, w6
    csel    w16, w4, w6, lt
    cmp     w16, w8
    csel    w16, w16, w8, lt
    cmp     w4, w6
    csel    w17, w4, w6, gt
    cmp     w17, w8
    csel    w17, w17, w8, gt
    asr     w14, w14, #4
    add     w15, w15, #15
    asr     w15, w15, #4
    asr     w16, w16, #4
    add     w17, w17, #15
    asr     w17, w17, #4
    LEA     x19, _fbw
    ldr     w19, [x19]
    LEA     x20, _fbh
    ldr     w20, [x20]
    cmp     w14, #0
    csel    w14, w14, wzr, gt
    cmp     w16, #0
    csel    w16, w16, wzr, gt
    sub     w21, w19, #1
    cmp     w15, w21
    csel    w15, w15, w21, lt
    sub     w21, w20, #1
    cmp     w17, w21
    csel    w17, w17, w21, lt
    cmp     w14, w15
    b.gt    Lrdone
    cmp     w16, w17
    b.gt    Lrdone
    str     w14, [sp, #108]
    str     w15, [sp, #112]
    str     w17, [sp, #116]
    str     w16, [sp, #120]

    lsl     w21, w14, #4
    add     w21, w21, #8
    lsl     w22, w16, #4
    add     w22, w22, #8

    sub     w23, w7, w5
    sub     w24, w22, w6
    mul     w23, w23, w24
    sub     w24, w8, w6
    sub     w25, w21, w5
    mul     w24, w24, w25
    sub     w23, w23, w24
    sub     w24, w3, w7
    sub     w25, w22, w8
    mul     w24, w24, w25
    sub     w25, w4, w8
    sub     w26, w21, w7
    mul     w25, w25, w26
    sub     w24, w24, w25
    sub     w25, w5, w3
    sub     w26, w22, w4
    mul     w25, w25, w26
    sub     w26, w6, w4
    sub     w27, w21, w3
    mul     w26, w26, w27
    sub     w25, w25, w26
    str     w23, [sp, #96]
    str     w24, [sp, #100]
    str     w25, [sp, #104]

    sub     w0, w6, w8
    lsl     w0, w0, #4
    str     w0, [sp, #128]
    sub     w0, w8, w4
    lsl     w0, w0, #4
    str     w0, [sp, #132]
    sub     w0, w4, w6
    lsl     w0, w0, #4
    str     w0, [sp, #136]
    sub     w0, w7, w5
    lsl     w0, w0, #4
    str     w0, [sp, #144]
    sub     w0, w3, w7
    lsl     w0, w0, #4
    str     w0, [sp, #148]
    sub     w0, w5, w3
    lsl     w0, w0, #4
    str     w0, [sp, #152]

    sxtw    x11, w11
    LEA     x9, _svz
    LEA     x10, _svi
    ldr     w0, [sp, #192]
    ldr     w1, [sp, #196]
    ldr     w2, [sp, #200]
    ldr     w3, [x9, x0, lsl #2]
    lsl     x3, x3, #16
    sdiv    x3, x3, x11
    ldr     w4, [x9, x1, lsl #2]
    lsl     x4, x4, #16
    sdiv    x4, x4, x11
    ldr     w5, [x9, x2, lsl #2]
    lsl     x5, x5, #16
    sdiv    x5, x5, x11
    ldr     w6, [x10, x0, lsl #2]
    lsl     x6, x6, #16
    sdiv    x6, x6, x11
    ldr     w7, [x10, x1, lsl #2]
    lsl     x7, x7, #16
    sdiv    x7, x7, x11
    ldr     w8, [x10, x2, lsl #2]
    lsl     x8, x8, #16
    sdiv    x8, x8, x11

    sxtw    x0, w23
    mul     x9, x0, x3
    sxtw    x1, w24
    madd    x9, x1, x4, x9
    sxtw    x2, w25
    madd    x9, x2, x5, x9
    str     x9, [sp, #160]
    mul     x9, x0, x6
    madd    x9, x1, x7, x9
    madd    x9, x2, x8, x9
    str     x9, [sp, #168]

    ldrsw   x0, [sp, #128]
    ldrsw   x1, [sp, #132]
    ldrsw   x2, [sp, #136]
    mul     x9, x0, x3
    madd    x9, x1, x4, x9
    madd    x9, x2, x5, x9
    mov     x16, x9
    mul     x9, x0, x6
    madd    x9, x1, x7, x9
    madd    x9, x2, x8, x9
    mov     x17, x9

    ldrsw   x0, [sp, #144]
    ldrsw   x1, [sp, #148]
    ldrsw   x2, [sp, #152]
    mul     x9, x0, x3
    madd    x9, x1, x4, x9
    madd    x9, x2, x5, x9
    str     x9, [sp, #176]
    mul     x9, x0, x6
    madd    x9, x1, x7, x9
    madd    x9, x2, x8, x9
    str     x9, [sp, #184]

    ldr     w13, [sp, #128]
    ldr     w14, [sp, #132]
    ldr     w15, [sp, #136]
    LEA     x21, _palsel
    ldr     w21, [x21]
    LEA     x0, _pal
    add     x21, x0, x21, lsl #11
    LEA     x19, _fb
    LEA     x20, _zbuf
    LEA     x1, _fbw
    ldr     w1, [x1]
    str     w1, [sp, #124]

Lrrow:
    ldr     w0, [sp, #120]
    ldr     w1, [sp, #116]
    cmp     w0, w1
    b.gt    Lrdone
    ldr     w1, [sp, #124]
    mul     w1, w0, w1
    add     x11, x19, x1, lsl #2
    add     x12, x20, x1, lsl #1
    ldr     w22, [sp, #96]
    ldr     w23, [sp, #100]
    ldr     w24, [sp, #104]
    ldr     x25, [sp, #160]
    ldr     x26, [sp, #168]
    ldr     w27, [sp, #108]
    ldr     w28, [sp, #112]
Lrcol:
    orr     w0, w22, w23
    orr     w0, w0, w24
    tbnz    w0, #31, Lrnext
    asr     x1, x25, #16
    ldrh    w2, [x12, x27, lsl #1]
    cmp     w1, w2
    b.le    Lrnext
    strh    w1, [x12, x27, lsl #1]
    asr     x3, x26, #16
    bic     w3, w3, w3, asr #31
    and     w3, w3, #0x1fc
    ldr     w4, [x21, x3, lsl #2]
    str     w4, [x11, x27, lsl #2]
Lrnext:
    add     w22, w22, w13
    add     w23, w23, w14
    add     w24, w24, w15
    add     x25, x25, x16
    add     x26, x26, x17
    add     w27, w27, #1
    cmp     w27, w28
    b.le    Lrcol

    ldr     w0, [sp, #96]
    ldr     w1, [sp, #144]
    add     w0, w0, w1
    str     w0, [sp, #96]
    ldr     w0, [sp, #100]
    ldr     w1, [sp, #148]
    add     w0, w0, w1
    str     w0, [sp, #100]
    ldr     w0, [sp, #104]
    ldr     w1, [sp, #152]
    add     w0, w0, w1
    str     w0, [sp, #104]
    ldr     x0, [sp, #160]
    ldr     x1, [sp, #176]
    add     x0, x0, x1
    str     x0, [sp, #160]
    ldr     x0, [sp, #168]
    ldr     x1, [sp, #184]
    add     x0, x0, x1
    str     x0, [sp, #168]
    ldr     w0, [sp, #120]
    add     w0, w0, #1
    str     w0, [sp, #120]
    b       Lrrow

Lrdone:
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #240
    ret

.p2align 2
_scene_tunnel:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    LEA     x0, _tms
    ldr     w19, [x0]
    mov     w0, #T_TUNNEL
    sub     w19, w19, w0
    LEA     x24, _sintab
    mov     w0, #21
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w25, [x24, x1, lsl #2]
    asr     w25, w25, #12
    mov     w0, #15
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w26, [x24, x1, lsl #2]
    asr     w26, w26, #13
    mov     w0, #60
    mul     w27, w19, w0
    lsr     w27, w27, #4
    mov     w0, #26
    mul     w28, w19, w0
    lsr     w28, w28, #5
    LEA     x0, _fbw
    ldr     w20, [x0]
    LEA     x0, _fbh
    ldr     w21, [x0]
    mov     w0, #MAXW
    sub     w0, w0, w20
    lsr     w0, w0, #1
    add     w25, w25, w0
    mov     w0, #MAXH
    sub     w0, w0, w21
    lsr     w0, w0, #1
    add     w26, w26, w0
    LEA     x0, _palsel
    mov     w1, #1
    str     w1, [x0]
    LEA     x22, _fb
    mov     w23, #0
Ltuy:
    add     w0, w23, w26
    mov     w1, #MAXW
    mul     w0, w0, w1
    add     w0, w0, w25
    LEA     x1, _tdist
    add     x1, x1, x0
    LEA     x2, _tang
    add     x2, x2, x0
    LEA     x3, _tshade
    add     x3, x3, x0
    LEA     x4, _pal
    add     x4, x4, #2048
    mov     w5, #0
Ltux:
    ldrb    w6, [x1, x5]
    ldrb    w7, [x2, x5]
    ldrb    w8, [x3, x5]
    add     w6, w6, w27
    add     w7, w7, w28
    and     w6, w6, #0xff
    and     w7, w7, #0xff
    lsr     w9, w6, #4
    lsr     w10, w7, #4
    eor     w9, w9, w10
    tst     w9, #1
    mov     w10, #255
    mov     w11, #120
    csel    w9, w10, w11, ne
    mul     w9, w9, w8
    lsr     w9, w9, #8
    and     w9, w9, #0xf8
    ldr     w10, [x4, x9, lsl #2]
    str     w10, [x22, x5, lsl #2]
    add     w5, w5, #1
    cmp     w5, w20
    b.lo    Ltux
    add     x22, x22, x20, lsl #2
    add     w23, w23, #1
    cmp     w23, w21
    b.lo    Ltuy
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #96
    ret

.p2align 2
_scene_roto:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    LEA     x0, _tms
    ldr     w19, [x0]
    mov     w0, #T_ROTO
    sub     w19, w19, w0
    LEA     x24, _sintab
    mov     w0, #22
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w9, [x24, x1, lsl #2]
    add     w0, w0, #0x4000
    ubfx    w1, w0, #6, #10
    ldr     w10, [x24, x1, lsl #2]
    mov     w0, #13
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w11, [x24, x1, lsl #2]
    mov     w12, #98304
    add     w11, w12, w11, asr #1
    smull   x9, w9, w11
    asr     x9, x9, #16
    smull   x10, w10, w11
    asr     x10, x10, #16
    mov     w25, w9
    mov     w26, w10
    LEA     x0, _fbw
    ldr     w20, [x0]
    LEA     x0, _fbh
    ldr     w21, [x0]
    lsr     w0, w20, #1
    lsr     w1, w21, #1
    neg     w2, w0
    neg     w3, w1
    mul     w4, w2, w26
    mul     w5, w3, w25
    sub     w27, w4, w5
    mul     w4, w2, w25
    mul     w5, w3, w26
    add     w28, w4, w5
    mov     w0, #37
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w0, [x24, x1, lsl #2]
    add     w27, w27, w0, asr #1
    mov     w0, #43
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w0, [x24, x1, lsl #2]
    add     w28, w28, w0, asr #1
    LEA     x0, _palsel
    mov     w1, #2
    str     w1, [x0]
    LEA     x22, _fb
    mov     w23, #0
    mov     w0, #7
    mul     w19, w19, w0
    lsr     w19, w19, #4
Lroy:
    mov     w5, #0
    mov     w6, w27
    mov     w7, w28
    LEA     x8, _tex
    LEA     x4, _pal
    add     x4, x4, #4096
Lrox:
    asr     w9, w6, #16
    asr     w10, w7, #16
    and     w9, w9, #TEXW-1
    and     w10, w10, #TEXW-1
    mov     w11, #TEXW
    madd    w9, w10, w11, w9
    ldrb    w9, [x8, x9]
    add     w9, w9, w19
    and     w9, w9, #0xf0
    ldr     w12, [x4, x9, lsl #2]
    str     w12, [x22, x5, lsl #2]
    add     w6, w6, w26
    add     w7, w7, w25
    add     w5, w5, #1
    cmp     w5, w20
    b.lo    Lrox
    neg     w0, w25
    add     w27, w27, w0
    add     w28, w28, w26
    add     x22, x22, x20, lsl #2
    add     w23, w23, #1
    cmp     w23, w21
    b.lo    Lroy
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #112
    ret

.p2align 2
_scene_balls:
    stp     x29, x30, [sp, #-96]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    bl      _clearz
    LEA     x0, _tms
    ldr     w19, [x0]
    mov     w0, #T_BALLS
    sub     w19, w19, w0
    LEA     x0, _zdist
    IMM32   w1, 190000
    str     w1, [x0]

    LEA     x24, _sintab
    mov     w0, #9
    mul     w0, w19, w0
    ubfx    w1, w0, #6, #10
    ldr     w20, [x24, x1, lsl #2]
    add     w20, w20, #65536
    lsr     w20, w20, #1
    LEA     x21, _mvert
    LEA     x22, _mnorm
    LEA     x23, _morph
    mov     w25, #0
1:  ldr     w0, [x21], #4
    ldr     w1, [x22], #4
    mov     w2, #40960
    smull   x1, w1, w2
    asr     x1, x1, #16
    sub     w1, w1, w0
    smull   x1, w1, w20
    asr     x1, x1, #16
    add     w0, w0, w1
    str     w0, [x23], #4
    add     w25, w25, #1
    cmp     w25, #NVERT*3
    b.lo    1b

    mov     w0, #24
    mul     w0, w19, w0
    mov     w1, #15
    mul     w1, w19, w1
    mov     w2, #9
    mul     w2, w19, w2
    bl      _setmat
    LEA     x0, _morph
    bl      _xform
    LEA     x0, _palsel
    mov     w1, #3
    str     w1, [x0]

    mov     w19, #0
Lball:
    LEA     x0, _svz
    ldr     w0, [x0, x19, lsl #2]
    cbz     w0, Lballn
    mov     w0, w19
    bl      _drawball
Lballn:
    add     w19, w19, #2
    cmp     w19, #NVERT
    b.lo    Lball

    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #96
    ret

.p2align 2
_drawball:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    LEA     x1, _svx
    ldr     w2, [x1, x0, lsl #2]
    asr     w19, w2, #16
    LEA     x1, _svy
    ldr     w2, [x1, x0, lsl #2]
    asr     w20, w2, #16
    LEA     x1, _svz
    ldr     w21, [x1, x0, lsl #2]
    LEA     x1, _svi
    ldr     w22, [x1, x0, lsl #2]

    LEA     x1, _focal
    ldr     w1, [x1]
    mov     w0, w21
    mul     x0, x0, x1
    lsr     x23, x0, #17
    cmp     w23, #1
    csel    w23, w23, wzr, ge
    b.ge    1f
    mov     w23, #1
1:  cmp     w23, #10
    b.ls    2f
    mov     w23, #10
2:  mul     w24, w23, w23
    mov     x0, x21
    mul     x0, x0, x0
    mov     x1, #7864
    mul     x0, x0, x1
    lsr     x0, x0, #30
    str     w0, [sp, #96]

    LEA     x0, _fbw
    ldr     w25, [x0]
    LEA     x0, _fbh
    ldr     w26, [x0]
    sub     w27, w20, w23
    add     w28, w20, w23
Lby:
    cmp     w27, w28
    b.gt    Lbdone
    cmp     w27, #0
    b.lt    Lbyn
    cmp     w27, w26
    b.ge    Lbdone
    sub     w0, w27, w20
    mul     w0, w0, w0
    sub     w1, w19, w23
Lbx:
    add     w2, w19, w23
    cmp     w1, w2
    b.gt    Lbyn
    cmp     w1, #0
    b.lt    Lbxn
    cmp     w1, w25
    b.ge    Lbyn
    sub     w2, w1, w19
    mul     w2, w2, w2
    add     w2, w2, w0
    cmp     w2, w24
    b.gt    Lbxn
    lsl     w3, w2, #16
    udiv    w3, w3, w24
    mov     w4, #65536
    sub     w3, w4, w3
    lsr     w3, w3, #8
    LEA     x4, _nztab
    ldrb    w4, [x4, x3]
    ldr     w5, [sp, #96]
    mul     w5, w4, w5
    lsr     w5, w5, #8
    add     w5, w21, w5
    mov     w6, #65535
    cmp     w5, w6
    csel    w5, w5, w6, ls
    mul     w6, w27, w25
    add     w6, w6, w1
    LEA     x7, _zbuf
    ldrh    w8, [x7, x6, lsl #1]
    cmp     w5, w8
    b.le    Lbxn
    strh    w5, [x7, x6, lsl #1]
    sub     w9, w1, w19
    sub     w10, w27, w20
    mov     w11, #150
    mul     w9, w9, w11
    sdiv    w9, w9, w23
    mul     w10, w10, w11
    sdiv    w10, w10, w23
    lsl     w11, w4, #1
    sub     w12, w9, w10
    add     w12, w12, w11
    asr     w12, w12, #1
    cmp     w12, #0
    csel    w12, w12, wzr, gt
    cmp     w12, #255
    b.ls    4f
    mov     w12, #255
4:  add     w12, w12, w22
    lsr     w12, w12, #1
    LEA     x13, _palsel
    ldr     w13, [x13]
    LEA     x14, _pal
    add     x14, x14, x13, lsl #11
    ldr     w15, [x14, x12, lsl #2]
    LEA     x14, _fb
    str     w15, [x14, x6, lsl #2]
Lbxn:
    add     w1, w1, #1
    b       Lbx
Lbyn:
    add     w27, w27, #1
    b       Lby
Lbdone:
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #112
    ret

.p2align 2
_putpix:
    LEA     x3, _fbw
    ldr     w3, [x3]
    cmp     w0, w3
    b.hs    1f
    LEA     x4, _fbh
    ldr     w4, [x4]
    cmp     w1, w4
    b.hs    1f
    madd    w3, w1, w3, w0
    LEA     x4, _fb
    str     w2, [x4, x3, lsl #2]
1:  ret

.p2align 2
_drawstr:
    stp     x29, x30, [sp, #-112]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    mov     x19, x0
    mov     w20, w1
    mov     w21, w2
    mov     w22, w3
    str     w4, [sp, #96]
Lds:
    ldrb    w0, [x19], #1
    cbz     w0, Ldsdone
    LEA     x1, _charset
    mov     w2, #0
1:  ldrb    w3, [x1, x2]
    cbz     w3, 2f
    cmp     w3, w0
    b.eq    3f
    add     w2, w2, #1
    b       1b
2:  mov     w2, #0
3:  LEA     x4, _font
    add     x23, x4, x2, lsl #3
    mov     w24, #0
4:  ldrb    w25, [x23, x24]
    mov     w26, #0
5:  mov     w0, #7
    sub     w0, w0, w26
    lsr     w1, w25, w0
    tbz     w1, #0, 8f
    ldr     w3, [sp, #96]
    mul     w27, w26, w3
    add     w27, w20, w27
    mul     w28, w24, w3
    add     w28, w21, w28
    str     wzr, [sp, #100]
6:  str     wzr, [sp, #104]
7:  ldr     w0, [sp, #104]
    add     w0, w27, w0
    ldr     w1, [sp, #100]
    add     w1, w28, w1
    mov     w2, w22
    bl      _putpix
    ldr     w0, [sp, #104]
    add     w0, w0, #1
    str     w0, [sp, #104]
    ldr     w3, [sp, #96]
    cmp     w0, w3
    b.lo    7b
    ldr     w0, [sp, #100]
    add     w0, w0, #1
    str     w0, [sp, #100]
    ldr     w3, [sp, #96]
    cmp     w0, w3
    b.lo    6b
8:  add     w26, w26, #1
    cmp     w26, #8
    b.lo    5b
    add     w24, w24, #1
    cmp     w24, #8
    b.lo    4b
    ldr     w3, [sp, #96]
    lsl     w0, w3, #3
    add     w20, w20, w0
    b       Lds
Ldsdone:
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #112
    ret

.p2align 2
_emitrgb:
    ubfx    w1, w0, #16, #8
    ldr     w2, [x26, x1, lsl #2]
    and     w3, w2, #0xff
    lsr     w2, w2, #8
    str     w2, [x19]
    add     x19, x19, x3
    mov     w2, #59
    strb    w2, [x19], #1
    ubfx    w1, w0, #8, #8
    ldr     w2, [x26, x1, lsl #2]
    and     w3, w2, #0xff
    lsr     w2, w2, #8
    str     w2, [x19]
    add     x19, x19, x3
    mov     w2, #59
    strb    w2, [x19], #1
    and     w1, w0, #0xff
    ldr     w2, [x26, x1, lsl #2]
    and     w3, w2, #0xff
    lsr     w2, w2, #8
    str     w2, [x19]
    add     x19, x19, x3
    ret

.p2align 2
_emit256:
    ubfx    w1, w0, #16, #8
    ubfx    w2, w0, #8, #8
    and     w3, w0, #0xff
    add     w4, w1, w2
    add     w4, w4, w3
    mov     w5, #24
    cmp     w1, w2
    ccmp    w2, w3, #0, eq
    b.ne    1f
    mov     w5, #3
    udiv    w4, w4, w5
    cmp     w4, #8
    b.hs    5f
    mov     w0, #16
    b       9f
5:  cmp     w4, #248
    b.lo    6f
    mov     w0, #231
    b       9f
6:  sub     w4, w4, #8
    mov     w5, #10
    udiv    w4, w4, w5
    add     w0, w4, #232
    b       9f
1:  mov     w5, #6
    mul     w1, w1, w5
    lsr     w1, w1, #8
    mul     w2, w2, w5
    lsr     w2, w2, #8
    mul     w3, w3, w5
    lsr     w3, w3, #8
    mov     w5, #36
    mul     w1, w1, w5
    mov     w5, #6
    madd    w2, w2, w5, w1
    add     w0, w2, w3
    add     w0, w0, #16
9:  ldr     w2, [x26, x0, lsl #2]
    and     w3, w2, #0xff
    lsr     w2, w2, #8
    str     w2, [x19]
    add     x19, x19, x3
    ret

.p2align 2
_encode:
    stp     x29, x30, [sp, #-160]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    stp     x27, x28, [sp, #80]
    LEA     x19, _outbuf
    LEA     x26, _dec3
    LEA     x0, _ssync
    ldr     x1, [x0]
    str     x1, [x19]
    add     x19, x19, #8
    LEA     x0, _rows
    ldr     w21, [x0]
    LEA     x0, _fbw
    ldr     w20, [x0]
    LEA     x0, _col256
    ldr     w0, [x0]
    str     w0, [sp, #96]
    mov     w27, #-1
    mov     w28, #-1
    mov     w22, #0
Leny:
    LEA     x0, _fb
    lsl     w1, w22, #1
    mul     w2, w1, w20
    add     x23, x0, x2, lsl #2
    add     x24, x23, x20, lsl #2
    LEA     x0, _prev
    mul     w1, w22, w20
    add     x0, x0, x1, lsl #3
    str     x0, [sp, #128]
    mov     w1, #1
    str     w1, [sp, #100]
    mov     w25, #0
Lenx:
    ldr     w0, [x23, x25, lsl #2]
    ldr     w1, [x24, x25, lsl #2]
    and     w0, w0, #0xf8f8f8f8
    and     w1, w1, #0xf8f8f8f8
    fmov    s0, w0
    fmov    s1, w1
    uabd    v2.8b, v0.8b, v1.8b
    umaxv   b3, v2.8b
    fmov    w2, s3
    LEA     x3, _vmerge
    ldr     w3, [x3]
    cmp     w2, w3
    csel    w1, w0, w1, lo
    orr     x2, x1, x0, lsl #32
    ldr     x3, [sp, #128]
    ldr     x4, [x3, x25, lsl #3]
    cmp     x2, x4
    b.eq    Lenskip
    str     x2, [x3, x25, lsl #3]
    ldr     w3, [sp, #100]
    cbz     w3, Lencol
    str     wzr, [sp, #100]
    mov     w3, #27
    strb    w3, [x19], #1
    mov     w3, #91
    strb    w3, [x19], #1
    add     w3, w22, #1
    ldr     w4, [x26, x3, lsl #2]
    and     w5, w4, #0xff
    lsr     w4, w4, #8
    str     w4, [x19]
    add     x19, x19, x5
    mov     w3, #59
    strb    w3, [x19], #1
    add     w3, w25, #1
    ldr     w4, [x26, x3, lsl #2]
    and     w5, w4, #0xff
    lsr     w4, w4, #8
    str     w4, [x19]
    add     x19, x19, x5
    mov     w3, #72
    strb    w3, [x19], #1
Lencol:
    cmp     w0, w1
    b.ne    Lenpair
    cmp     w1, w28
    b.eq    Lenspace
    mov     w28, w1
    mov     w0, w1
    mov     w2, #1
    str     x1, [sp, #112]
    bl      _emitsgr
    ldr     x1, [sp, #112]
Lenspace:
    mov     w2, #32
    strb    w2, [x19], #1
    b       Lenadv
Lenpair:
    cmp     w0, w27
    b.eq    Lenbgonly
    cmp     w1, w28
    b.eq    Lenfgonly
    mov     w27, w0
    mov     w28, w1
    mov     w2, #2
    str     x1, [sp, #112]
    bl      _emitsgr
    ldr     x0, [sp, #112]
    bl      _emitrgbtail
    b       Lenglyph
Lenfgonly:
    mov     w27, w0
    mov     w2, #0
    bl      _emitsgr
    b       Lenglyph
Lenbgonly:
    mov     w28, w1
    mov     w0, w1
    mov     w2, #1
    bl      _emitsgr
Lenglyph:
    LEA     x2, _sblk
    ldr     w3, [x2]
    str     w3, [x19]
    add     x19, x19, #3
    b       Lenadv
Lenskip:
    mov     w3, #1
    str     w3, [sp, #100]
Lenadv:
    add     w25, w25, #1
    cmp     w25, w20
    b.lo    Lenx
    add     w22, w22, #1
    cmp     w22, w21
    b.lo    Leny
    LEA     x2, _srst
    ldr     x3, [x2]
    str     x3, [x19]
    add     x19, x19, #4
    LEA     x2, _sunsync
    ldr     x3, [x2]
    str     x3, [x19]
    add     x19, x19, #8
    LEA     x0, _outp
    str     x19, [x0]
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x25, x26, [sp, #64]
    ldp     x27, x28, [sp, #80]
    ldp     x29, x30, [sp], #160
    ret

.p2align 2
_emitsgr:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    str     x0, [sp, #16]
    mov     w3, #27
    strb    w3, [x19], #1
    mov     w3, #91
    strb    w3, [x19], #1
    LEA     x3, _sgrtab
    LEA     x4, _sgrtab5
    LEA     x5, _col256
    ldr     w5, [x5]
    cmp     w5, #0
    csel    x3, x3, x4, eq
    add     x3, x3, x2, lsl #3
    ldr     x4, [x3]
    str     x4, [x19]
    add     x19, x19, #5
    ldr     x0, [sp, #16]
    str     x2, [sp, #24]
    LEA     x3, _col256
    ldr     w3, [x3]
    cbnz    w3, 1f
    bl      _emitrgb
    b       2f
1:  bl      _emit256
2:  ldr     x2, [sp, #24]
    cmp     w2, #2
    b.eq    3f
    mov     w3, #109
    strb    w3, [x19], #1
3:  ldp     x29, x30, [sp], #32
    ret

.p2align 2
_emitrgbtail:
    stp     x29, x30, [sp, #-32]!
    mov     x29, sp
    LEA     x3, _col256
    ldr     w3, [x3]
    cbnz    w3, 1f
    LEA     x3, _sbg
    ldr     x4, [x3]
    str     x4, [x19]
    add     x19, x19, #6
    bl      _emitrgb
    b       2f
1:  LEA     x3, _sbg5
    ldr     x4, [x3]
    str     x4, [x19]
    add     x19, x19, #6
    bl      _emit256
2:  mov     w3, #109
    strb    w3, [x19], #1
    ldp     x29, x30, [sp], #32
    ret

.p2align 2
_prev_reset:
    LEA     x0, _prev
    IMM32   w1, MAXW*MAXROWS*8
    movi    v0.16b, #255
1:  stp     q0, q0, [x0], #32
    subs    w1, w1, #32
    b.hi    1b
    ret

.p2align 2
_bench:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    bl      _prev_reset
    LEA     x0, _benchn
    ldr     w19, [x0]
    mov     w20, #0
    mov     x22, #0
    bl      _now_ms
    LEA     x1, _t0
    str     x0, [x1]
1:  mov     w0, #16
    mul     w0, w20, w0
    bl      _render_frame
    bl      _encode
    LEA     x0, _outp
    ldr     x0, [x0]
    LEA     x1, _outbuf
    sub     x0, x0, x1
    add     x22, x22, x0
    add     w20, w20, #1
    cmp     w20, w19
    b.lo    1b
    bl      _now_ms
    LEA     x1, _t0
    ldr     x1, [x1]
    sub     x23, x0, x1
    mov     w0, w19
    bl      _putu32
    LEA     x0, _bsp
    mov     w1, #1
    bl      _write1
    mov     w0, w23
    bl      _putu32
    LEA     x0, _bsp
    mov     w1, #1
    bl      _write1
    udiv    x0, x22, x19
    bl      _putu32
    LEA     x0, _bnl
    mov     w1, #1
    bl      _write1
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x29, x30, [sp], #64
    ret

.p2align 2
_putu32:
    stp     x29, x30, [sp, #-48]!
    mov     x29, sp
    add     x1, sp, #40
    mov     w2, #10
1:  udiv    w3, w0, w2
    msub    w4, w3, w2, w0
    add     w4, w4, #48
    sub     x1, x1, #1
    strb    w4, [x1]
    mov     w0, w3
    cbnz    w0, 1b
    add     x2, sp, #40
    sub     w2, w2, w1
    mov     x0, x1
    add     x2, sp, #40
    sub     x2, x2, x1
    mov     x1, x0
    mov     x0, #1
    mov     x16, #SYS_write
    svc     #0x80
    ldp     x29, x30, [sp], #48
    ret

.p2align 2
_write_bmp:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    LEA     x0, _fbw
    ldr     w19, [x0]
    LEA     x0, _fbh
    ldr     w20, [x0]
    mov     w0, #3
    mul     w21, w19, w0
    add     w0, w21, #3
    and     w21, w0, #-4
    mul     w22, w21, w20
    LEA     x23, _outbuf
    mov     x24, x23
    mov     w0, #0x4d42
    strh    w0, [x24], #2
    add     w0, w22, #54
    str     w0, [x24], #4
    str     wzr, [x24], #4
    mov     w0, #54
    str     w0, [x24], #4
    mov     w0, #40
    str     w0, [x24], #4
    str     w19, [x24], #4
    str     w20, [x24], #4
    mov     w0, #1
    strh    w0, [x24], #2
    mov     w0, #24
    strh    w0, [x24], #2
    str     wzr, [x24], #4
    str     w22, [x24], #4
    mov     w0, #2835
    str     w0, [x24], #4
    str     w0, [x24], #4
    str     wzr, [x24], #4
    str     wzr, [x24], #4
    sub     w0, w20, #1
1:  cmp     w0, #0
    b.lt    2f
    mul     w1, w0, w19
    LEA     x2, _fb
    add     x2, x2, x1, lsl #2
    mov     w3, #0
    mov     x4, x24
3:  ldr     w5, [x2, x3, lsl #2]
    strb    w5, [x4], #1
    lsr     w6, w5, #8
    strb    w6, [x4], #1
    lsr     w6, w5, #16
    strb    w6, [x4], #1
    add     w3, w3, #1
    cmp     w3, w19
    b.lo    3b
    add     x24, x24, x21
    sub     w0, w0, #1
    b       1b
2:  LEA     x1, _outbuf
    sub     x2, x24, x1
    mov     x0, #1
    mov     x16, #SYS_write
    svc     #0x80
    ldp     x19, x20, [sp, #16]
    ldp     x21, x22, [sp, #32]
    ldp     x23, x24, [sp, #48]
    ldp     x29, x30, [sp], #64
    ret

.section __DATA,__data
.p2align 3
_fbw:       .long 100
_fbh:       .long 60
_rows:      .long 30
_cx:        .long 3276800
_cy:        .long 1966080
_focal:     .long 75
_zdist:     .long 180000
_rng:       .long 0x13579bdf
_col256:    .long 0
_shotms:    .long -1
_tskew:     .long 0
_istty:     .long 1
_tms:       .long 0
_palsel:    .long 0
_benchn:    .long 0
_forcew:    .long 0
_forceh:    .long 0
_showfps:   .long 0
_vmerge:    .long 28
_ctol:      .long 20
_fpsval:    .long 0
_fpsacc:    .long 0
.p2align 3
_fpst0:     .quad 0
_fpsbuf:    .space 16
.p2align 3
_t0:        .quad 0
_outp:      .quad 0
_tvsleep:   .quad 0
            .quad 0
_wsz:       .quad 0
_sigact:    .quad 0
            .quad 0
            .quad 0
.p2align 3
_sfg:       .asciz "38;2;"
_sbg:       .asciz ";48;2;"
_sfg5:      .asciz "38;5;"
_sbg5:      .asciz ";48;5;"
_sblk:      .asciz "\342\226\200"
_srst:      .asciz "\033[0m"
.p2align 3
_ssync:     .asciz "\033[?2026h"
.p2align 3
_sunsync:   .asciz "\033[?2026l"
.p2align 3
_sgrtab:    .ascii "38;2;"
            .space 3
            .ascii "48;2;"
            .space 3
            .ascii "38;2;"
            .space 3
_sgrtab5:   .ascii "38;5;"
            .space 3
            .ascii "48;5;"
            .space 3
            .ascii "38;5;"
            .space 3

.p2align 2
_palstops:
    .byte 0,   0,   0,   0
    .byte 90,  36,  0,   70
    .byte 168, 168, 30,  200
    .byte 220, 255, 130, 255
    .byte 255, 255, 255, 255
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0

    .byte 0,   0,   0,   16
    .byte 80,  0,   50,  120
    .byte 160, 20,  190, 210
    .byte 220, 160, 255, 255
    .byte 255, 255, 255, 255
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0

    .byte 0,   10,  0,   30
    .byte 64,  150, 20,  90
    .byte 128, 255, 90,  40
    .byte 192, 255, 220, 90
    .byte 255, 255, 255, 230
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0

    .byte 0,   4,   0,   14
    .byte 70,  20,  60,  120
    .byte 150, 90,  200, 230
    .byte 210, 200, 250, 255
    .byte 255, 255, 255, 255
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0
    .byte 0,0,0,0

.p2align 2
_nztab:
    .byte 0,16,23,28,32,36,39,42,45,48,50,53,55,57,60,62,64,66,68,69,71,73,75,76,78,80,81,83,84,86,87,89
    .byte 90,92,93,94,96,97,98,100,101,102,103,105,106,107,108,109,110,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126
    .byte 128,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,143,144,145,146,147,148,149,150,150,151,152,153,154,155,155
    .byte 156,157,158,159,159,160,161,162,163,163,164,165,166,166,167,168,169,169,170,171,172,172,173,174,175,175,176,177,177,178,179,180
    .byte 180,181,182,182,183,184,184,185,186,187,187,188,189,189,190,191,191,192,193,193,194,195,195,196,196,197,198,198,199,200,200,201
    .byte 202,202,203,203,204,205,205,206,207,207,208,208,209,210,210,211,211,212,213,213,214,214,215,216,216,217,217,218,219,219,220,220
    .byte 221,221,222,223,223,224,224,225,225,226,227,227,228,228,229,229,230,230,231,232,232,233,233,234,234,235,235,236,236,237,237,238
    .byte 239,239,240,240,241,241,242,242,243,243,244,244,245,245,246,246,247,247,248,248,249,249,250,250,251,251,252,252,253,254,254,255
    .byte 255

.p2align 2
_charset:
    .asciz " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!-:/*+<>()[]#@='?"

.p2align 2
_title:
    .asciz "RING0"

.p2align 2
_swshot:    .asciz "-shot"
_swtime:    .asciz "-time"
_sw256:     .asciz "-256"
_swhelp:    .asciz "-h"
_swbench:   .asciz "-bench"
_swsize:    .asciz "-size"
_swfps:     .asciz "-fps"
_bsp:       .asciz " "
_bnl:       .asciz "\n"

_s_enter:   .ascii "\033[?1049h\033[?25l\033[2J"
.set _s_enter_len, 18
_s_leave:   .ascii "\033[0m\033[?25h\033[?1049l\n"
.set _s_leave_len, 19
_usage:
    .ascii "ring0demo - 3d demoscene in aarch64 assembly\n"
    .ascii "  -fps          show frame rate\n"
    .ascii "  -256          256 colour fallback\n"
    .ascii "  -size W H     force grid size in cells\n"
    .ascii "  -time MS      start at MS into the timeline\n"
    .ascii "  -shot MS      write BMP of frame at MS to stdout\n"
    .ascii "  -bench N      render N frames headless\n"
.set _usage_len, 292

.p2align 3
_font:
    .byte 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
    .byte 0x3c,0x66,0xc3,0xc3,0xff,0xc3,0xc3,0x00
    .byte 0xfc,0xc6,0xc6,0xfc,0xc6,0xc6,0xfc,0x00
    .byte 0x3e,0x63,0xc0,0xc0,0xc0,0x63,0x3e,0x00
    .byte 0xf8,0xcc,0xc6,0xc6,0xc6,0xcc,0xf8,0x00
    .byte 0xff,0xc0,0xc0,0xfc,0xc0,0xc0,0xff,0x00
    .byte 0xff,0xc0,0xc0,0xfc,0xc0,0xc0,0xc0,0x00
    .byte 0x3e,0x63,0xc0,0xcf,0xc3,0x67,0x3d,0x00
    .byte 0xc3,0xc3,0xc3,0xff,0xc3,0xc3,0xc3,0x00
    .byte 0x3c,0x18,0x18,0x18,0x18,0x18,0x3c,0x00
    .byte 0x0f,0x03,0x03,0x03,0xc3,0xc3,0x7c,0x00
    .byte 0xc6,0xcc,0xd8,0xf0,0xd8,0xcc,0xc6,0x00
    .byte 0xc0,0xc0,0xc0,0xc0,0xc0,0xc0,0xff,0x00
    .byte 0xc3,0xe7,0xff,0xdb,0xc3,0xc3,0xc3,0x00
    .byte 0xc3,0xe3,0xf3,0xdb,0xcf,0xc7,0xc3,0x00
    .byte 0x3c,0x66,0xc3,0xc3,0xc3,0x66,0x3c,0x00
    .byte 0xfc,0xc6,0xc6,0xfc,0xc0,0xc0,0xc0,0x00
    .byte 0x3c,0x66,0xc3,0xc3,0xdb,0x6e,0x3d,0x00
    .byte 0xfc,0xc6,0xc6,0xfc,0xd8,0xcc,0xc6,0x00
    .byte 0x7c,0xc6,0xc0,0x7c,0x03,0x63,0x3e,0x00
    .byte 0xff,0x18,0x18,0x18,0x18,0x18,0x18,0x00
    .byte 0xc3,0xc3,0xc3,0xc3,0xc3,0xc3,0x7e,0x00
    .byte 0xc3,0xc3,0xc3,0xc3,0x66,0x3c,0x18,0x00
    .byte 0xc3,0xc3,0xc3,0xdb,0xff,0xe7,0xc3,0x00
    .byte 0xc3,0x66,0x3c,0x18,0x3c,0x66,0xc3,0x00
    .byte 0xc3,0xc3,0x66,0x3c,0x18,0x18,0x18,0x00
    .byte 0xff,0x03,0x06,0x3c,0x30,0x60,0xff,0x00
    .byte 0x3c,0x66,0xc7,0xdb,0xe3,0x66,0x3c,0x00
    .byte 0x18,0x38,0x78,0x18,0x18,0x18,0x3c,0x00
    .byte 0x7e,0xc3,0x03,0x0e,0x38,0x60,0xff,0x00
    .byte 0x7e,0xc3,0x03,0x1e,0x03,0xc3,0x7e,0x00
    .byte 0x0e,0x1e,0x36,0x66,0xff,0x06,0x06,0x00
    .byte 0xff,0xc0,0xfc,0x03,0x03,0xc3,0x7e,0x00
    .byte 0x3c,0x66,0xc0,0xfc,0xc3,0xc3,0x7e,0x00
    .byte 0xff,0x03,0x06,0x0c,0x18,0x30,0x30,0x00
    .byte 0x7e,0xc3,0xc3,0x7e,0xc3,0xc3,0x7e,0x00
    .byte 0x7e,0xc3,0xc3,0x7f,0x03,0x66,0x3c,0x00
    .byte 0x00,0x00,0x00,0x00,0x00,0x38,0x38,0x00
    .byte 0x00,0x00,0x00,0x00,0x38,0x38,0x18,0x30
    .byte 0x18,0x18,0x18,0x18,0x18,0x00,0x18,0x00
    .byte 0x00,0x00,0x00,0xff,0x00,0x00,0x00,0x00
    .byte 0x00,0x38,0x38,0x00,0x38,0x38,0x00,0x00
    .byte 0x03,0x06,0x0c,0x18,0x30,0x60,0xc0,0x00
    .byte 0x00,0xdb,0x7e,0x3c,0x7e,0xdb,0x00,0x00
    .byte 0x00,0x18,0x18,0xff,0x18,0x18,0x00,0x00
    .byte 0x0e,0x18,0x30,0x60,0x30,0x18,0x0e,0x00
    .byte 0x70,0x18,0x0c,0x06,0x0c,0x18,0x70,0x00
    .byte 0x0c,0x18,0x30,0x30,0x30,0x18,0x0c,0x00
    .byte 0x30,0x18,0x0c,0x0c,0x0c,0x18,0x30,0x00
    .byte 0x3c,0x30,0x30,0x30,0x30,0x30,0x3c,0x00
    .byte 0x3c,0x0c,0x0c,0x0c,0x0c,0x0c,0x3c,0x00
    .byte 0x66,0x66,0xff,0x66,0xff,0x66,0x66,0x00
    .byte 0x3c,0x66,0xde,0xde,0xc0,0x63,0x3e,0x00
    .byte 0x00,0x00,0xff,0x00,0xff,0x00,0x00,0x00
    .byte 0x18,0x18,0x18,0x00,0x00,0x00,0x00,0x00
    .byte 0x7e,0xc3,0x03,0x1c,0x18,0x00,0x18,0x00

.zerofill __DATA,__bss,_fb,FBSZ,4
.zerofill __DATA,__bss,_zbuf,ZBSZ,4
.zerofill __DATA,__bss,_outbuf,OUTSZ,4
.zerofill __DATA,__bss,_sintab,4096,4
.zerofill __DATA,__bss,_dec3,2048,4
.zerofill __DATA,__bss,_pal,8192,4
.zerofill __DATA,__bss,_mvert,NVERT*12,4
.zerofill __DATA,__bss,_mnorm,NVERT*12,4
.zerofill __DATA,__bss,_morph,NVERT*12,4
.zerofill __DATA,__bss,_mtri,NTRI*8,4
.zerofill __DATA,__bss,_svx,NVERT*4,4
.zerofill __DATA,__bss,_svy,NVERT*4,4
.zerofill __DATA,__bss,_svz,NVERT*4,4
.zerofill __DATA,__bss,_svi,NVERT*4,4
.zerofill __DATA,__bss,_mat,64,4
.zerofill __DATA,__bss,_star,NSTAR*12,4
.zerofill __DATA,__bss,_tdist,MAXW*MAXH,4
.zerofill __DATA,__bss,_tang,MAXW*MAXH,4
.zerofill __DATA,__bss,_tshade,MAXW*MAXH,4
.zerofill __DATA,__bss,_tex,TEXW*TEXW,4
.zerofill __DATA,__bss,_prev,MAXW*MAXROWS*8,4
