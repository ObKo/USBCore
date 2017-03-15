#include "console.h"

#include <stdlib.h>
#include <strings.h>
#include <ctype.h>
#include <stdint.h>

extern char inbyte(void);
extern void outbyte (char c);

void parseLine(char *line, char *buffer, size_t bufLen, char *(*(*tokens)), size_t maxTokens)
{
    int bufI = 0;
    char *ptr = line;
    char** tokenPtr = *tokens;

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

        if (tokenPtr < *tokens + maxTokens - 1)
        {
            *tokenPtr = buffer + start;
            tokenPtr++;
        }
    }
    *tokenPtr = NULL;
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
#define CONSOLE_MAX_LINE_SIZE   1024
#define CONSOLE_MAX_TOKENS      32

void consoleInit(struct Console *cp)
{
    cp->lineBuffer = malloc(CONSOLE_MAX_LINE_SIZE);
    cp->parserBuffer = malloc(CONSOLE_MAX_LINE_SIZE + CONSOLE_MAX_TOKENS);
    cp->tokens = malloc(CONSOLE_MAX_TOKENS * sizeof(char*));

}

char **consoleGetCommand(struct Console *cp)
{
    getLine(cp->lineBuffer, CONSOLE_MAX_LINE_SIZE);
    parseLine(cp->lineBuffer, cp->parserBuffer, CONSOLE_MAX_LINE_SIZE + CONSOLE_MAX_TOKENS,
              &cp->tokens, CONSOLE_MAX_TOKENS);
    return cp->tokens;
}

void consoleFree(struct Console *cp)
{
    free(cp->lineBuffer);
    free(cp->parserBuffer);
    free(cp->tokens);
}
