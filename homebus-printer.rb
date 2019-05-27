#!/usr/bin/env ruby

require './options'
require './app'

printer_app_options = PrinterHomeBusAppOptions.new

printer = PrinterHomeBusApp.new printer_app_options.options
printer.run!
