/*  ACAClock
 *   a short program to demonstrate ACA1221.library's 
 *   speed stepping functions
 *
 *   generates proper AmigaDOS return codes
 *   for scripting
 *
 *   Marcus Gerards, 2015
 */

#include <exec/types.h>
#include <proto/exec.h>
#include <dos/dos.h>
#include <proto/dos.h>
#include <libraries/ACA1221.h>
#include <proto/ACA1221.h>

/* Version information */
char VersionString[] ="$VER: ACAClock 1.0 "__AMIGADATE__;

struct Library *DosBase;
struct Library *ACA1221Base;

/* Variables & pointers for the command line */
const char *const *arg_pointer;
struct RDArgs *rda;
LONG *argvalues[4];
int retval = 0;

/* the command template */
#define ARGS "Q=QUIET/S,M=MAXSPEED/S,C=CURRENTSPEED/S,S=SETSPEED/K/N"

/* return variables/pointers for ACA1221.library */
BOOL speedSuccess;                      /* return value for SetSpeed */
struct ClockInfo *ACAMaxSpeed = NULL;   /* pointer to max speed stepping/clock data structure of the lib */
struct ClockInfo *ACASpeed = NULL;      /* pointer to max speed stepping/clock data structure of the lib */

/* Here we go */
int main(argc,argv)      
    int argc;
    char **argv; 
{
    argvalues[0]=argvalues[1]=argvalues[2]=argvalues[3] = NULL;
 
    /* this program is >OS 2.0 only, sorry */
    DosBase     = (struct Library *) OpenLibrary(DOSNAME,37L);   
    ACA1221Base = (struct Library *) OpenLibrary(ACA1221NAME,0L);
    
    if (DosBase && ACA1221Base) {
        
        /* We always query the maximum speed stepping available first,
           so we'll be able to check if user's input is valid. We 
           should always get a return value here, because the library
           already checked an ACA1221 is present at this point.
        */
        ACAMaxSpeed = GetMaxSpeed();             

        if ((rda = ReadArgs(ARGS, (LONG *) argvalues, NULL)) != NULL) {
            
            /* MAXSPEED - user wants to check for the card's maximum clock */
            if (argvalues[1]) {
                /* output maximum speed licensed / available */
                if (!(argvalues[0])) {
                    Printf("Maximum speed stepping of this card is %ld (%s)\n", 
                                ACAMaxSpeed->ci_CPUSpeedStep, ACAMaxSpeed->ci_CPUClock);
                }
                retval = 0;
            }

            /* CHECKSPEED - user wants to check the card's current clock */
            if (argvalues[2]) {
                /* query current speed */
                ACASpeed = GetCurrentSpeed();
               
                if (!(argvalues[0])) {
                    Printf("Current speed stepping of this card is %ld (%s)\n", 
                                ACASpeed->ci_CPUSpeedStep, ACASpeed->ci_CPUClock);
                }
                retval = 0;
            }
            
            /* user wants to set the card's clock */
            if (argvalues[3]) {
                /* check if user supplied a valid speed step value */
                if ((*argvalues[3] >=0) && (*argvalues[3] < 4)) {
                    /* check if supplied speed step value is licensed */
                    if (*argvalues[3] <= ACAMaxSpeed->ci_CPUSpeedStep) {
                        /* if yes, set it */
                        if ((speedSuccess = SetSpeed(*argvalues[3]))) {
                            ACASpeed = GetCurrentSpeed();
                            if (!(argvalues[0])) {
                                Printf("Card is now set to speed step %ld (%s).\n",
                                           ACASpeed->ci_CPUSpeedStep, ACASpeed->ci_CPUClock);
                            }
                            retval = 0;
                        } else {
                            /* this should not happen */
                            if (!(argvalues[0])) {
                                Printf("Failed to set the card to speed step %ld.\n", argvalues[1]);
                            }
                            retval = 20; /* so we return FATAL ERROR */
                        }
                    } else {
                        if (!(argvalues[0])) {
                                Printf("Card is not licensed for speed step %ld.\n", argvalues[1]);
                        }
                        retval = 5;
                    }
                } else {
                    if (!(argvalues[0])) Printf("The supplied speed step value is invalid! Valid steps are 0,1,2 or 3!\n");
                    retval = 10;
                }
            }
            FreeArgs(rda);
        } else {
            PrintFault(IoErr(), NULL);
            retval = 20;
        }
    } else {
        if (DosBase == NULL) Printf("Cannot open dos.library V37+!\n");
        if (ACA1221Base == NULL) Printf("Cannot open ACA1221.library!\n");
        retval = 20;
    }
    if (DosBase != NULL) CloseLibrary((struct Library *) DosBase);  
    if (ACA1221Base != NULL) CloseLibrary((struct Library *) ACA1221Base); 
    return (retval);
}

