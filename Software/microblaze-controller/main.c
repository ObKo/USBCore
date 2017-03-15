#include <stdio.h>
#include <xparameters.h>
#include <xil_cache.h>
#include <xil_printf.h>
#include "console.h"

int main()
{
#ifdef XPAR_MICROBLAZE_USE_ICACHE
    Xil_ICacheEnable();
#endif
#ifdef XPAR_MICROBLAZE_USE_DCACHE
    Xil_DCacheEnable();
#endif
    print("Welcome to USBCore software!\n\r");

    struct Console con;

    consoleInit(&con);

    for(;;)
    {
        print("USBCore> ");
        char **t = consoleGetCommand(&con);
        while (*t)
        {
            print(*t); print(";");
            t++;
        }
        print("\r\n");
    }

    consoleFree(&con);
    
    Xil_DCacheDisable();
    Xil_ICacheDisable();
    return 0;
}
