PROJECT(SPI_Flasher)
CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

INCLUDE_DIRECTORIES(
    /usr/include/libusb-1.0
)

ADD_EXECUTABLE(usbcore_spi_flasher main.c spi_flasher.c)
TARGET_LINK_LIBRARIES(usbcore_spi_flasher usb-1.0)