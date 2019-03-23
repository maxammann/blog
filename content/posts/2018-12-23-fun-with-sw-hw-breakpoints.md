---
layout: post
title: "CTF: Fun with Hardware and Software breakpoints in GDB"
date: 2018-12-23
---

I did the orw challange on [pwnable.tw](https://pwnable.tw/) yesterday. It is very streight forward.
You just have to send some x86 shellcode to stdin and the orw binary will execute it.

But I spend a few hours with getting this to work with gdb as the instructions in gdb were quite
weird.

```nasm
0x08048571     push 0xc8                   ; 200 ; size_t nbyte
0x08048576     push obj.shellcode          ; 0x804a060 ; void *buf
0x0804857b     push 0                      ; int fildes
0x0804857d     call sym.imp.read           ; ssize_t read(int fildes, void *buf, size_t nbyte)
0x08048582     add esp, 0x10
0x08048585     mov eax, obj.shellcode      ; 0x804a060
0x0804858a     call eax
```

So it just writes the shellcode to `0x804a060` and jumps to the address using `call`.
I'm using pwntools to write my exploits as a lot of other people are doing.
The important part is the gdb script:
```python
#!python2
from pwn import *

context.update(arch='i386', endian='little', os='linux')
p = process("./challange/orw")
elf = ELF("./challange/orw")
gdb.attach(p, '''
        # 1. breakpoint
        break *0x0804858a
        # 2. breakpoint
        break *0x804a060 
        c
        x /5i 0x804a060
        x /5x 0x804a060
''')

shellcode = 'AAA' # Example 4 byte non-workable shellcode to see the effect of software breakpoints

p.recvuntil("Give my your shellcode:")
p.send(asm(shellcode))

p.interactive()


```

Alright so we are setting 2 breakpoints when the programm starts. These are probably software
breakpoints as [internal documents](https://sourceware.org/gdb/wiki/Internals/Breakpoint%20Handling) of GDB state. These write an `INT` instruction to the specified instruction:

> "Since it literally overwrites the program being tested, the program area must be writable, so this technique won’t work on programs in ROM. It can also distort the behavior of programs that examine themselves, although such a situation would be highly unusual."

So yes it can distort the behavior and in this example it did! So lets see what we can find at the
instruction `0x804a060` when reaching the second first or second breakpoint:

```hex
0x804a060:	0x41414100
```

As you can see it seems like only 3 bytes got copied. The first byte is `0x00`.
This is because gdb wrote `0x90` (INT) to the address when the breakpoint was set.
After reaching the 1. breakpoing it wrote `0x90` again to make sure that the programm will stop at
the 2. breakpoint.
After reaching the 2. breakpoint it restored the byte to `0x00` because when the breakpoints were set it actually was.

So this is why gdb fucks our shellcode up! It restored the value where the `INT` was to the wrong
value!


You may notice that the following script will not corrupt the instructions:
```python
gdb.attach(p, '''
        break *0x804a060 
        c
        x /5i 0x804a060
        x /5x 0x804a060
''')
```

This works because the code gets rewritten between setting the breakpoints and reaching it. So the
breakpoint here will not work but also cause no problem.

# Solution I
The solution is to set the breakpoint at `0x804a060` after the shellcode was copied!
```python
gdb.attach(p, '''
        break *0x0804858a
        c
        break *0x804a060 
        x /5i 0x804a060
        x /5x 0x804a060
''')
```

# Solution II 
The other solution is to use hardware breakpoints which do not modify the code the CPU will execute!
Note that there are only a limited amount of them!

# Reason of confusion
The reson why I was so confused is that gdb never showed my the `INT` instructions. So I did not
think that gdb would restore values to outdated values!
Even if you look at the assembler code in gdb it will not show it you
[(Debugger flow control: Hardware breakpoints vs software breakpoints)](http://www.nynaeve.net/?p=80):

> "Now, you might be tempted to say that this isn’t really how software breakpoints work, if you have ever tried to disassemble or dump the raw opcode bytes of anything that you have set a breakpoint on, because if you do that, you’ll not see an int 3 anywhere where you set a breakpoint. This is actually because the debugger tells a lie to you about the contents of memory where software breakpoints are involved; any access to that memory (through the debugger) behaves as if the original opcode byte that the debugger saved away was still there."

# Conclusion

Never set software breakpoints at addresses you are writing executable code to!

