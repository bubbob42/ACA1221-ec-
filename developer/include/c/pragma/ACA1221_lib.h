#ifndef _INCLUDE_PRAGMA_ACA1221_LIB_H
#define _INCLUDE_PRAGMA_ACA1221_LIB_H

#ifndef CLIB_ACA1221_PROTOS_H
#include <clib/aca1221_protos.h>
#endif

#if defined(AZTEC_C) || defined(__MAXON__) || defined(__STORM__)
#pragma amicall(ACA1221Base,0x01e,ACA1221_GetCurrentSpeed())
#pragma amicall(ACA1221Base,0x024,ACA1221_GetMaxSpeed())
#pragma amicall(ACA1221Base,0x02a,ACA1221_SetSpeed(d0))
#pragma amicall(ACA1221Base,0x030,ACA1221_MapROM(d0,d1))
#pragma amicall(ACA1221Base,0x036,ACA1221_GetStatus())
#endif
#if defined(_DCC) || defined(__SASC)
#pragma  libcall ACA1221Base ACA1221_GetCurrentSpeed 01e 00
#pragma  libcall ACA1221Base ACA1221_GetMaxSpeed    024 00
#pragma  libcall ACA1221Base ACA1221_SetSpeed       02a 001
#pragma  libcall ACA1221Base ACA1221_MapROM         030 1002
#pragma  libcall ACA1221Base ACA1221_GetStatus      036 00
#endif

#endif	/*  _INCLUDE_PRAGMA_ACA1221_LIB_H  */
