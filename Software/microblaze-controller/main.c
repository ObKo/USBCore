#include <stdio.h>
#include <xparameters.h>
#include <xil_cache.h>
#include <xil_printf.h>
#include "console.h"
#include <stdlib.h>

void cmdEcho(int argc, char **argv)
{
    for (int i = 1; i < argc; i++)
    {
        print(argv[i]); print(" ");
    }
    print("\r\n");
}

void cmdDump(int argc, char **argv)
{
    if (argc != 3)
    {
        print("Usage: dump addr count\r\n");
        return;
    }
    uint32_t address = 0;
    uint32_t size = 0;

    char *end = argv[1] + strlen(argv[1]);
    address = strtoul(argv[1], &end, 0);

    end = argv[2] + strlen(argv[2]);
    size = strtoul(argv[2], &end, 0);

    if (!size)
        return;

    uint32_t endAddr = (address + size) - 1;

    uint32_t realStart = address & 0xFFFFFFF0;
    uint32_t realEnd = (((endAddr >> 4) + 1) << 4) - 1;

    for (uint32_t a = realStart; a <= realEnd; a+=16)
    {
        xil_printf("0x%08x: ", a);
        for (int i = 0; i < 16; i++)
        {
            if (((a + i) < address) || ((a + i) > endAddr))
                print("   ");
            else
                xil_printf("%02x ", ((uint8_t*)0)[a + i]);
        }
        printf("\r\n");
    }
}

struct ConsoleCommand commands[] = {
    {"dump", &cmdDump},
    {"echo", &cmdEcho},
    {NULL, NULL}
};

struct Console con;

int main()
{
#ifdef XPAR_MICROBLAZE_USE_ICACHE
    Xil_ICacheEnable();
#endif
#ifdef XPAR_MICROBLAZE_USE_DCACHE
    Xil_DCacheEnable();
#endif
    print("Welcome to USBCore software!\n\r");

    consoleInit(&con, commands);
    consoleInteract(&con);
    consoleFree(&con);
    
    Xil_DCacheDisable();
    Xil_ICacheDisable();
    return 0;
}
