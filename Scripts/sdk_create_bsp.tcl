#!/usr/bin/env xsct
cd ../Software
setws [pwd]
createhw -name arty_debug -hwspec arty_debug.hdf
sdk createbsp -name arty_debug_bsp -hwproject arty_debug -proc CPU -os standalone
projects -build
