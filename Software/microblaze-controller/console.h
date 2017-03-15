#ifndef CONSOLE_H
#define CONSOLE_H

#include <stdio.h>

#define CONSOLE_MAX_LINE_SIZE   1024
#define CONSOLE_MAX_TOKENS      32

struct Console {
    char *lineBuffer;
    char *parserBuffer;
    char *(*tokens);
};

void consoleInit(struct Console *cp);
char **consoleGetCommand(struct Console *cp);
void consoleFree(struct Console *cp);

#endif
