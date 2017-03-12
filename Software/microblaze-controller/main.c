#include <stdio.h>
#include <xparameters.h>
#include <xil_cache.h>

extern char8 inbyte(void);
extern void outbyte (char8 c);
static char cmd[256];

void getCommand()
{
    char c = ' ';
    int i = 0;

    print("USBCore> ");

    while (c != '\r')
    {
        c = inbyte();
        outbyte(c);

        if (i < 256)
        {
            cmd[i] = c;
            i++;
        }
    }
    cmd[i] = '\0';

    outbyte('\n'); outbyte('\r');

    print(cmd);

    outbyte('\n'); outbyte('\r');
}

int main()
{
#ifdef XPAR_MICROBLAZE_USE_ICACHE
    Xil_ICacheEnable();
#endif
#ifdef XPAR_MICROBLAZE_USE_DCACHE
    Xil_DCacheEnable();
#endif
    print("Welcome to USBCore software!\n\r");
    
    for(;;)
    {
        getCommand();
    }
    
    Xil_DCacheDisable();
    Xil_ICacheDisable();
    return 0;
}
