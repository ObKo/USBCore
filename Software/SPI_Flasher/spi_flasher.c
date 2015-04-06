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
#include "string.h"

int flash_command(libusb_device_handle* dev, uint8_t type, uint8_t command, uint8_t *data, int length)
{
    int res = -1;

    if (type == REQ_TYPE_PAGE_WRITE)
        res = libusb_control_transfer(dev, USB_CTL_TYPE, REQ_PROGRAM, command, 0x0000, data, length, USB_TIMEOUT);
    else if (type == REQ_TYPE_PAGE_READ)
        res = libusb_control_transfer(dev, USB_CTL_TYPE, REQ_READ, command, 0x0000, data, length, USB_TIMEOUT);
    else if (type == REQ_TYPE_WRITE)
        res = libusb_control_transfer(dev, USB_CTL_TYPE, REQ_COMMAND, command, 0x0000, data, length, USB_TIMEOUT);
    else if (type == REQ_TYPE_READ)
        res = libusb_control_transfer(dev, 0x80 | USB_CTL_TYPE, REQ_COMMAND, command, 0x0000, data, length, USB_TIMEOUT);

    return res > 0 ? 0 : res;
}

int flash_wait(libusb_device_handle* dev)
{
    unsigned char reg = 0xFF;
    int res;

    while (reg & 0x01)
    {
        res = flash_command(dev, REQ_TYPE_READ, 0x05, &reg, 1);
        if (res)
            return res;
    }
    return 0;
}

int flash_write_enable(libusb_device_handle* dev)
{
    flash_command(dev, REQ_TYPE_WRITE, 0x06, 0, 0);
}

int flash_erase_sector(libusb_device_handle* dev, uint8_t sector_addr)
{
    unsigned char addr[3] = {sector_addr, 0x00, 0x00};
    int res;

    res = flash_write_enable(dev);
    if (res)
        return res;

    res = flash_command(dev, REQ_TYPE_WRITE, 0xD8, addr, 3);
    if (res)
        return res;

    res = flash_wait(dev);
    if (res)
        return res;
    return 0;
}

int flash_write_data(libusb_device_handle* dev, uint32_t address, uint8_t *data, int length)
{
    unsigned char addr[3];
    int transferred;
    int sended = 0;
    int res;

    while (sended < length)
    {
        int current_addr = address + sended;
        int chunk_size = length - sended > 256 ? 256 : length - sended;

        if (((current_addr & 0xFF) != 0) && ((current_addr & 0xFF) + chunk_size > 256))
            chunk_size -= current_addr & 0xFF;

        addr[0] = (current_addr >> 16) & 0xff;
        addr[1] = (current_addr >> 8) & 0xff;
        addr[2] = current_addr & 0xff;

        res = flash_write_enable(dev);
        if (res)
            return res;

        res = libusb_bulk_transfer(dev, 0x01, data + sended, chunk_size, &transferred, 1000);
        if (res)
            return res;

        if (transferred != chunk_size)
            return -1;

        res = flash_command(dev, REQ_TYPE_PAGE_WRITE, 0x02, addr, 3);
        if (res)
            return res;

        res = flash_wait(dev);
        if (res)
            return res;

        sended += chunk_size;
    }
    return 0;
}

int flash_program(libusb_device_handle* dev, uint32_t address, uint8_t *data, int length)
{
    int sector_count = (length - 1) / 65536 + 1;
    int offset = 0;
    int i;
    int res;

    for (i = 0; i < sector_count; i++)
    {
        int write_size = (i == sector_count - 1) ? (length % 65536) : 65536;
        offset = i << 16;

        res = flash_erase_sector(dev, ((address >> 16) + i) & 0xFF);
        if (res)
            return res;

        res = flash_write_data(dev, address + offset, data + offset, write_size);
        if (res)
            return res;
    }
    return 0;
}

int flash_read_page(libusb_device_handle* dev, uint32_t address, uint8_t *data)
{
    unsigned char addr[3] = {(address >> 16) & 0xff, (address >> 8) & 0xff, address & 0xff};
    int transferred;
    int res;

    res = flash_command(dev, REQ_TYPE_PAGE_READ, 0x03, addr, 3);
    if (res)
        return res;

    res = libusb_bulk_transfer(dev, 0x81, data, 256, &transferred, 1000);
    if (res)
        return res;

    if (transferred != 256)
        return -1;

    return 0;
}

int flash_read(libusb_device_handle* dev, uint32_t address, uint8_t *data, int length)
{
    char pagebuf[256];
    int readed = 0;
    int res;

    while (readed < length)
    {
        uint32_t cur_addr = address + readed;
        res = flash_read_page(dev, cur_addr, pagebuf);
        if (res)
            return res;

        int copy_size = (length - readed > 256) ? 256 : length - readed;
        memcpy(data + readed, pagebuf, copy_size);
        readed += copy_size;
    }
    return 0;
}

