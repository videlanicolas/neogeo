    ; https://wiki.neogeodev.org/index.php?title=68k_vector_table
    
    ; m68k Vector table.
    ; It's 64 long word vectors at the beginning of the ROM file.
    ; Upon reset, this vector table is read.
    ; These vectors will change PC to whatever value is found here.
RAM_START               equ $10f300
PC_START                equ $C00402

    org $0
    dc.l                RAM_START               ; Initial value for Stack Pointer.
    dc.l                PC_START                ; Initial value for PC.
    dc.l                $00C00408               ; Bus error.
    dc.l                $00C0040E               ; Address error.
    dc.l                $00C0040E               ; Illegal instruction.
    dc.l                $0000034C               ; Division by zero.
    dc.l                $0000034E               ; CHK out of bounds.
    dc.l                $0000034E               ; TRAPV.
    dc.l                $00C0041A               ; Privilege violation. This never happens because we always use supervisor mode.
    dc.l                $00C00420               ; This will get executed after each instruction in TRACE mode. We don't need it.
    
    org $60
    dc.l                $00C00432               ; No ack from Hardware.
    org $64
    dc.l                VBLANK                  ; VBLANK.
    dc.l                TIMER_INTERRUPT         ; Timer interrupt.
    dc.l                $00C00426               ; Cold boot.
    ; There are more entries in the table, but we don't need those.
    ; https://wiki.neogeodev.org/index.php?title=68k_program_header
    org $100
    dc.b                "NeoGeo",$00              ; BIOS name.
    org $107
    dc.b                $00                     ; Cartridge system.
    dc.w                $1234                   ; NGH number, doesn't matter.