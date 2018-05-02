#ifndef _INLINE_ACA1221_H
#define _INLINE_ACA1221_H

#ifndef CLIB_ACA1221_PROTOS_H
#define CLIB_ACA1221_PROTOS_H
#endif

#ifndef __INLINE_MACROS_H
#include <inline/macros.h>
#endif

#ifndef  LIBRARIES_ACA1221_H
#include <libraries/ACA1221.h>
#endif

#ifndef ACA1221_BASE_NAME
#define ACA1221_BASE_NAME ACA1221Base
#endif

#define ACA1221_GetCurrentSpeed() \
	LP0(0x1e, struct ClockInfo *, ACA1221_GetCurrentSpeed, \
	, ACA1221_BASE_NAME)

#define ACA1221_GetMaxSpeed() \
	LP0(0x24, struct ClockInfo *, ACA1221_GetMaxSpeed, \
	, ACA1221_BASE_NAME)

#define ACA1221_SetSpeed(SpeedStep) \
	LP1(0x2a, BOOL, ACA1221_SetSpeed, UBYTE, SpeedStep, d0, \
	, ACA1221_BASE_NAME)

#define ACA1221_MapROM(file, option) \
	LP2(0x30, BOOL, ACA1221_MapROM, STRPTR, file, d0, LONG, option, d1, \
	, ACA1221_BASE_NAME)

#define ACA1221_GetStatus() \
	LP0(0x36, struct ACA1221Info *, ACA1221_GetStatus, \
	, ACA1221_BASE_NAME)

#endif /*  _INLINE_ACA1221_H  */
