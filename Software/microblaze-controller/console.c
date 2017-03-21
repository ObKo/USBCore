#include "console.h"

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdint.h>

extern char inbyte(void);
extern void outbyte (char c);

int parseLine(char *line, char *buffer, size_t bufLen, char *(*tokens)[], size_t maxTokens)
{
    int bufI = 0, tI = 0;
    char *ptr = line;

    while (*ptr != '\0')
    {
        if (isblank(*ptr))
        {
            ptr++;
            continue;
        }
        int start = bufI;
        while (*ptr && !isblank(*ptr) && (bufI < bufLen - 1))
        {
            buffer[bufI] = *ptr;
            bufI++;
            ptr++;
        }
        buffer[bufI] = '\0';
        bufI++;

        if (tI < maxTokens)
        {
            (*tokens)[tI] = buffer + start;
            tI++;
        }
    }
    (*tokens)[tI] = NULL;

    return tI;
}

static void getLine(char *line, size_t length)
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

void consoleInit(struct Console *cp, struct ConsoleCommand *commands)
{
    cp->lineBuffer = malloc(CONSOLE_MAX_LINE_SIZE);
    cp->parserBuffer = malloc(CONSOLE_MAX_LINE_SIZE + CONSOLE_MAX_TOKENS);
    cp->commands = commands;
}

int consoleGetCommand(struct Console *cp)
{
    getLine(cp->lineBuffer, CONSOLE_MAX_LINE_SIZE);
    return parseLine(cp->lineBuffer, cp->parserBuffer, CONSOLE_MAX_LINE_SIZE + CONSOLE_MAX_TOKENS,
                     &cp->argv, CONSOLE_MAX_TOKENS);
}

void consoleInteract(struct Console *cp)
{
    for(;;)
    {
        print("USBCore> ");
        int argc = consoleGetCommand(cp);

        if (argc < 1)
            continue;

        if (!strcmp(cp->argv[0], "exit"))
        {
            print("Goodbye!\r\n");
            break;
        }

        if (!cp->commands)
            continue;

        struct ConsoleCommand *cmd = cp->commands;

        while (cmd->cmd && cmd->func)
        {
            if (!strcmp(cp->argv[0], cmd->cmd))
            {
                cmd->func(argc, cp->argv);
                break;
            }
        }
        if (!cmd->cmd || !cmd->func)
        {
            print("Unknown command: "); print(cp->argv[0]); print("\r\n");
        }
    }
}

void consoleFree(struct Console *cp)
{
    free(cp->lineBuffer);
    free(cp->parserBuffer);
}
