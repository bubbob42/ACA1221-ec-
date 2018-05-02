    IFND    LIBRARIES_ACA1221_I
LIBRARIES_ACA1221_I    SET     1
**
**      $VER: ACA1221.i 1.2 (20-May-17)
**
**      ACA1221.library definitions
**
**	(C)2015-2017 by Marcus Gerards
**      All Rights Reserved.
**


        IFND    EXEC_TYPES_I
        incdir	"include3.1:"
        INCLUDE 'exec/types.i'
        ENDC

;------------------------------------------------------------------------
; Generic library informations

ACA1221NAME      MACRO
        dc.b    "ACA1221.library",0
        ENDM

ACA1221VERSION   EQU     1

; Card's speed stepping capabilities 
ACA1221MAXSTEP   EQU     3
ACA1221MINSTEP   EQU     0
 
;------------------------------------------------------------------------
;
; ClockInfo structure
;
; A pointer to this  structure is returned by ACA1221.library upon call 
; on GetCurrentSpeed() and GetMaxSpeed()
; It`s READ-ONLY!

  STRUCTURE ClockInfo,0
    APTR	ci_CPUClock			; current/max CPU clock 
	UWORD	ci_CPUSpeedStep		; current/max CPU speed stepping
	

;-----------------------------------------------------------------------
; ACA1221Info structure
;
; A pointer to this structure is returned by ACA1221.library upon call 
; on ACA1221_GetStatus()
; It`s READ-ONLY!
; */

  STRUCTURE ACA1221Info,0
	BOOL	ai_MapROM					; MapROM status bit. TRUE, if enabled 
	APTR	ai_ClockInfo				; pointer to clock speed info 
	APTR	ai_ClockMax					; pointer to max clock speed info 
	BOOL	ai_NoMemcard				; Switches off card's fast memory. 
										; TRUE, if enabled 
	BOOL	ai_NoC0Mem					; TRUE, if SlowRAM is disabled 						
	ULONG	ai_Serial					; copy of Autoconf[tm] serial, 
										; equals rounded down version 
										; of card's maximum clock frequency 
	BOOL	ai_CurrentCPU				; the CPU currently in use (either 
										; 0 = 68EC020 or 1 = 68020 
	BOOL	ai_Overdrive				; Overdrive setting available? 
	BOOL	ai_TrialJumper				; Trial jumper set? 
	BOOL	ai_UnlockJumper				; Unlock jumper set? 
	UWORD	ai_Trials					; Number of trials left 
	ULONG	ai_Version					; firmware version 
	UBYTE	ai_MemSize					; licensed/available memory on card


	ENDC