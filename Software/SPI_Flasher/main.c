/*
 * USB Full-Speed/Hi-Speed Device Controller core - SPI Flasher Utility
 *
 * Copyright (c) 2015 Konstantin Oblaukhov
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#include "spi_flasher.h"

#include <libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>

int main(int argc, char **argv)
{
    if (argc < 3)
    {
        printf("Usage: spi_flasher [options] <file>\n");
        printf("Options are:\n");
        printf("  -r: read flash content\n");
        printf("  -w: program flash\n");
        printf("  -a <addr>: start address of flash\n");
        printf("  -s <size>: read/write size\n");
        printf("  -e <vid>: device vendor id (in HEX)\n");
        printf("  -p <pid>: device product id (in HEX)\n");
        printf("  -f: don't verify flash content after writing\n");
        printf("  -v: verbose output\n");
        return 0;
    }

    char opt;

    char cmd = 0;
    uint32_t addr = 0;
    int size = 0;
    uint16_t vid = 0xdead, pid = 0xbeef;
    int force = 0;
    int verbose = 0;

    while ((opt = getopt(argc, argv, "rwa:s:e:p:fv")) != -1)
    {
        switch (opt)
        {
        case 'r':
            cmd = 'r';
            break;
        case 'w':
            cmd = 'w';
            break;
        case 'a':
            addr = strtol(optarg, NULL, 0);
            break;
        case 's':
            size = strtol(optarg, NULL, 0);
            break;
        case 'e':
            vid = strtol(optarg, NULL, 16);
            break;
        case 'p':
            pid = strtol(optarg, NULL, 16);
            break;
        case 'f':
            force = 1;
            break;
        case 'v':
            verbose = 1;
            break;
        }
    }

    if (!cmd)
    {
        printf("Please specify command (-r or -w)");
        return 0;
    }

    if (optind >= argc)
    {
        printf("Please specify file");
        return 0;
    }

    libusb_context *usb;
    libusb_init(&usb);

    libusb_device_handle* dev;
    dev = libusb_open_device_with_vid_pid(usb, vid, pid);

    if (!dev)
    {
        printf("Cannot open usb device\n");
        return -1;
    }

    int ret;

    if (cmd == 'w')
    {
        FILE *inf = fopen(argv[optind], "rb");
        if (!inf)
        {
            printf("Cannot open input file\n");
            return -1;
        }

        if (!size)
        {
            fseek(inf, 0, SEEK_END);
            size = ftell(inf);
            fseek(inf, 0, SEEK_SET);
        }

        uint8_t *data = malloc(size);

        ret = fread(data, size, 1, inf);
        if (ret != 1)
        {
            printf("Cannot read input file\n");
            free(data);
            fclose(inf);
            return -1;
        }
        fclose(inf);

        printf("Programming flash (%d sectors, %d pages)...\n", ((size - 1) >> 16) + 1, ((size - 1) >> 8) + 1);
        if ((ret = flash_program(dev, addr, data, size)) != 0)
        {
            printf("Cannot program flash: %s\n", libusb_error_name(ret));
            free(data);
            return -1;
        }

        if (!force)
        {
            uint8_t *rdata = malloc(size);

            printf("Reading data from flash...\n");
            if ((ret = flash_read(dev, addr, rdata, size)) != 0)
            {
                printf("Cannot read flash: %s\n", libusb_error_name(ret));
                free(rdata);
                free(data);
                return -1;
            }

            int i;

            printf("Compare...\n");
            for (i = 0; i < size; i++)
            {
                if (data[i] != rdata[i])
                {
                    printf("Flash compare error at 0x%x: 0x%x != 0x%x\n", i, data[i], rdata[i]);
                    free(rdata);
                    free(data);
                    return -1;
                }
            }
            free(rdata);
        }
        free(data);
    }
    else
    {
        if (!size)
        {
            printf("Please specify size for reading\n");
            return 0;
        }

        uint8_t *data = malloc(size);

        printf("Reading data from flash (%d pages)...\n", ((size - 1) >> 8) + 1);
        if ((ret = flash_read(dev, addr, data, size)) != 0)
        {
            printf("Cannot read flash: %s\n", libusb_error_name(ret));
            free(data);
            return -1;
        }

        FILE *outf = fopen(argv[optind], "wb");
        if (!outf)
        {
            printf("Cannot open output file\n");
            return -1;
        }

        ret = fwrite(data, size, 1, outf);
        if (ret != 1)
        {
            printf("Cannot write to output file\n");
            free(data);
            fclose(outf);
            return -1;
        }

        free(data);
        fclose(outf);
    }
    printf("Done!\n");

    libusb_close(dev);
    libusb_exit(usb);
    return 0;
}
