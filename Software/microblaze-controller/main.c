#include <stdio.h>
#include <xparameters.h>
#include <xil_cache.h>
#include <xil_printf.h>
#include <strings.h>
#include <stdlib.h>

extern char8 inbyte(void);
extern void outbyte (char8 c);

void getLine(char *line, size_t length)
{
    char c = ' ';
    int i = 0;

    while (c != '\r')
    {
        c = inbyte();

        if (c == '\t')
            c = ' ';
        else if (c == 0x1B)
            c = '^';

        outbyte(c);

        if (c == 0x7F)
        {
            if (i > 0)
            {
                i--;
                outbyte(0x08);
                outbyte(' ');
                outbyte(0x08);
            }
        }
        else if (i < length)
        {
            line[i] = c;
            i++;
        }
    }
    outbyte('\n');
    line[i - 1] = '\0';
}

void trim(char *str)
{
    if (!str)
        return;

    int from = 0;
    int to = strlen(str);

    if (from == to)
        return;

    while((from != to) && isblank(str[from])/* (str[from] == ' ') || (str[from] == '\t'))*/)
        from++;

    while((from != to) && ((str[to - 1] == ' ') || (str[to - 1] == '\t')))
        to--;

    if (from == to)
        str[0] = '\0';

    for(int i = 0; i < (to - from); i++)
        str[i] = str[from + i];

    str[(to - from)] = '\0';
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

    char *mainLine = malloc(1024);

    for(;;)
    {
        print("USBCore> ");
        getLine(mainLine, 1024);
        trim(mainLine);
        print(mainLine);
        print("\r\n");
    }
    
    Xil_DCacheDisable();
    Xil_ICacheDisable();
    return 0;
}
