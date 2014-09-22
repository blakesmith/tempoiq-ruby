require 'json'
require 'uri'

require 'tempoiq/models/bulk_write'
require 'tempoiq/models/cursor'
require 'tempoiq/models/datapoint'
require 'tempoiq/models/delete_summary'
require 'tempoiq/models/device'
require 'tempoiq/models/find'
require 'tempoiq/models/pipeline'
require 'tempoiq/models/query'
require 'tempoiq/models/read'
require 'tempoiq/models/row'
require 'tempoiq/models/search'
require 'tempoiq/models/selection'

require 'tempoiq/remoter/live_remoter'

module TempoIQ
  class ClientError < StandardError
  end

  # TempoIQ::Client is the main interface to your TempoIQ backend.
  # 
  # The client is broken down into two main sections:
  #
  # [Device Provisioning]
  #   - #create_device
  #   - #update_device
  #   - #delete_device
  #   - #delete_devices
  #   - #get_device
  #   - #list_devices
  #
  # [DataPoint Reading / Writing]
  #   - #write_bulk
  #   - #write_device
  #   - #read
  class Client
    attr_reader :key, :secret, :host, :secure, :remoter

    # Create a TempoIQ API Client
    # 
    # * +key+ [String] - Your TempoIQ backend key
    # * +secret+ [String] - TempoIQ backend secret
    # * +host+ [String] - TempoIQ backend host, found on your TempoIQ backend dashboard
    # * +port+ (optional) [Integer] - TempoIQ backend port
    # * +opts+ (optional) [Hash] - Optional client parameters
    #
    # ==== Options
    # * +:secure+ [Boolean] - Whether to use SSL or not. Defaults to true
    # * +:remoter+ [Remoter] - Makes the backend calls
    def initialize(key, secret, host, port = 443, opts = {})
      @key = key
      @secret = secret
      @host = host
      @port = port
      @secure = opts.has_key?(:secure) ? opts[:secure] : true
      @remoter = opts[:remoter] || LiveRemoter.new(key, secret, host, port, secure)
    end

    def create_device(key, name, attributes, *sensors)
      device = Device.new(key, name, attributes, *sensors)
      remoter.post("/v2/devices", JSON.dump(device.to_hash)).on_success do |result|
        json = JSON.parse(result.body)
        Device.from_hash(json)
      end
    end

    def get_device(device_key)
      remoter.get("/v2/devices/#{URI.escape(device_key)}").on_success do |result|
        json = JSON.parse(result.body)
        Device.from_hash(json)
      end
    end

    def list_devices(selection)
      query = Query.new(Search.new("devices", selection),
                        Find.new,
                        nil)

      Cursor.new(Device, remoter, "/v2/devices", query)
    end

    def delete_device(device_key)
      remoter.delete("/v2/devices/#{URI.escape(device_key)}")
    end

    def delete_devices(selection)
      query = Query.new(Search.new("devices", selection),
                        Find.new,
                        nil)

      remoter.delete("/v2/devices", JSON.dump(query.to_hash)).on_success do |result|
        json = JSON.parse(result.body)
        DeleteSummary.new(json['deleted'])
      end
    end

    def update_device(device)
      remoter.put("/v2/devices/#{URI.escape(device.key)}", JSON.dump(device.to_hash)).on_success do |result|
        json = JSON.parse(result.body)
        Device.from_hash(json)
      end
    end

    def write_bulk(bulk_write = nil, &block)
      bulk = bulk_write || BulkWrite.new
      if block_given?
        yield bulk
      elsif bulk_write.nil?
        raise ClientError.new("You must pass either a bulk write object, or provide a block")
      end

      remoter.post("/v2/write", JSON.dump(bulk.to_hash))
    end

    def write_device(device_key, ts, values)
      bulk = BulkWrite.new
      values.each do |sensor_key, value|
        bulk.add(device_key, sensor_key, DataPoint.new(ts, value))
      end
      write_bulk(bulk)
    end

    def read(selection, start, stop, pipeline = nil, &block)
      pipe = pipeline || Pipeline.new
      if block_given?
        yield pipe
      end

      query = Query.new(Search.new("devices", selection),
                        Read.new(start, stop),
                        pipe)

      Cursor.new(Row, remoter, "/v2/read", query)      
    end
  end
end
