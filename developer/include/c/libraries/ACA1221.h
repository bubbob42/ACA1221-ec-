#ifndef LIBRARIES_ACA1221_H
#define LIBRARIES_ACA1221_H

/*
**      $VER: ACA1221.h 2.0 (05.05.2017)
**    
**
**      ACA1221.library definitions
**
**	(C)2015-2017 by Marcus Gerards
**      All Rights Reserved.
*/

#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif

/* Generic library information */
#define ACA1221NAME     "ACA1221.library"
#define ACA1221VERSION  2

/* Card's speed stepping capabilities */
#define ACA1221MAXSTEP  3
#define ACA1221MINSTEP  0        

/*-----------------------------------------------------------------------
 ClockInfo structure

 A pointer to this  structure is returned by ACA1221.library upon call 
 on GetCurrentSpeed() and GetMaxSpeed()
 It`s READ-ONLY!
 */

struct ClockInfo {
    STRPTR	ci_CPUClock;		/* current/max CPU clock */
    UWORD	ci_CPUSpeedStep;	/* current/max CPU speed stepping */	
};

/*-----------------------------------------------------------------------
 ACA1221Info structure

 A pointer to this structure is returned by ACA1221.library upon call 
 on ACA1221_GetStatus()
 It`s READ-ONLY!
 */

struct ACA1221Info {
	BOOL	ai_MapROM;					/* MapROM status bit. TRUE, if enabled */
	struct	ClockInfo *ai_ClockInfo;	/* pointer to clock speed info */
	struct	ClockInfo *ai_ClockMax;		/* pointer to max clock speed info */
	BOOL	ai_NoMemcard;				/* Switches off card's fast memory. */
										/* TRUE, if enabled */
	BOOL	ai_NoC0Mem;					/* TRUE, if SlowRAM is disabled */						
	ULONG	ai_Serial;					/* copy of Autoconf[tm] serial, */
										/* equals rounded down version */
										/* of card's maximum clock frequency */
	BOOL	ai_CurrentCPU;				/* the CPU currently in use (either */
										/* 0 = 68EC020 or 1 = 68020 */
	BOOL	ai_Overdrive;				/* Overdrive setting available? */
	BOOL	ai_TrialJumper;				/* Trial jumper set? */
	BOOL	ai_UnlockJumper;			/* Unlock jumper set? */
	UWORD	ai_Trials;					/* Number of trials left */
	ULONG	ai_Version;					/* firmware version */
	UBYTE	ai_MemSize;					/* licensed/available memory on card */
};


#endif /* LIBRARIES_ACA1221_H */

