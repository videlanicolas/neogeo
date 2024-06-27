; Functions used to clear the screen, both for the Fix layer and sprites.

; Function used to clear the sprites from the screen, taken and slightly modified from:
; https://wiki.neogeodev.org/index.php?title=Hello_world_tutorial#Cleaning_up_the_display
LSP_1ST:
    movem.l     d0,-(sp)                ; Save the state of the registers to the stack.
    move.w      #SCB2,REG_VRAMADDR      ; Height attributes are in VRAM at Sprite Control Bank 3.
    clr.w       d0                      ; Clear D0.
    move.w      #1,REG_VRAMMOD          ; Set the VRAM address auto-increment value to 1, so we move 1 byte with each write.
    move.l      #512-1,d0               ; Clear all 512 sprites.
    nop                                 ; Safety pause.

; Clear all the sprites, we do this by writing $0000 to all the sprite bank.
.loop:
    move.w      #0,REG_VRAMRW           ; Write to VRAM
    move.b	    #0,REG_DIPSW            ; Kick the watchdog.
    dbra        d0,.loop                ; Are we done ? No: jump back to .clearspr

    movem.l     (sp)+,d0                ; Restore registers from the stack.
    rts                                 ; Return from subroutine.

; Clear all the tiles in the fix layer.
; We do this by loading $FF (should be transparent).
FIX_CLEAR:
    movem.l     d0,-(sp)                ; Save the state of the registers to the stack.
    move.l      #(40*32)-1,d0           ; Move the amout of tiles we have to clear, this number represents the whole map.
    move.w      #FIXMAP,REG_VRAMADDR    ; Start at the beginning of the FIXMAP and write the whole map.
    nop                                 ; Safety pause.

.loop:
    move.w      #$00ff,REG_VRAMRW       ; Write to VRAM.
    move.b	    #0,REG_DIPSW            ; Kick the watchdog.
    dbra        d0,.loop                ; Are we done ? No: jump back to .clearfix
    movem.l     (sp)+,d0                ; Pop value from stack.
    rts                                 ; Return from subroutine.
