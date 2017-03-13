#!/usr/bin/env xsct
puts "There are $argc arguments to this script: $argv" 
connect
targets 3
dow [lindex $argv 0]
con
