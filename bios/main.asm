    include "regdefs.asm"
    include "header.asm"

    ; The M68k will mirror these bytes into C00402.
    ; When the BIOS is ready to load the game, it calls REG_SWPROM to switch these locations for the ones
    ; defined by the cartridge.
    org $402
    bra         RESET                   ; Jumps to PC_START will arrive here. We need 'bra' instead of 'jmp' here.
    org $444
    bra         SYSTEM_RETURN           ; The game will jump here when done on each subroutine.
    org $44a
    bra         SYSTEM_IO               ; This jump "should" be made on VBLANK interrupts by the game.
    org $4C2
    bra         FIX_CLEAR               ; This subroutine clears the fix layer.
    org $4C8
    bra         LSP_1ST                 ; This subroutine clears all sprites.

    ; Here's the actual code from the BIOS.
    ; The BIOS will initialize the hardware and then jump to the USER subroutine.
    ; The details of how that works are here: https://wiki.neogeodev.org/index.php?title=USER_subroutine
    ; Essentially the BIOS first calls "init" on the game and then expect it to return control by jumping to SYSTEM_RETURN,
    ; during "init" the game initalizes software DIPs, RAM and makes sure everything needed is available to start the game.
    ; Afterwards the BIOS will continue jumping to USER and comunicate back and forth through BIOS_USER_REQUEST and BIOS_USER_MODE.
    ; We can't rely on the stack here, so we have to do hard jumps back and forth to/from the game.
RESET:
    move.w      #$2700,sr               ; Supervisor mode, disable all interrupts.
    move.b      #0,REG_DIPSW            ; Kick watchdog.
    move.w      #7,REG_IRQACK           ; Acknowledge all interrupts.
    move.w      #0,REG_LSPCMODE         ; Disable timer.
    move.b      #1,BIOS_MVS_FLAG        ; We're MVS, so set that on RAM so the game knows about it as well.
    move.b      #0,BIOS_CREDIT_DEC1     ; No credits for P1.
    lea         RAM_START,sp            ; Load stack pointer at the beginning.
    move.b      #0,BIOS_USER_REQUEST    ; Tell the game to do an init.
    jmp         USER                    ; Jump to the game, the game should return through SYSTEM_RETURN

    ; Jumped here from the game, BIOS_USER_MODE contains a value that represent which stage the game just performed.
    ; The BIOS should read this state and make a decision to indicate the game which other state should it load next.
    ; The game "should" have a jump table to decide where it should jump next, but that's an implementation detail.
SYSTEM_RETURN:
    move.b      #0,REG_DIPSW            ; Kick watchdog.
    move.b      BIOS_USER_MODE,d0       ; Read the value from user mode, to know what they were doing.
    cmpi.b      #1,d0
    bne         .demo                   ; If the game was doing Init (0) or Game (2), then ask to do Title/Demo now.
    
    ; If we're here then that means the game was doing Demo or Game.
    ; We need to tell the game to stat again.
    move.b      #0,BIOS_USER_REQUEST    ; Ask for Init.
    jmp         USER

    ; Here we're asking the game to load the Demo state, which "should" run an eyecatcher of the game so people can be lured to the
    ; arcade machine and drop coins. Once a coin is dropped we're still here, but a different subroutine will tell the game when a coin was dropped.
    ; Each game handles coin drops differently.
.demo:
    move.b      #$80,BIOS_SYSTEM_MODE   ; Tell the game that it can use VBLANK.
    move.b      #2,BIOS_USER_REQUEST    ; Ask the game to do demo.
    move.b      #$1,REG_SWPROM          ; Switch the first $80 bytes (vector table) with the cart's P ROM vector table.
    move.b      #$1,REG_CRTFIX          ; Switch with the cart's S ROM and M ROM (fix map and sound driver).
    move.b      #0,BIOS_STATCURNT       ; Clear select/start for all players.
    move.b      #0,BIOS_STATCHANGE      ; Clear select/start for all players.
    move.b      #0,BIOS_STATCURNT_RAW   ; Clear select/start for all players.
    move.b      #0,BIOS_STATCHANGE_RAW  ; Clear select/start for all players.
    move.w      #$2000,sr               ; Clear all flags and enable all interrupts. From this point on our BIOS code might get interrupted by some other subroutine.
    move.w      #7,REG_IRQACK           ; Acknowledge all interrupts.
    jmp         USER                    ; Blind jump to USER subroutine.

    ; Called by the game to update the input from the user.
    ; We have to be careful with the stack here, since it has been initalized.
    ; This code "may" be interrupted by some other code, like TIMER_INTERRUPT.
    ; We are called with "jsr" here, not jumped. So we should return with "rst".
SYSTEM_IO:
    movem.l     d0/d1,-(sp)             ; Save the state of the registers we're going to use.
    
    ; Check if P1 placed a coin.
    move.b      REG_STATUS_A,d0         ; Get the coin status.
    btst        #0,d0                   ; If bit 0 is cleared then a coin was inserted.
    beq         COIN_IN                 ; Jump to COIN_IN if a coin was inserted.
    
    ; Check if the game is running. If so we don't care to start a new game until this one finishes.
    move.b      BIOS_USER_MODE,d0       ; Get the value of the user mode.
    cmpi.b      #2,d0                   ; 2 is when the user is in Game mode.
    beq         .getInput               ; Skip to the input if the game is in Game mode.

    ; Check if P1 pressed start.
    move.b      REG_STATUS_B,d0         ; Get the P1 start button.
    btst        #0,d0                   ; Check bit 0.
    bne         .getInput               ; If Start was not pressed, skip.
       
    ; Check if the user has enough credits.
    move.b      BIOS_CREDIT_DEC1,d0     ; Load the amount of credits for P1. c005b0
    tst.b       d0                      ; Test if D0 is empty.
    beq         .getInput               ; Skip if there are no credits.
    ; At this point, the user pressed "start" and has enough credits.
    ; Call the Player Subroutine.
    move.b      #1,BIOS_START_FLAG      ; Indicate that P1 pushed start.
    move.w      #$2000,sr               ; Enable all interrupts. c005c4
    jmp         PLAYER_START            ; Blind jump to start the game. They should clear RAM and reset the stack.
.getInput:
    ; Update the previous.
    move.b      BIOS_P1CURRENT,d0       ; This is the current input for this frame.
    move.b      d0,BIOS_P1PREVIOUS      ; Move the current to previous. 
    
    ; Update the current.
    move.b      REG_P1CNT,d0            ; Get the current value of the player's input.
    not.b       d0                      ; REG_P1CNT is active low, so switch the logic.
    move.b      d0,BIOS_P1CURRENT       ; This is the current input for this frame.
    
    ; Update the change.
    ; We need this truth table:
    ; current previous change
    ;    0       0        0
    ;    0       1        0
    ;    1       0        1
    ;    1       1        0
    move.b      BIOS_P1PREVIOUS,d1      ; Load the previous. 
    eor.b       d0,d1                   ; XOR with the current.
    and.b       d1,d0                   ; Filter to only get the rising change.
    move.b      d0,BIOS_P1CHANGE        ; Save it to the changed inputs.
    movem.l     (sp)+,d0/d1
    rts

    ; Subroutine to run when a player inserts a coin.
    ; Essentially we should do bookkeeping to BRAM and let the game know that a coin was inserted so it can play a coin sound.
    ; After a coin was inserted we should abruptly end the Demo and ask the game to do Title now (show the game title and wait for user to play "start").
COIN_IN:
    move.w      #$2700,sr               ; Disable all interrupts.
    jsr         COIN_SOUND              ; Ask the game to play a coin sound.
    move.b      BIOS_CREDIT_DEC1,d0     ; Get the current credits.
    addi.b      #1,d0                   ; Add one credit.
    move.b      d0,BIOS_CREDIT_DEC1     ; Save it back.
    move.b      #3,BIOS_USER_REQUEST    ; Ask the game to do title.
    move.w      #$2000,sr               ; Enable all interrupts.
    jmp         USER                    ; Blind jump to USER subroutine.

    ; BIOS routine to execute during VBLANK. The game should check on each VBLANK if it's ok to handle VBLANK or let the BIOS do it.
VBLANK:
    rte                                 ; Don't do anything on VBLANK, just return back.

    ; BIOS default Timer interrupt. 
TIMER_INTERRUPT:
    move.b      #2,REG_IRQACK           ; Acknowledge the interrupt.
    rte                                 ; Return back, don't do anything else.

    include "clear_screen.asm"