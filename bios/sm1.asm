; NeoGeo default sound driver.

    org $00
Reset:
	ld	    sp,$ffff			; Reset the stack pointer to the end of RAM.
	out	    ($08),a				; Enable NMI.

; Hang in RAM until NMI happens. 
.loop:
	jr	    .loop

    ; NMI from YM2610.
    org	$38
	retn

    ; Command from m68k.
    org $66
    in		a,($00)

    ; $01 means to prepare for switching to the Cartridge's sound driver.
    cp		$01
    jr		z,PrepareSwitch

    ; $03 means we should reset.
    cp		$03
    jr		z,Reset

    retn					    ; Return from NMI.

; Prepare for ROM switch with the cartridge's sound driver. We don't care here, just reset.
PrepareSwitch:
    set		7,a				    ; Set bit 7 so the m68k knows we are working.
    out		($0C),a				; Send byte to m68k.
    jp		Reset               ; Blind jump to Reset.
