    .section .text
    .globl  _start
_start:
    # Compute 6 + 7
    li      t0, 6
    li      t1, 7
    add     t2, t0, t1

    # Store result at label “result”
    la      t3, result
    sw      t2, 0(t3)

    # Endless loop
1:  j       1b

    .section .data
result:
    .word   0x1234
    .word   0x6789
