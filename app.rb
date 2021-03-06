require 'homebus'
require 'homebus_app'
require 'snmp'
require 'mqtt'
require 'json'

class PrinterHomeBusApp < HomeBusApp
  DDC = 'org.homebus.experimental.printer'

  def initialize(options)
    @options = options

    @manager_hostname = @options[:agent]

    @old_status = ''
    @old_total_page_count = 0

    super
  end

  def setup!
    @manager = SNMP::Manager.new(host: options[:agent], community: options[:community_string], version: :SNMPv1)

    response = @manager.get(['sysDescr.0', 'sysName.0', 'sysLocation.0', 'sysUpTime.0', '1.3.6.1.2.1.43.5.1.1.17.1', '1.3.6.1.2.1.25.3.2.1.3.1'])
    response.each_varbind do |vb|
      @sysName = vb.value.to_s if  vb.name.to_s == 'SNMPv2-MIB::sysName.0'
      @sysDescr = vb.value.to_s if  vb.name.to_s == 'SNMPv2-MIB::sysDescr.0'
      @sysLocation = vb.value.to_s if  vb.name.to_s == 'SNMPv2-MIB::sysLocation.0'
      @serial_number = vb.value.to_s if vb.name.to_s == 'SNMPv2-SMI::mib-2.43.5.1.1.17.1'
      @model = vb.value.to_s if vb.name.to_s == 'SNMPv2-SMI::mib-2.25.3.2.1.3.1'
    end

    if(@options[:verbose])
      puts @sysName, @sysDescr, @sysLocation, @model, @serial_number
    end

  end

  def work!
    status_msg = ''
    total_page_count = 0
    remaining_belt_unit_pages = 0
    remaining_drum_unit_pages = 0

    begin
      response = @manager.get([ '1.3.6.1.2.1.43.11.1.1.9.1.6', '1.3.6.1.2.1.43.11.1.1.9.1.7', '1.3.6.1.2.1.43.16.5.1.2.1.1', '1.3.6.1.2.1.43.10.2.1.4.1.1' ])
      response.each_varbind do |vb|
        remaining_belt_unit_pages = vb.value.to_i if vb.name.to_s == 'SNMPv2-SMI::mib-2.43.11.1.1.9.1.6'
        remaining_drum_unit_pages = vb.value.to_i if vb.name.to_s == 'SNMPv2-SMI::mib-2.43.11.1.1.9.1.7'
        status_msg  = vb.value.to_s if vb.name.to_s == 'SNMPv2-SMI::mib-2.43.16.5.1.2.1.1'
        total_page_count = vb.value.to_i if vb.name.to_s == 'SNMPv2-SMI::mib-2.43.10.2.1.4.1.1'
      end
    rescue
    end

    if(status_msg != '' && (status_msg != @old_status || total_page_count != @old_total_page_count))
      @old_status = status_msg
      @old_total_page_count = total_page_count

      status = {
        system: {
          model: @model,
          serial_number: @serial_number
        },
        status: {
          message: status_msg,
          total_page_count: total_page_count,
        },
        resources: [
          {
            name: 'remaining_belt_unit_pages',
            count: remaining_belt_unit_pages
          },
          {
            name: 'remaining_drum_unit_pages',
            count: remaining_drum_unit_pages
          }
        ]
      }

    if @options[:verbose]
      pp status
    end

      publish! DDC, status
    end
    
    sleep 60
  end

  def manufacturer
    'HomeBus'
  end

  def model
    @model
  end

  def friendly_name
    "Printer status for #{@manager_hostname}"
  end

  def friendly_location
    @sysLocation
  end

  def serial_number
    @serial_number
  end

  def pin
    ''
  end

  def devices
    [
      { friendly_name: 'Printer info',
        friendly_location: '',
        update_frequency: 60,
        index: 0,
        accuracy: 0,
        precision: 0,
        wo_topics: [ DDC ],
        ro_topics: [],
        rw_topics: []
      }
    ]
  end
end
