require 'homebus'
require 'homebus_app'
require 'snmp'
require 'mqtt'
require 'json'

class PrinterHomeBusApp < HomeBusApp
  def initialize(options)
    @options = options

    @manager_hostname = @options[:agent]

    super
  end

  def setup!
    @manager = SNMP::Manager.new(host: options[:agent], community: options[:community_string], version: :SNMPv1)

    response = @manager.get(['sysDescr.0', 'sysName.0', 'sysLocation.0', 'sysUpTime.0'])
    response.each_varbind do |vb|
      @sysName = vb.value.to_s if  vb.name.to_s == 'SNMPv2-MIB::sysName.0'
      @sysDescr = vb.value.to_s if  vb.name.to_s == 'SNMPv2-MIB::sysDescr.0'
      @sysLocation = vb.value.to_s if  vb.name.to_s == 'SNMPv2-MIB::sysLocation.0'
    end

    puts @sysName, @sysDescr, @sysLocation

    response = @manager.get([ '1.3.6.1.2.1.43.11.1.1.9.1.6', '1.3.6.1.2.1.43.11.1.1.9.1.7', '1.3.6.1.2.1.43.16.5.1.2.1.1', '1.3.6.1.2.1.1.5.0', '1.3.6.1.2.1.25.3.2.1.3.1' ])
    response.each_varbind do |vb|
      remaining_belt_unit_pages = vb.value.to_i if vb.name.to_s == '1.3.6.1.2.1.43.11.1.1.9.1.6'
      remaining_drum_unit_pages = vb.value.to_i if vb.name.to_s == '1.3.6.1.2.1.43.11.1.1.9.1.7'
      status  = vb.value.to_i if vb.name.to_s == '1.3.6.1.2.1.43.16.5.1.2.1.1'
      serial_number = vb.value.to_i if vb.name.to_s == '1.3.6.1.2.1.1.5.0'
      model = vb.value.to_i if vb.name.to_s == '1.3.6.1.2.1.25.3.2.1.3.1'
      pp vb
    end

#    response = @manager.get_bulk(0, 256, [ "1.3.6.1.2.1.43.10.2" ])
    count = 0
#    @manager.walk("1.3.6.1.2.1.43.11.1") do |row|
    @manager.walk("1.3.6.1.2.1.43.11.1.1.6.0") do |row|
      pp row
      count += 1
    end

    puts "#{count} rows"

    @manager.walk("1.3.6.1.2.1.43.11.1.1.9.0") do |row|
      pp row
      count += 1
    end

    puts "#{count} rows"


    @manager.walk("1.3.6.1.2.1.43.11.1.1.8.0") do |row|
      pp row
      count += 1
    end

    puts "#{count} rows"



    exit
  end

  def work!
    rcv_bytes = 0
    xmt_bytes = 0

    response = @manager.get(["ifInOctets.#{@ifnumber}", "ifOutOctets.#{@ifnumber}"])
    response.each_varbind do |vb|
      rcv_bytes = vb.value.to_i if vb.name.to_s == "IF-MIB::ifOutOctets.#{@ifnumber}"
      xmt_bytes = vb.value.to_i if vb.name.to_s == "IF-MIB::ifInOctets.#{@ifnumber}"
    end

#    out = `snmpbulkwalk -v 2c -c public -Osq 10.0.1.1 .1.3.6.1.2.1.3.1.1.2`
#    pp out
#    active_hosts = out.split("\n").length
    active_hosts = 1

    unless @first_pass
      if @options[:verbose]
        puts "receive #{rcv_bytes - @last_rcv_bytes} bytes, #{((rcv_bytes - @last_rcv_bytes)/20.0*8/1024).to_i} kbps"
        puts "transmit #{xmt_bytes - @last_xmt_bytes} bytes, #{((xmt_bytes - @last_xmt_bytes)/20.0*8/1024).to_i} kbps"
      end

      rx_bps = ((rcv_bytes - @last_rcv_bytes)/60.0*8).to_i
      tx_bps = ((xmt_bytes - @last_xmt_bytes)/20.0*8).to_i

      if @options[:verbose]
        pp results
      end

      timestamp = Time.now.to_i

      # stop publishing this until we have real data to share
      if false
      @mqtt.publish "/network/active_hosts", JSON.generate({ id: @uuid,
                                                             timestamp: timestamp,
                                                             active_hosts: active_hosts
                                                           })
      end

      @mqtt.publish '/network/bandwidth',
                    JSON.generate({ id: @uuid,
                                    timestamp: timestamp,
                                    rx_bps: rx_bps,
                                    tx_bps: tx_bps
                                  }),
                    true
    else
      @first_pass = false
    end

    @last_rcv_bytes = rcv_bytes
    @last_xmt_bytes = xmt_bytes


    sleep 60
  end

  def manufacturer
    'HomeBus'
  end

  def model
    @sysDescr
  end

  def friendly_name
    "Network activity for #{@manager_hostname}"
  end

  def friendly_location
    @sysLocation
  end

  def serial_number
    ''
  end

  def pin
    ''
  end

  def devices
    [
      { friendly_name: 'Receive bandwidth',
        friendly_location: '',
        update_frequency: 60,
        index: 0,
        accuracy: 0,
        precision: 0,
        wo_topics: [ 'network/bandwidth' ],
        ro_topics: [],
        rw_topics: []
      },
      { friendly_name: 'Transmit bandwidth',
        friendly_location: '',
        update_frequency: 60,
        accuracy: 0,
        precision: 0,
        index: 1,
        wo_topics: [ 'network/bandwidth' ],
        ro_topics: [],
        rw_topics: []
      },
      { friendly_name: 'Active hosts',
        friendly_location: '',
        update_frequency: 60,
        accuracy: 0,
        precision: 0,
        index: 2,
        wo_topics: [ 'network/active' ],
        ro_topics: [],
        rw_topics: []
      }
    ]
  end
end
