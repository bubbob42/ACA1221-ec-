/*   ACAMapROM
 *
 *   a tool to access the MapROM feature of the 
 *   ACA1221(EC) & ACA1233n cards via 
 *   A1221.library & ACA1233n.library
 *
 *   generates proper AmigaDOS return codes
 *   for scripting
 *
 *   Marcus Gerards, 2016-2017
 */

#include <stdlib.h>
#include <exec/types.h>
#include <proto/exec.h>
#include <dos/dos.h>
#include <proto/dos.h>
#include <libraries/ACA1221.h>
#include <proto/ACA1221.h>
#include <libraries/ACA1233n.h>
#include <proto/ACA1233n.h>


/* Version information */
char VersionString[] ="$VER: ACAMapROM 1.2 "__AMIGADATE__;

struct Library *DosBase;
struct Library *ACA1221Base;
struct Library *ACA1233nBase;

/* Variables & pointers for the command line */
const char *const *arg_pointer;
struct RDArgs *rda;
LONG *argvalues[4];
int retval = 0;

/* the command template */
#define ARGS "Q=QUIET/S,FILE,I=MAPINT/S,R=MAPREMOVE/S"

/* return variables/pointers for the ACA libraries */
BOOL success;   /* return value for the MapROM functions */

BPTR fh = 0L;   /* file handle for custom ROM */

/* protos */
void Terminate(int);

/* Here we go */
int main(argc,argv)      
    int argc;
    char **argv; 
{
    struct ACA1233Info *ACA1233Info = NULL;
    struct ACA1221Info *ACA1221Info = NULL;
    
    argvalues[0]=argvalues[1]=argvalues[2]=argvalues[3] = NULL;
 
    /* this program is >OS 2.0 only, sorry */
    DosBase     = (struct Library *) OpenLibrary(DOSNAME,37L);   
    ACA1221Base = (struct Library *) OpenLibrary(ACA1221NAME,0L);
    ACA1233nBase = (struct Library *) OpenLibrary(ACA1233nNAME,0L);
    
    if ( DosBase && (ACA1221Base || ACA1233nBase) ) {
        
        if (ACA1221Base) {
            ACA1221Info = ACA1221_GetStatus();
        }
        else {
            ACA1233Info = ACA1233_GetStatus();
        }
        
        if ( (rda = ReadArgs(ARGS, (LONG *) argvalues, NULL)) != NULL ) {
            if (argvalues[3]) {
                /* remove mapped ROM */
                if (ACA1221Base) {
                    if (ACA1221Info->ai_MapROM) {
                        success = ACA1221_MapROM(NULL,AR_MAPREMOVE);
                    }
                    else {
                        if (!(argvalues[0])) Printf("MapROM not active, exiting.\n");
                        Terminate(RETURN_WARN);
                    }
                }
                else {
                    if (ACA1233Info->ai_MapROM) {
                        success = ACA1233_MapROM(NULL,AR_MAPREMOVE);
                    }
                    else {
                        if (!(argvalues[0])) Printf("MapROM not active, exiting.\n");
                        Terminate(RETURN_WARN);
                    }

                    /* we'll never reach this point with the 1221s... */
                    if (success) {
                        if (!(argvalues[0])) Printf("Successfully switched back to internal ROM.\n");
                        Terminate(RETURN_OK);
                    }
                    else {
                        Printf("Error! Unable to switch back to internal Kickstart ROM!\n");
                        Terminate(RETURN_ERROR);
                    }
                }
            }
            else if (argvalues[2]) {
                /* map internal ROM */
                if (ACA1221Base) {
                    if (ACA1221Info->ai_MapROM) {
                        if (!(argvalues[0])) Printf("MapROM already active, exiting.\n");
                        Terminate(RETURN_WARN);
                    }
                    else {
                        success = ACA1221_MapROM(NULL, AR_MAPINT);
                    }
                }
                else {
                    if (ACA1233Info->ai_MapROM) {
                        if (!(argvalues[0])) Printf("MapROM already active, exiting.\n");
                        Terminate(RETURN_WARN);
                    }
                    else {
                        success = ACA1233_MapROM(NULL, AR_MAPINT);
                    }

                    if (success) {
                        if (!(argvalues[0])) Printf("Successfully mapped internal ROM to MapROM space.\n");
                        Terminate(RETURN_OK);
                    }
                    else {
                        Printf("Error! Unable to map internal Kickstart ROM to MapROM space!\n");
                        Terminate(RETURN_ERROR);
                    }
                }
            }

            else if (argvalues[1]) {
                /* kick custom kickstart */
               
                if ( (fh = Open((STRPTR) argvalues[1], MODE_OLDFILE) ) ) {

                    if (ACA1221Base) {
                        if (ACA1221Info->ai_MapROM) {
                            if (!(argvalues[0])) Printf("MapROM already active, exiting.\n");
                            Terminate(RETURN_WARN);
                        }
                        else {
                            success = ACA1221_MapROM((STRPTR) argvalues[1], 0); 
                        }
                    }
                    else {
                        if (ACA1233Info->ai_MapROM) {
                            if (!(argvalues[0])) Printf("MapROM already active, exiting.\n");
                            Terminate(RETURN_WARN);
                        }
                        else {
                            success = ACA1233_MapROM((STRPTR) argvalues[1], 0);
                        }
                            
                        /* no "else" needed here, since a successfully 
                           kicked ROM file will always cause an immediate reboot 
                        */
                        if (!(success)) {
                                
                            Printf("Error! Unable to map ROM from file - is it really a valid ROM?\n");
                            Terminate(RETURN_ERROR);
                        }
                    }
                }
                else {
                    Printf("Unable to open file!\n");
                        
                    Terminate(RETURN_ERROR);
                }
            }
            else {
                Printf("No arguments supplied.Call \"ACAMapROM ?\" for options.\n");
                    
                Terminate(RETURN_WARN);
            }
        }
        else {
            PrintFault(IoErr(), NULL);
         
            Terminate(RETURN_FAIL);
        }
    }
    else {
        if ( (ACA1221Base == NULL) && (ACA1233nBase == NULL)) {
            Printf("Cannot open ACA1221.library or ACA1233n.library!\n");
        }
        Terminate(RETURN_FAIL);
    }
}

void Terminate(int retval) {
    
    if (rda) {
        FreeArgs(rda);
    }

    if (DosBase != NULL) CloseLibrary((struct Library *) DosBase);  
    if (ACA1221Base != NULL) CloseLibrary((struct Library *) ACA1221Base); 
    if (ACA1233nBase != NULL) CloseLibrary((struct Library *) ACA1233nBase); 
    
    exit(retval);
}
