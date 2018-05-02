#ifndef CLIB_ACA1221_PROTOS_H
#define CLIB_ACA1221_PROTOS_H

/*
**      $VER: ACA1221_protos.h 2.0 (05.05.2017)
**
**      ACA1221.library proto types
**
**		(C)2015-2017 by Marcus Gerards
**      All Rights Reserved.
*/

#include <libraries/ACA1221.h>

/* ACA1221 protos */

struct ClockInfo *ACA1221_GetCurrentSpeed(void);
struct ClockInfo *ACA1221_GetMaxSpeed(void);
BOOL ACA1221_SetSpeed(UBYTE);
BOOL ACA1221_MapROM(STRPTR, LONG);
struct ACA1221Info *ACA1221_GetStatus(void);

#endif	/* CLIB_ACA1221_PROTOS_H */
