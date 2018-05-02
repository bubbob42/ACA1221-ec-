/*  ACAGov
 *   a short program showing load-depended control of CPU 
 *   clock via ACA1221.library's speed stepping functions
 *   
 *   GetUsage() has been picked from the DOpus4/XOper sources
 *   
 *   generates proper ADOS returncodes for scripting
 * 
 *   Marcus Gerards, 2015
 */

#define __USE_SYSBASE 1
#include <exec/types.h>
#include <exec/exec.h>
#include <proto/exec.h>
#include <dos/dos.h>
#include <proto/dos.h>
#include <libraries/ACA1221.h>
#include <proto/ACA1221.h>
#include <devices/timer.h>


/* Version information */
char VersionString[] ="$VER: ACAGov 1.0 "__AMIGADATE__;


/* Library bases */
struct DOSBase          *DosBase       = NULL;
struct Library          *ACA1221Base   = NULL;
struct Device           *TimerBase     = NULL;


/* Variables & pointers for the command line */
const char *const *arg_pointer;
struct RDArgs *rda;
LONG *argvalues[8];
int retval = 0;

/* the command template */
#define ARGS "Q=QUIET/S,A=AUTOCLOCK/S,UT=UPPERTHRESHOLD/K/N,LT=LOWERTHRESHOLD/K/N,I=INTERVAL/K/N,MAX=MAXSTEP/K/N,MIN=MINSTEP/K/N,E=EXIT/S"

/* Timer port & stuff */
struct MsgPort *TimePort;
struct timerequest *TimeRequest;


/* return variables/pointers for ACA1221.library */
BOOL speedSuccess;                      /* return value for SetSpeed */
struct ClockInfo *ACAMaxSpeed = NULL;   /* pointer to max speed stepping/clock data structure of the lib */
struct ClockInfo *ACASpeed = NULL;      /* pointer to current speed stepping/clock data structure of the lib */

/* some globals for the CPU governor */
BOOL ag_NoOutput = FALSE;
BOOL ag_AutoClock = FALSE;
ULONG ag_UpperThreshold = 70;
ULONG ag_LowerThreshold = 50;
ULONG ag_Interval = 200; /* default interval = 200 milliseconds */
ULONG ag_MaxStep = ACA1221MAXSTEP; /* 3 */
ULONG ag_MinStep = ACA1221MINSTEP; /* 0 */

/* ASM routines */
extern ULONG __regargs __asm GetUsage( void );

/* Prototypes */
BOOL SetupTimerRequest(VOID);
VOID ACAGov(VOID);


/* Here we go */
int main(argc,argv)      
    int argc;
    char **argv; 
{
    /* this is for terminating the main loop */
    BOOL terminate = FALSE;
    
    /* we need a MessagePort in case we get started twice */
    struct MsgPort *mport       = NULL;
    
    argvalues[0]=argvalues[1]=argvalues[2]=argvalues[3]=argvalues[4]=argvalues[5]=argvalues[6]=argvalues[7] = NULL;
 
    /* open libraries - this program is >OS 2.0 only, sorry */
    DOSBase     = (struct DosLibrary *) OpenLibrary(DOSNAME,37L);   
    ACA1221Base = (struct Library *) OpenLibrary(ACA1221NAME,0L);

    if (DOSBase && ACA1221Base && (argc != 0)) {
        
        /* let's check if we are already running... */
        Forbid();
        
        if ((mport = FindPort("ACAGov"))) {
            Signal(mport->mp_SigTask, SIGBREAKF_CTRL_C);
            Permit();
            mport = NULL;
            Printf("Already running - stopping ACAGov\n");
        }
        else {
            Permit();
            mport = CreateMsgPort();
            mport->mp_Node.ln_Name = "ACAGov";
            mport->mp_Node.ln_Pri = 1L;
            
            AddPort(mport);
            
            if ((rda = ReadArgs(ARGS, (LONG *) argvalues, NULL)) != NULL) {
            
                /* store the arguments for better readablility & checking */
                if (argvalues[0]) ag_NoOutput       = TRUE;
                if (argvalues[1]) ag_AutoClock      = TRUE;
                if (argvalues[2]) ag_UpperThreshold = *argvalues[2];
                if (argvalues[3]) ag_LowerThreshold = *argvalues[3];
                if (argvalues[4]) ag_Interval       = *argvalues[4];
                
                /* user calls for EXIT, so we clean up immediatly */
                if (argvalues[7]) {
                    FreeArgs(rda);
                    goto cleanup; /* remember BASIC? It's bad here, too. */
                }
            
                /* determine max speed stepping value */
                ACAMaxSpeed = GetMaxSpeed();
            
                /* check if user's MaxStep value is valid for this card */
                if (argvalues[5]) {
                    if ((*argvalues[5] > ag_MaxStep) || (*argvalues[5] > ACAMaxSpeed->ci_CPUSpeedStep)) {
                        Printf("Your selected speed stepping value is too large. This card is licensed for speed stepping %ld (%s)\n",
                                ACAMaxSpeed->ci_CPUSpeedStep, ACAMaxSpeed->ci_CPUClock); 
                    } else {
                        if (*argvalues[5] < ACA1221MINSTEP+1) {
                            Printf("MAXSTEP must be at least step %ld for the governor to work properly! Setting MAXSTEP to %ld.\n",
                                 ACA1221MINSTEP+1);
                            ag_MaxStep = 1;
                        } else {
                             ag_MaxStep = *argvalues[5];
                        }
                    }
                }

                /* user supplied both MinStep & MaxStep values? 
                    let's see if they will fit together */
                if ((argvalues[5]) && (argvalues[6])) {
                    if (*argvalues[6] >= *argvalues[5]) {
                        Printf("MINSTEP *must* be smaller than MAXSTEP! Setting MINSTEP to 0\n");
                    } else {
                        ag_MinStep = *argvalues[6];
                    }
                }
            
                /* at last check if MinStep is valid */
                if (argvalues[6]) {
                    if ((*argvalues[6] < ACA1221MINSTEP) || (*argvalues[6] > ACA1221MAXSTEP-1)) {
                        Printf("MINSTEP must be at least 0 and not greater than 2 for the governor to work properly! Setting MINSTEP to 0.\n");
                    } else {
                        ag_MinStep = *argvalues[6];
                    }
                }
                
                /* check for bad threshold combos */
                if (ag_UpperThreshold <= ag_LowerThreshold) {
                    ag_UpperThreshold = 80;
                    ag_LowerThreshold = 50;
                
                    Printf("Supplied thresholds make no sense resetting to default!\n");
                    Printf("Lower threshold: %ld - UpperThreshold: %ld\n", 
                                    ag_UpperThreshold, ag_LowerThreshold);
                }
        
                /* fire up the timer */
                if (SetupTimerRequest()) {
            
                    ULONG timer_mask;
                    ULONG signal_mask;
                    ULONG signals;

	            timer_mask = 1L << TimePort->mp_SigBit;

                    /* we want to get a signal at ctrl-c or every second */
	            signal_mask = SIGBREAKF_CTRL_C | timer_mask;
	            signals = 0;

	            TimeRequest->tr_node.io_Command	= TR_ADDREQUEST;
	            TimeRequest->tr_time.tv_secs	= 0;
                    /* user input is measured in 1/1000 s */
	            TimeRequest->tr_time.tv_micro	= ag_Interval;

	            SendIO((struct IORequest *)TimeRequest);

                    /* this is the main loop */
                    while (!(terminate)) {           /* exit by setting terminate   */
                        if (signals == 0) {
                            /* wait for our signals */
                            signals = Wait(signal_mask);
                        }
                        else {
                            signals |= SetSignal(0,signal_mask) & signal_mask;
                        }
                        /* we got a signal from timer.device */                
                        if (signals & timer_mask) {
                            if (GetMsg(TimePort) != NULL) {
                                WaitIO((struct IORequest *)TimeRequest);
                        
                                /* call our little main routine */
                                ACAGov();
                        
                                /* and renew the timer request */
                                TimeRequest->tr_node.io_Command	= TR_ADDREQUEST;
                                TimeRequest->tr_time.tv_secs	= 0;
                                TimeRequest->tr_time.tv_micro	= ag_Interval * 1000;
                        
                                SendIO((struct IORequest *)TimeRequest);
                            }
                            signals &= ~timer_mask;
                        }
                
                        /* we exit by pressing ctrl-c */
                        if(signals & SIGBREAKF_CTRL_C) {
                            terminate = TRUE;
                            signals &= ~SIGBREAKF_CTRL_C;
                        }
                    }
            
                    /* abort and wait for pending device requests */
                    if (CheckIO((struct IORequest *)TimeRequest) == NULL) {
                         AbortIO((struct IORequest *)TimeRequest);
                    }
                    WaitIO((struct IORequest *)TimeRequest);
                }
                FreeArgs(rda);
            } else {
                PrintFault(IoErr(), NULL);
                retval = 20;
            }
        }
    } else {
        /* something went wrong */
        if (ACA1221Base == NULL) {
            Printf("Cannot open ACA1221.library!\n");
        }
        if (argc == 0) {        /* start from Workbench? We don't like it... */
            BPTR output;
            BPTR old_output;
            
            if ((output = Open("CON:0/0//100/Error!/WAIT/CLOSE",MODE_NEWFILE))) {
                old_output = SelectOutput(output);
                Printf("ACAGov runs from CLI/shell only!\n\n");
                                
                SelectOutput(old_output);
                Close(output);
            }
        }
        else Printf ("Unable to open one or more system libraries!\n");
        retval = 20;
    }

    /* Cleanup stuff */
cleanup:

    if (TimeRequest != NULL) {
        if (TimeRequest->tr_node.io_Device != NULL) {
            CloseDevice((struct IORequest *)TimeRequest);
        }
        
	DeleteIORequest((struct IORequest *)TimeRequest);
	TimeRequest = NULL;
    }
    
    if (TimePort != NULL) {
        DeleteMsgPort(TimePort);
	TimePort = NULL;
    }
    
    if (mport != NULL) {
        if ((FindPort("ACAGov"))) {
            RemPort(mport);
        }
        DeleteMsgPort(mport);
    }
   
    if (DosBase)        CloseLibrary((struct Library *) DosBase);  
    if (ACA1221Base)    CloseLibrary((struct Library *) ACA1221Base);
 
    return (retval);
}

/*
        This is our little CPU speed governor
*/ 
VOID ACAGov(VOID)
{
    /* determine current CPULoad */
    ULONG CPULoad = GetUsage()/10;
    BOOL stepChange;
    
    /* and current ACASpeedStep */
    ACASpeed = GetCurrentSpeed();
    
    /* output the current situation, if QUIET is not set */
    if (!(ag_NoOutput)) {
        Printf("CPU Load: %ld% ACA SpeedStepping: %ld ", 
                    CPULoad, ACASpeed->ci_CPUSpeedStep);
    }

    /* very primitive CPU governor coming up here 
       we increase speed stepping by 1 if CPULoad is > 50% */
    
    if (ag_AutoClock) {
        if ((CPULoad > ag_UpperThreshold) && (ACASpeed->ci_CPUSpeedStep < ag_MaxStep)) {
            Forbid();
            if ((stepChange = SetSpeed(ACASpeed->ci_CPUSpeedStep + 1))) {
                if (!(ag_NoOutput)) Printf("Increasing speed!\n");
            } else {
                Permit();
                Printf("Failed to increase speed stepping!\n");
            }
            Permit();
        }
        /* and decrease speed stepping by 1 if CPULoad < 40% */ 
        else if ((CPULoad < ag_LowerThreshold) && (ACASpeed->ci_CPUSpeedStep > ag_MinStep)) {
            Forbid();
            if ((stepChange = SetSpeed(ACASpeed->ci_CPUSpeedStep - 1))) {
                if (!(ag_NoOutput)) Printf("Decreasing speed!\n");
            } else {
                Permit();
                Printf("Failed to decrease speed stepping!\n");
            }
            Permit();
        }
        else {
            if (!(ag_NoOutput)) Printf("No speed change.\n");
        }
    }
    else {
        if (!(ag_NoOutput)) Printf("\n");
    }
    return;
}

BOOL SetupTimerRequest(VOID) {
    
    TimePort = CreateMsgPort();
    
    if(TimePort == NULL) {
        Printf("Could not create timer message port.\n");
        return FALSE;
    } else {
        TimeRequest = (struct timerequest *)CreateIORequest(TimePort,sizeof(*TimeRequest));
        
	if(TimeRequest == NULL) {
            Printf("Could not create timer I/O request.\n");
            return FALSE;
	} else {
            if(OpenDevice(TIMERNAME,UNIT_VBLANK,(struct IORequest *)TimeRequest,0) != 0) {
                Printf("Could not open 'timer.device'.\n");
                return FALSE;
            } else {
                TimerBase = TimeRequest->tr_node.io_Device;
            }
        }
    }
    return TRUE;
}
