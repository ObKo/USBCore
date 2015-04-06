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

#ifndef SPI_FLAHSER_H
#define SPI_FLAHSER_H

#include <stdint.h>
#include <libusb.h>

#define USB_CTL_TYPE        0x40

#define USB_TIMEOUT         1000

#define REQ_TYPE_WRITE      0x00
#define REQ_TYPE_READ       0x01
#define REQ_TYPE_PAGE_WRITE 0x02
#define REQ_TYPE_PAGE_READ  0x03

#define REQ_COMMAND         0x04
#define REQ_PROGRAM         0x05
#define REQ_READ            0x06

int flash_command(libusb_device_handle* dev, uint8_t direction, uint8_t command, uint8_t *data, int length);
int flash_wait(libusb_device_handle* dev);
int flash_write_enable(libusb_device_handle* dev);

int flash_erase_sector(libusb_device_handle* dev, uint8_t sector_addr);
int flash_write_data(libusb_device_handle* dev, uint32_t address, uint8_t *data, int length);
int flash_program(libusb_device_handle* dev, uint32_t address, uint8_t *data, int length);

int flash_read_page(libusb_device_handle* dev, uint32_t address, uint8_t *data);
int flash_read(libusb_device_handle* dev, uint32_t address, uint8_t *data, int length);

#endif