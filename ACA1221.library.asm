	* ACA1221.library
* simple interface to the cards' speed change settings

	opt ow+,o+, d-
	MACHINE MC68020

	incdir	"NDK_39:include/include_i/"
	
	include	"exec/memory.i"
	include "exec/initializers.i"
	include "exec/libraries.i"
	include "lvo/exec_lib.i"
	include "lvo/dos_lib.i"
	include "lvo/expansion_lib.i"
	include	"dos/dos.i"


* setting this flag produces a dummy library which 
* "behaves" like the real thing and does not depend
* on the presence of an ACA1221(EC)
DEBUG		equ		0

	IFNE DEBUG	
		OUTPUT	ACA1221debug.library
		opt DEBUG XDEBUG SYMTAB
	ENDC


******** ACA Interface memory adresses **************

*** EC & non-EC ***

ACA_AutoConfig			equ		$e90000
ACA_Memory				equ		$e91000
ACA_Trigger				equ		$e92000
ACA_Status				equ		$e93000


*** non-EC ***

ACA_License				equ		$e94000
ACA_Trial               equ     $e95000

ACA_1221_UpperMapROM	equ		$bf80000
ACA_1221_LowerMapROM	equ		$bf00000


*** EC ***

ACA_1221EC_LowerMapROM	equ		$600000
ACA_1221EC_UpperMapROM	equ		$780000

*****  ACA1221Lib defines  *****
AR_MAPINT       equ		1	
AR_MAPREMOVE	equ		-1


*****  ACAInfo offsets *****

ai_MapROM			equ		0
ai_ClockInfo		equ		2
ai_ClockMax			equ		6
ai_NoMemcard		equ		10
ai_NoC0Mem			equ		12
ai_Serial			equ		14
ai_CurrentCPU		equ		18
ai_Overdrive		equ     20
ai_TrialJumper		equ		22
ai_UnlockJumper		equ		24
ai_Trials			equ		26
ai_Version			equ		28
ai_MemSize			equ		32

	incdir		""

***************** Library structure *****************
;	bra		GetCurrentSpeed		; DEBUG
;	moveq	#1,d0
;	bra		SetSpeed
;	bra		GetMaxSpeed
;	bsr		InitRoutine
;	bsr		ACA1221_GetStatus
;	bsr		ACA1221_GetCurrentSpeed
;	moveq	#0,d1
;	bsr		ACA1221_SetSpeed
;	move.l	#kickname,d0
;	bra		ACA1221_MapROM

	
Startlib:
    moveq    #0,d0
    rts

RomTag:
    dc.w    $4afc		;RT_MATCHWORD /ILLEGAL
    dc.l    RomTag		;RT_MATCHTAG
    dc.l    endep		;RT_ENDSKIP
    dc.b    $80			;RT_FLAGS - AutoInit-flag set
    dc.b    1			;RT_VERSION
    dc.b    9			;RT_TYPE
    dc.b    0			;RT_PRI
    dc.l    libname		;RT_NAME
    dc.l    idstring	;RT_IDSTRING
    dc.l    init		;RT_INIT - parameters for MakeLibrary()

libname:
    dc.b    'ACA1221.library',0
    even
idstring:
	
	IFEQ	DEBUG
	
    dc.b    '$VER: ACA1221.library 1.2  (20-May-2017) '
    
    ELSEIF
    
    dc.b    '$VER: ACA1221DEBUG.library 1.2  (20-May-2017) '

	ENDC    
    
    dc.b    'by Marcus Gerards '
    dc.b    '(marcus.gerards@gmail.com)',0
    even
init:
    dc.l    34	; LibSize(34)
    dc.l    functable
    dc.l    datatable
    dc.l    InitRoutine

functable:
    dc.w    -1							; ToDo: do we really need that marker?

**********	Standard library functions	*********
    dc.w    Open-functable				;-06
    dc.w    Close-functable				;-12
    dc.w    Expunge-functable			;-18
    dc.w    Startlib-functable			;-24
	
**********	Custom functions			**********
    dc.w    ACA1221_GetCurrentSpeed-functable	;-30
    dc.w    ACA1221_GetMaxSpeed-functable		;-36
    dc.w    ACA1221_SetSpeed-functable			;-42
    dc.w	ACA1221_MapROM-functable			;-48
    dc.w	ACA1221_GetStatus-functable			;-54
    dc.w    -1							; End marker

datatable:
    INITBYTE    8,9				;LN_TYPE,NT_LIBRARY
    INITLONG    10,libname		;LN_NAME,LibName
    INITBYTE    14,6			;LIB_FLAGS,LIBF_SUMUSED!LIBF_CHANGED
    INITWORD    20,1			;LIB_VERSION,VERSION
    INITWORD    22,2			;LIB_REVISION,REVISION
    INITLONG    24,idstring		;LIB_IDSTRING,IDString
    dc.l    0


**********	Library initialization	**********
InitRoutine:
	movem.l	d0-a6,-(sp)
    move.l	a0,seglist
    move.l	4.w,a6
    lea		exname(pc),a1
    moveq	#33,d0					; expansion.library V33
    jsr		_LVOOpenLibrary(a6)		; open it
    move.l	d0,exbase
	tst.l	d0
    beq.w	openerror
    
    
* check for Autoconfig for ACA1221
	IFEQ	DEBUG					; we need to skip this for the dummy library
autoconf:
    move.l	exbase(pc),a6        
    move.l	#0,a0 
nextboard:
    move.l	#4626,d0				; ManID: IComp
    moveq	#-1,d1					; ProdID: any
    jsr		_LVOFindConfigDev(a6)
    move.l	d0,a0					; save ConfigDev pointer for next loop
    tst.l	d0
    beq.w	openerror				; last board or none?
    cmp.b	#21,17(a0)				; ACA1221?
    beq.s	saveserial
    cmp.b	#22,17(a0)				; ACA1221EC?
    bne.s	nextboard
    
    lea		flagEC,a1				; set flag for EC version
    move.l	#1,(a1)
    
    ENDC

saveserial:
	lea		ACAInfo,a3
	move.l	22(a0),ai_Version(a3)	; for maximum clock
	
    
opendos:    
    move.l	4.w,a6
    lea		dosname(pc),a1
    moveq	#37,d0					; try dos V37 for env-var
    jsr		_LVOOpenLibrary(a6)
    move.l	d0,dosbase
    tst.l	d0
    beq.s	openerror
    

noenv
    movem.l	(sp)+,d0-a6
    rts
	

openerror:							;something went wrong...
    movem.l	(sp)+,d0-a6
    moveq	#0,d0
    rts

Open:								; exec delivers libptr:a6, libversion:d0 
    addq.w	#1,32(a6)				; increase LIB_OPENCNT
    bclr	#3,14(a6)				; clear the EXPUNGE-bit in LIB_FLAGS
    move.l	a6,d0					; return ACA1221Base
    rts

Close:								; ( libptr:a6 )
    subq.w	#1,32(a6)				; decrease LIB_OPENCNT
    bne.s	.nooneopen
    btst	#3,14(a6)        		; test LIB_FLAGS - can we remove the library?
    bne.s	Expunge 				; do it -> .nooneopen2
.nooneopen:
    moveq	#0,d0
    rts

Expunge:							; ( libptr: a6 )
    tst.w	32(a6)					; test OpenCount
    beq.s	.nooneopen2				; we still have users
    bset	#3,14(a6)				; expunge at first opportunity
    moveq	#0,d0
    rts


.nooneopen2:
    movem.l	d2/a4/a6,-(sp)
    move.l	a6,a4
    move.l	seglist,d2
    move.l	a4,a1
    move.l	4.w,a6
    jsr		_LVORemove(a6)			; remove library
	
    moveq	#0,d0
    move.l	a4,a1					; get library base address
    move.w	16(a4),d0				; LIB_NEGSIZE
    sub.w	d0,a1
    add.w	18(a4),d0				; LIB_POSSIZE
    jsr		_LVOFreeMem(a6)			; FreeMem (library structure & jumptables)

    move.l	4.w,a6					; close 
    move.l	exbase(pc),a1			; expansion.library
    jsr		_LVOCloseLibrary(a6)
    
    move.l	dosbase(pc),a1
    cmp.l	#0,(a1)					; did we open dos.library?
    beq.s	.nodosopen				
    jsr		_LVOCloseLibrary(a6)

.nodosopen:
    move.l	d2,d0					; return SegmentList
    movem.l	(sp)+,d2/a4/a6
    rts
    
    
******* ACA1221.library/ACA1221_GetStatus ************************************
*
*   NAME
*       ACA1221_GetStatus() - return info about the card's settings
*
*   SYNOPSIS
*       status = ACA1221_GetStatus();
*       D0
*
*       struct ACA1221Info *ACA1221_GetStatus(void);
*
*   FUNCTION
*       Reads settings of the card and returns a pointer to an internal 
*       library structure. 
*       
*   INPUTS
*       none
*
*   RESULT
*       status - pointer to struct ACA1221Info (see ACA1221.h) or NULL
*
*   EXAMPLE
*       struct ACA1221Info *ACAInfo = NULL:
*       
*       ACAInfo = ACA1221_GetStatus();
*      
*       Printf("MapROM is currently %s\n",
*                 ACAInfo->ai_MapROMStatus ? "enabled" : "not enabled");
*
*   NOTES
*       None
*
*   BUGS
*       None known
*
*   SEE ALSO
*       libraries/ACA1221.h
* 	
*											
*******************************************************************************
 
ACA1221_GetStatus:
	movem.l	a0-a6/d1-d7,-(a7)
	lea 	ACA_Status,a0
;   lea 	TestAdrr,a0
	lea		ACAInfo,a1
	moveq	#0,d1
	moveq	#0,d2
	move.l	#%10000000,d4
	move.b	(a0),d1
	
	move.w	d1,d2
	and.b	d4,d2
	lsr.w	#7,d2
	move.w	d2,ai_Overdrive(a1)
	move.w	d1,d2
	lsr.b	#1,d4
	and.b	d4,d2
	lsr.w   #6,d2
	move.w	d2,ai_UnlockJumper(a1)
	
	move.w	d1,d2
	lsr.b	#1,d4
	and.b	d4,d2
	lsr.w   #5,d2
	move.w	d2,ai_TrialJumper(a1)
	
	move.w	d1,d2
	lsr.b	#1,d4
	and.b	d4,d2
	lsr.w   #4,d2
	move.w	d2,ai_MapROM(a1)
	
	move.w	d1,d2
	clr.l	d4
	move.b	#%1100,d4
	and.b	d4,d2
	lsr.b   #2,d2
	move.b	d2,ai_MemSize(a1)
	
	moveq	#0,d0
	bsr.s	ACA1221_GetCurrentSpeed
	move.l	d0,ai_ClockInfo(a1)
	
	moveq	#0,d0
	bsr		ACA1221_GetMaxSpeed
	move.l	d0,ai_ClockMax(a1)
	
	lea     ACA_Trial,a0            ; access the number of trials
	move.b  (a0),ai_Trials(a1)      ; store them
	move.l	a1,d0
   
.endStatus
	movem.l (sp)+,d1-d7/a0-a6	; Restore registers
	rts

.checkdone:
	move.l	a2,d0					; return info structure
    
    movem.l	(a7)+,a0-a6/d1-d7
    rts

    


******* ACA1221.library/ACA1221_GetCurrentSpeed **************************************
*
*   NAME 										
*       ACA1221_GetCurrentSpeed -- determine the current speed values of the card
*
*   SYNOPSIS
*       speedinfo = ACA1221_GetCurrentSpeed()				
*       D0
*	
*       struct ClockInfo *ACA1221_GetCurrentSpeed(void);	
*
*   FUNCTION
*       Read current speed setting of the card. Returns a pointer to
*       an internal library structure. Both actual clock value 
*       (STRPTR) and speed stepping (UWORD) will be returned.													*
*       
*   INPUTS
*       none
*
*   RESULT
*       speedinfo - pointer to struct ClockInfo (see ACA1221.h) or NULL
*
*   EXAMPLE
*       struct ClockInfo *ACASpeed = NULL:
*       
*       ACASpeed = ACA1221_GetCurrentSpeed();
*
*       Printf("My current speed stepping is %ld (%s)",
*                 ACASpeed->ci_CPUSpeedStep, ACASpeed->ci_CPUClock);
*
*   NOTES
*       Any task accessing the library may call ACA1221_SetSpeed(), so always 
*       call ACA1221_GetCurrentSpeed() right before you process the ClockInfo 
*       values.
*
*   BUGS
*       None known
*
*   SEE ALSO
*       ACA1221_GetMaxSpeed(), ACA1221_SetSpeed(), libraries/ACA1221.h
* 	
*											
******************************************************************************

ACA1221_GetCurrentSpeed:
    movem.l	a0-a6/d1-d7,-(a7)
    lea 	ACA_Status,a0
    move.l	flagEC,d4
    cmp.l	#1,d4
    bne.s	noEC
    lea		clocktableEC,a1
    bra.s	readspeed
noEC:
	moveq	#0,d0
	move.b	(a0),d0
	and.l	#%10000000,d0
	lsr.w	#7,d0
	cmp.w	#1,d0
	beq.s	.overdrive				; overdrive needs different clocktable
	lea		clocktable,a1
	bra.s	readspeed
.overdrive:
	lea		clocktableOD,a1

readspeed:	
	lea		ACACurrentSpeed,a2
	moveq	#0,d0
	
	IFEQ	DEBUG					
	
	moveq	#%11,d1					; mask for clock speed			
	move.b	(a0),d0
	and.b	d1,d0
	move.w	d0,4(a2)				; save the speed stepping
	
	ELSEIF	
	
	tst.l	(a2)					; the dummy lib grabs a speed setting directly from the struct
	bne.s	cspeedset
	move.l	#3,d0
	bra.s	cont
cspeedset:
	move.w	4(a2),d0
cont:
	
	ENDC
	
	lsl.w	#2,d0					; multiply speed step by 4
	add.l	d0,a1					; point to longword with clock value
	move.l	(a1),(a2) 				; save the clock value	
	cmp.l	#1,d4
	bne.s	noECstep
	lea 	clocktransEC,a3
	lsr.w	#2,d0
	move.w	(a3,d0.w*2),4(a2)		; save the speed stepping
	
noECstep:	
	move.l	a2,d0					; return clock structure
    
    movem.l	(a7)+,a0-a6/d1-d7
    rts


******* ACA1221.library/ACA1221_GetMaxSpeed *************************************
*
*   NAME
*       ACA1221_GetMaxSpeed() - determine the maximum speed setting of the card
*
*   SYNOPSIS
*       speedinfo =	ACA1221_GetMaxSpeed();
*       D0
*
*       struct ClockInfo *ACA1221_GetMaxSpeed(void);
*
*   FUNCTION
*       Read maximum speed setting of the card. Returns a pointer to
*       an internal library structure. Both actual clock value 
*       (STRPTR) and speed stepping (UWORD) will be returned.	
*
*   INPUTS
*       none
*
*   RESULT
*       speedinfo - pointer to struct ClockInfo (see ACA1221.h) or NULL
*
*   EXAMPLE
*       struct ClockInfo *ACAMaxSpeed = NULL:
*       
*       ACAMaxSpeed = ACA1221_GetMaxSpeed();
*      
*       Printf("My maximum speed stepping is %ld (%s)",
*                 ACAMaxSpeed->ci_CPUSpeedStep, ACAMaxSpeed->ci_CPUClock);
*
*   NOTES
*       The maximum speed is determined by the current license status of the
*       card. The status can be checked via the tool "ACAControl" supplied 
*       with the card.
*
*   BUGS
*       None known
*
*   SEE ALSO
*       ACA1221_GetCurrentSpeed(), ACA1221_SetSpeed(), libraries/ACA1221.h
* 	
*											
******************************************************************************

ACA1221_GetMaxSpeed:
    movem.l d1-a6,-(a7)			; d0 = result
    lea		ACA_License,a0
    lea		ACA_Status,a3
    move.l	flagEC,d0
    cmp.l	#1,d0				; check for EC version
    beq.s	speedmaxEC
    
    moveq	#0,d0
	move.b	(a3),d0
	and.l	#%10000000,d0
	lsr.w	#7,d0
	cmp.w	#1,d0
	beq.s	.overdrive				; overdrive needs different clocktable
	lea		clocktable,a1
	bra.s	readmaxspeed
.overdrive:
	lea		clocktableOD,a1

readmaxspeed:    
    lea 	ACAMaxSpeed,a2
	moveq	#0,d0		
	
	IFEQ	DEBUG				; the dummy lib gets maximum clock license
	
	moveq	#%11,d1
	move.b	(a0),d0
	and.b	d1,d0
	
	ELSEIF
	
	moveq	#3,d0				; 3 = max clock
	
	ENDC
	
	move.w	d0,4(a2)
	lsl.w	#2,d0
	add.l	d0,a1
	bra.s	returnMax
	
speedmaxEC:
	lea		clocktableEC,a1
	lea		ACAMaxSpeed,a2
	move.w	#3,4(a2)
	add.l	#12,a1

returnMax:
	move.l	(a1),(a2)
	move.l	a2,d0
    movem.l (a7)+,d1-a6        
    rts



******* ACA1221.library/ACA1221_SetSpeed *************************************
*
*   NAME
*       ACA1221_SetSpeed - changes the current speed setting of the card
*
*   SYNOPSIS
*       Success = ACA1221_SetSpeed(speedStepping);
*       D0                 D0
*
*       BOOL ACA1221_SetSpeed(UBYTE);
*
*   FUNCTION
*       Change the current speed setting of the card to the supplied stepping.
*       The setting is in effect until the next flip of the power switch.
*
*   INPUTS
*       speedStepping   - binary value, a fully licensed ACA1221 supports 
*                         stepping 0-3, which correspond to the following
*                         clock values:
*
*                         0: 9.46 MHz
*                         1: 17.03 MHz
*                         2: 21.28 MHz
*                         3: 28.38 MHz (42.56 MHz in overdrive mode)    
*                         
*                         the  ACA1221EC always supports stepping 0-3, 
*                         which correspond to the following clock values:
*
*                         0: 17.03 MHz
*                         1: 21.28 MHz
*                         2: 28.38 MHz
*                         3: 42.56 MHz (will only work with CPU mask E13G!)    
*    
*
*   RESULT
*       success - TRUE, if the card accepts the setting, otherwise FALSE. You
*                 may check this by calling ACA1221_GetCurrentSpeed() after 
*                 ACA1221_SetSpeed().
*
*   EXAMPLE
*       BOOL success = FALSE;
*       UBYTE mySpeed = 2;
*
*       success = ACA1221_SetSpeed(mySpeed);
*       
*       if (success) {
*           Printf("My speed stepping has been set to %ld\n", mySpeed);
*       }
*
*   NOTES
*       For the ACA1221, the maximum speed available is determined by the 
*       current license status of the card, while all speed steps are always
*       available for the 1221EC.
*       You get the maximum speed stepping by calling ACA1221_GetMaxSpeed(). 
*       The license status of the ACA1221 can be checked via the tool 
*       "ACAControl" supplied with the card.
*
*       You may call the function anytime without the need to disable 
*       multitasking. Other tasks (e.g. formatting disks, etc.) will not be
*       disturbed.
*
*   BUGS
*       None known
*
*   SEE ALSO
*       ACA1221_GetCurrentSpeed(), ACA1221_GetMaxSpeed(), libraries/ACA1221.h
* 	
*											
******************************************************************************

ACA1221_SetSpeed:
	movem.l d1-a6,-(a7)
   
	lea		ACA_Memory,a0
	lea		command,a1
	lea		ACA_Trigger,a2
	
	lea		ACACurrentSpeed,a3	
	move.w	d0,4(a3)		; we store it right here 
	
	IFEQ	DEBUG			; dummy lib sets any speed
	
	moveq	#0,d1
	move.l	flagEC,d1
	cmp.l	#1,d1
	beq.s	setspeedEC		; the EC version has a different table
	lea		clocktable,a5
	bra.s	storespeed

setspeedEC:	
	lea 	clocktableEC,a5
	lea		clocktransEC2,a4
	move.w	(a4,d0.w*2),d0
	
storespeed:
;	lsl.w	#2,d0
	move.l	d0,d3
	lsl.w	#2,d3
	add.w	d3,a5
	move.w	(a5),(a3)
	move.b	#4,(a1)			; issue temp CPU speed command

	cmp.l	#1,d1
	bne.s	.setclockNOEC	; the EC version must switch to 21.28 MHz, first!
	tst.l	d0
	beq.s	.setclockNOEC	; except that's what the user wants anyway...
	
	move.l	4.w,a6
	jsr		_LVODisable(a6)
	jsr		_LVOForbid(a6)

	move.b	#0,1(a1)
	move.w	(a1),(a0)		; store command line in ACA memory
	
	move.b	#1,(a2)			; pull the trigger
	nop					; short wait
	nop
	
	jsr		_LVOPermit(a6)
	jsr		_LVOEnable(a6)

		
	moveq	#1,d1
	lea		ACA_OK,a4
.checkintspeed:
	cmp.b	(a4)+,(a0)+
	bne.s	speederror
	dbra	d1,.checkintspeed
	
.setclockNOEC
	lea		ACA_Memory,a0
	move.b	#4,(a1)			; issue temp CPU speed command
	move.b	d0,1(a1)		; set speed
	move.w	(a1),(a0)		; store command line in ACA memory
	
	move.l	4.w,a6
	jsr		_LVODisable(a6)
	jsr		_LVOForbid(a6)

	move.b	#1,(a2)			; pull the trigger
	nop					; short wait
	nop
	
	jsr		_LVOPermit(a6)
	jsr		_LVOEnable(a6)
	
	moveq	#1,d1
	lea		ACA_OK,a4
checkspeed:
	cmp.b	(a4)+,(a0)+
	bne.s	speederror
	dbra	d1,checkspeed
	bra.s	speedsuccess	
speederror:
	moveq	#0,d0
		
speedsuccess:
	ELSEIF
	ENDC
	moveq	#1,d0				; speed has been set successfully
speedreturn:
	;jsr		_LVOPermit(a6)
	;jsr		_LVOEnable(a6)
	movem.l (sp)+,d1-d7/a0-a6	; Restore registers
    rts


******* ACA1221.library/ACA1221_MapROM *******************************
*
*   NAME
*       ACA1221_MapROM() - Maps/unmaps Kickstart ROM to/from FastRAM
*
*   SYNOPSIS
*       success = ACA1221_MapROM(file, option);
*       D0                       D0    D1
*
*       BOOL ACA1221_MapROM(STRPTR, LONG);
*
*   FUNCTION
*       Maps Kickstart ROM to the contents of a file which will be copied to 
*       FastRAM beforehand.Supply AR_MAPINT as option argument to use the 
*       internal physical Kickstart ROM as the source or supply AR_MAPREMOVE to 
*       deactivate the MapROM feature. If you supply an option, "file" should 
*       be NULL, but will be ignored anyway.
*
*   INPUTS
*       file   - pointer to a filenameor NULL
*       option - one of the options AR_MAPREMOVE, AR_MAPINT
*
*   RESULT
*       success - TRUE, if the card accepts the setting, otherwise FALSE. 
*
*   EXAMPLE
*       BOOL success = FALSE;
*       STRPTR file = "kickstart.rom";
*       ...
*
*       success = MapROM(file, 0);
*
*       if (success) {
*           Printf("Contents of the file have been mapped as Kickstart ROM\n");
*       }
*
*	NOTES
*
*   BUGS
*		none known
*
*   SEE ALSO
*       libraries/ACA1221.h
*        	
*											
******************************************************************************

ACA1221_MapROM:

	movem.l	d1-a6,-(sp)
	move.l	flagEC,d6

;	move.l	#kickname,d0
	move.l	d0,d2				; save filename ptr
	move.l	d1,d3				; save option
;	moveq	#AR_MAPINT,d3		; debug: test MAPINT
;	moveq	#AR_MAPREMOVE,d3	; debug: test MAPREMOVE

	lea		ACA_Status,a0
	moveq	#0,d1
	move.b	(a0),d1
	and.l	#%10000,d1
	lsr.l	#4,d1
	
	cmp.l	#AR_MAPREMOVE,d3	; remove mapped ROM?
	
	bne.s	.startMapROM
	move.l	d1,d0
	cmp.w	#1,d0
	bne.s	.mapROM_done
	
	bsr		UnSetMapRom
	move.b	ACA_Status,d1
	and.l	#%10000,d1
	lsr.l	#4,d1				; check if MapRom has been 
	move.l	d1,d0				; disabled sucessfully
	bchg	#0,d0				; and swap the bit for proper return code
	bra.s	.mapROM_done

.startMapROM:	
	cmp.w	#1,d1				; MapROM already active?
	beq		noMapROM

	cmp.l	#AR_MAPINT,d3		; copy internal ROM?
	bne		processFile			; else get the file
	lea 	$f80000,a0			; copy ROM to both maprom areas
	
	tst.l	d6
	beq.s	.noEC_up
	jsr		EC_copyint
;	bra.s	.mapROM_done
	bra.s 	.SetMapRom

.noEC_up
	lea		ACA_1221_UpperMapROM,a1

.copyUpper		
	jsr		copyROM512k
	lea		$f80000,a0

	lea		ACA_1221_LowerMapROM,a1

.copyLower	
	jsr		copyROM512k

.SetMapRom
	bsr.s	SetMapRom			; and enable MapROM
	
.getStatus:	
	lea		ACA_Status,a0
	moveq	#0,d0
	move.b	(a0),d0
	and.l	#%10000,d0
	lsr.l	#4,d0
	
.mapROM_done:
	movem.l	(sp)+,d1-a6
	rts

*** little subroutine for setting the MapRom-flag ***
SetMapRom:
	lea		ACA_Memory,a0
	lea		command,a1
	lea		ACA_Trigger,a2
	move.b	#5,(a1)			; issue maprom command
	move.b	#1,1(a1)		; on or off?
	move.w	(a1),(a0)		; store command line in ACA memory
	
	move.l	4.w,a6
	jsr		_LVODisable(a6)
	jsr		_LVOForbid(a6)

	move.b	#1,(a2)			; pull the trigger
	nop						; short wait
	nop
	
	jsr		_LVOPermit(a6)
	jsr		_LVOEnable(a6)
	rts

*** little subroutine for resetting the MapRom-flag ***	
UnSetMapRom:
	moveq	#-1,d7
	jmp		rebootamiga
	rts
	
noMapROM:					;
	moveq	#0,d0
	movem.l	(sp)+,d1-a6
	rts

.freeBuffer:
	move.l	$4.w,a6
	jsr		_LVOFreeVec(a6)
	rts


*** Try to open the file and fill in FileInfoBlock ***
processFile:
	move.l  dosbase,a6
	moveq	#0,d0
	move.l	d2,d1
	move.l	#MODE_OLDFILE,d2
	jsr		_LVOOpen(a6)
	tst.l	d0
	beq		.fOpenError			; file not available?
	
	move.l	d0,d1				; save file handle
	move.l	d0,d5				; twice
	moveq	#0,d0
	move.l	#fib,d2				; buffer for FileInfoBlock
	jsr		_LVOExamineFH(a6)
	tst.l	d0
	beq.	.bAllocError
	
.checkBuffer:
	move.l	$4.w,a6
	move.l	d2,a0
	move.l	fib_Size(a0),d4	; check the kickstart's size
	
	cmp.l	#$80000,d4
	bne.s	.no512k
	move.l	d4,kickSize
	bra.s	.allocBuffer
	
.no512k:
	cmp.l	#$40000,d4	
	bne.s	.no256k
	move.l	d4,kickSize
	bra.s	.allocBuffer

.no256k:
	cmp.l	#$100000,d4
	bne		.bAllocError		; ok, it's neither 256 nor 512 nor 1024k
	move.l	d4,kickSize

.allocBuffer					; we allocate a handsome buffer for our file
	move.l	d4,d0
	tst.l	d6
	beq.s	.noChip
	move.l	#(MEMF_CHIP|MEMF_CLEAR),d1
	bra.s	.doAlloc
.noChip
	move.l	#(MEMF_ANY|MEMF_CLEAR),d1
.doAlloc	
	jsr		_LVOAllocVec(a6)
	tst.l	d0
	beq		.bAllocError
	move.l	d0,kickBuffer
	
.readKickFile:
	moveq	#0,d0
	move.l	dosbase,a6
	move.l	d5,d1
	move.l	kickBuffer,d2
	move.l	kickSize,d3
	jsr		_LVORead(a6)
	cmp.l	kickSize,d0	
	bne.s	.fReadError
	move.l	kickBuffer,a0
	
	tst.l	d6
	beq.s	.noECcopy
	jsr		EC_copyfile
	bra		rebootamiga

.noECcopy:
	cmp.l	#$100000,d0
	bne.s	.normalKickSize
	jsr		copyROM1024k
	bra		rebootamiga			; and out

	
.normalKickSize:				; copy & mirror 512k ROM
	move.l	kickBuffer,a0
	lea		ACA_1221_UpperMapROM,a1

.copyUpper
	jsr		copyROM512k
	
	move.l	kickBuffer,a0
	lea		ACA_1221_LowerMapROM,a1

.copyLower:	
	jsr		copyROM512k
	bra		rebootamiga			; and out

.fReadError:
	move.l	$4.w,a6
	move.l	kickBuffer,a1
	jsr		_LVOFreeVec(a6)

.bAllocError;
	move.l	d5,d1
	jsr		_LVOClose(a6)

.fOpenError:
	moveq	#0,d0
	bra		noMapROM
	rts

.fdone:
	moveq	#1,d0
	rts


*** kick rom copy routines ***
*
* a0 = ROM/Source buffer
* a1 = target maprom space 
*
******************************

copyROM1024k: 
	lea		ACA_1221_LowerMapROM,a1 ; Extended ROM pointer
	
.copyKick:
	moveq	#$0003,d0				; Copy 1024kb of data
	move.l	#$ffff,d1
.copyownkick1024kloop:
	move.l	(a0)+,d2				; Copy extended ROM
	move.l 	d2,(a1)+				; & Copy Kickstart ROM	
	dbra 	d1,.copyownkick1024kloop
	dbra 	d0,.copyownkick1024kloop
	rts



*******************************************************************************
rebootamiga:		
	lea		ACA_Memory,a0
	lea		command,a1
	lea		ACA_Trigger,a2

	move.b	#5,(a1)			; issue maprom command
	
	cmp.l	#-1,d7
	beq.s	.mapremove
	
	move.b	#1,1(a1)		; on or off?

	lea.l	rebootprogram,a5
	bra.s	.mapitnow

.mapremove
	move.b	#0,1(a1)		; on or off?
	
	lea.l	rebootprogram,a5

.mapitnow
	move.l	(a1),(a0)
	move.l	$4.w,a6					; Get Exec pointer

	jsr		_LVODisable(a6)
	jsr		_LVOSupervisor(a6)		; Gain Supervisor status	
	



;========================================================================
* Various buffers
;========================================================================

seglist:    dc.l    0
exbase:		dc.l    0
dosbase:	dc.l	0
envbuf:		dc.l	0

	even

memory_list:	dc.l	0 ; pointer to a list of all memory chunks allocated by the library

exname:			dc.b    "expansion.library",0
dosname:		dc.b	"dos.library",0

envname:		dc.b 	"ACA_CUSTOMCHECK",0

	even
	
flagEC:			dc.l	0
	
clocktable:		dc.l	Speed0,Speed1,Speed2,Speed3	; ACA1221 clock speed jump table
clocktableOD:	dc.l	Speed0,Speed1,Speed2,Speed4 ; ACA1221 (overdrive) clock speed jump table
clocktableEC:	dc.l	Speed2,Speed3,Speed1,Speed4 ; ACA1221EC clock speed jump table
clocktransEC:	dc.w	1,2,0,3
clocktransEC2:	dc.w	2,0,1,3

Speed0:			dc.b	"9.46 MHz",0
Speed1:			dc.b	"17.03 MHz",0
Speed2:			dc.b	"21.28 MHz",0
Speed3:			dc.b	"28.38 MHz",0
Speed4:			dc.b	"42.56 MHz",0

	even

*ACAInfo struct 
ACAInfo:			
				dc.w	0	; ai_MapROM
				dc.l	0	; ai_ClockInfo (pointer to struct ClockInfo)
				dc.l	0	; ai_ClockMax (pointer to struct ClockInfo)
				dc.w	0   ; ai_NoMemcard
				dc.w	0   ; ai_NoC0Mem
				dc.l	0	; ai_Serial (copy of er_serial)
				dc.w	0	; ai_CurrentCPU (0 = 68EC020 or 1 = 68020)
				dc.w	0	; ai_Overdrive;
				dc.w	0	; ai_TrialJumper;
				dc.w	0	; ai_UnlockJumper;
				dc.w	0	; ai_Trials;
				dc.l	0	; ai_Version;	
				dc.b	0	; ai_MemSize;

	even
ACASerial       dc.l    0
	
* ACASpeed struct - STRPTR Clock, UWORD SpeedStep
ACAMaxSpeed		dc.l	0
				dc.w	0
ACACurrentSpeed	dc.l	0
				dc.w	0
					 
command			ds.l	8

ACA_OK			dc.b	'OK',0

	cnop	0,4
	
fib:			ds.b	$104

	
endep:
	even
	

**********************************************************
	SECTION	"reboot",CODE_C

	cnop	0,4
rebootprogram:

	move.l	#$0808,d6
	movec	d6,cacr			; Flush and disable caches

	move.w 	#$2700,sr		; Disable all interrupts
	move.w 	#$7fff,$dff09a	; Disable chipset interrupts
	move.w 	#$7fff,$dff09c	; Clear pending interrupts
	move.w 	#$7fff,$dff096	; Disable chipset DMA
	move.b 	#$7f,$bfed01	; Disable CIAB interrupts
	move.b 	#$7f,$bfdd00	; Disable CIAA interrupts
	
	move.l	#$ffff,d6		; for the show
.gimmecolours
	move.w	d6,$DFF180
	subq	#1,d6
	move.w	d6,$DFF182
	dbra	d6,.gimmecolours

	
	lea		ACA_Trigger,a2
	move.b	#1,(a2)			; pull the trigger & (de-)activate ACAMapROM
	nop						; short wait
	nop

	clr.l 	d0
	movec 	d0,vbr			; Set VBR to $0
	
	clr.l	$4.w			; clear execbase

	
	lea.l	$1000000,a0
	sub.l	-$14(a0),a0
	move.l	4(a0),a0
	subq.l	#2,a0
	reset	
	jmp 	(a0)			; This works thanks to 68K prefetch


EC_copyint:
	movem.l d0-d7/a0-a6,-(sp)	; save registers

	move.l	4.w,a6	
	moveq	#0,d0				; flush and disable caches
	moveq	#1,d1
	jsr		_LVOCacheControl(a6)
	move.l	d0,cachebits

										; we need to shuffle MapROM-area in
	jsr		_LVODisable(a6)				; before copying
	jsr		_LVOForbid(a6)				; on EC cards
	moveq	#1,d0
	
	lea 	ACA_Memory,a0
	lea		command,a1
	move.b	#3,(a1)			; memory-command
	move.b	d0,1(a1)
	move.l	(a1),(a0)		; store command line in ACA memory
	
	lea		ACA_Trigger,a2
	move.b	#1,(a2)			; pull the trigger & (de-)activate MemShuff
	nop						; short wait
	nop

	lea		$f80000,a0
	lea		ACA_1221EC_UpperMapROM,a1
	jsr		copyROM512k

	lea		$f80000,a0	
	lea		ACA_1221EC_LowerMapROM,a1
	jsr		copyROM512k
	
	moveq	#0,d0						; shuffle memory back out
	lea 	ACA_Memory,a0
	lea		command,a1
	move.b	#3,(a1)			; memory-command
	move.b	d0,1(a1)
	move.l	(a1),(a0)		; store command line in ACA memory
	
	lea		ACA_Trigger,a2
	move.b	#1,(a2)			; pull the trigger & (de-)activate MemShuff
	nop						; short wait
	nop

	move.l	4.w,a6	
	jsr		_LVOPermit(a6)
	jsr		_LVOEnable(a6)
	
	moveq	#1,d1
	move.l	cachebits,d0
	jsr		_LVOCacheControl(a6)

	movem.l (sp)+,d0-d7/a0-a6	; Restore registers
	rts


copyROM512k:
	moveq	#0,d0
	move.l	#$ffff,d1
	moveq	#$1,d2

.copyROM512kloop:
	move.l	(a0)+,d0
	move.l	d0,(a1)+
	dbra 	d1,.copyROM512kloop
	dbra	d2,.copyROM512kloop
	rts

EC_copyfile:
	movem.l d0-d7/a0-a6,-(sp)	; save registers
	move.l	d0,d4
	move.l	4.w,a6	
	moveq	#0,d0				; flush and disable caches
	moveq	#1,d1
	jsr		_LVOCacheControl(a6)
	move.l	d0,cachebits

										; we need to shuffle MapROM-area in
	jsr		_LVODisable(a6)				; before copying
	jsr		_LVOForbid(a6)				; on EC cards
	moveq	#1,d0
	
	lea 	ACA_Memory,a0
	lea		command,a1
	move.b	#3,(a1)			; memory-command
	move.b	d0,1(a1)
	move.l	(a1),(a0)		; store command line in ACA memory
	
	lea		ACA_Trigger,a2
	move.b	#1,(a2)			; pull the trigger & (de-)activate MemShuff
	nop						; short wait
	nop

	move.l	kickBuffer,a0
	
.normalKickSize:				; copy & mirror 512k ROM
	
	lea		ACA_1221EC_LowerMapROM,a1
	jsr		copyROM512k
	
	cmp.l	#$100000,d4
	beq.s	.copyLow
	move.l	kickBuffer,a0
	
.copyLow
	lea		ACA_1221EC_UpperMapROM,a1
	jsr		copyROM512k
		
.shuffleback	
	
	moveq	#0,d0						; shuffle memory back out
	lea 	ACA_Memory,a0
	lea		command,a1
	move.b	#3,(a1)			; memory-command
	move.b	d0,1(a1)
	move.l	(a1),(a0)		; store command line in ACA memory
	
	lea		ACA_Trigger,a2
	move.b	#1,(a2)			; pull the trigger & (de-)activate MemShuff
	nop						; short wait
	nop

	move.l	4.w,a6	
	jsr		_LVOPermit(a6)
	jsr		_LVOEnable(a6)
	
	moveq	#1,d1
	move.l	cachebits,d0
	jsr		_LVOCacheControl(a6)

	movem.l (sp)+,d0-d7/a0-a6	; Restore registers
	rts
	
	cnop	0,4

cachebits:	dc.l	0

kickBuffer:		dc.l	0
kickSize:		dc.l	0

	
;kickname:	dc.b	"kdh1:devs/kickstarts/os39_a1200_v2.rom",0