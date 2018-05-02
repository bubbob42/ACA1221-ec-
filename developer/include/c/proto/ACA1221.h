#ifndef _PROTO_ACA1221_H
#define _PROTO_ACA1221_H

#ifndef EXEC_TYPES_H
#include <exec/types.h>
#endif
#if !defined(CLIB_ACA1221_PROTOS_H) && !defined(__GNUC__)
#include <clib/aca1221_protos.h>
#endif

#ifndef __NOLIBBASE__
extern struct Library *ACA1221Base;
#endif

#ifdef __GNUC__
#include <inline/aca1221.h>
#elif !defined(__VBCC__)
#include <pragma/aca1221_lib.h>
#endif

#endif	/*  _PROTO_ACA1221_H  */
