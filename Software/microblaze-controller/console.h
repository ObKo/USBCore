#ifndef CONSOLE_H
#define CONSOLE_H

#include <stdio.h>

#define CONSOLE_MAX_LINE_SIZE   1024
#define CONSOLE_MAX_TOKENS      32

struct ConsoleCommand {
    const char *cmd;
    void (*func)(int argc, char **argv);
};

struct Console {
    char *lineBuffer;
    char *parserBuffer;
    char *argv[CONSOLE_MAX_TOKENS];
    struct ConsoleCommand *commands;
};

void consoleInit(struct Console *cp, struct ConsoleCommand *commands);
int consoleGetCommand(struct Console *cp);
void consoleInteract(struct Console *cp);
void consoleFree(struct Console *cp);

#endif
