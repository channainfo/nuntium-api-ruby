# Provides access to the Nuntium Public API.
#
# === Install
#
#   gem install nuntium_api
#
# === Example
#
#   api = Nuntium.new 'service_url', 'account_name', 'application_name', 'application_password'
require 'rubygems'
require 'httparty'
require 'json'

# Provides access to the Nuntium Public API.
class Nuntium
  include HTTParty

  # Creates an application-authenticated Nuntium api access.
  def initialize(url, account, application, password)
    @url = url
    @account = account
    @application = application
    @auth = {:username => "#{account}/#{application}", :password => password}
  end

  # Gets the list of countries known to Nuntium.
  def countries
    self.class.get "#{@url}/api/countries.json"
  end

  # Gets a country given its iso2 or iso3 code, or nil if a country with that iso does not exist.
  def country(iso)
    c = self.class.get "#{@url}/api/countries/#{iso}.json"
    return nil if c.class <= String
    c
  end

  # Gets the list of carriers known to Nuntium that belong to a country, given its
  # iso2 or iso3 code. Gets all carriers if no country is specified.
  def carriers(country_id = nil)
    if country_id
      self.class.get "#{@url}/api/carriers.json", :query => {:country_id => country_id}
    else
      self.class.get "#{@url}/api/carriers.json"
    end
  end

  # Gets a carrier given its guid, or nil if a carrier with that guid does not exist.
  def carrier(guid)
    c = self.class.get "#{@url}/api/carriers/#{guid}.json"
    return nil if c.class <= String
    c
  end

  # Returns the list of channels belonging to the application or that don't
  # belong to any application.
  def channels
    chans = self.class.get "#{@url}/api/channels.json", :basic_auth => @auth
    return nil if chans.class <= String
    chans.each do |channel|
      read_configuration channel
    end
  end

  # Returns a chnanel given its name, or nil if the channel doesn't exist
  def channel(name)
    response = self.class.get "#{@url}/api/channels/#{name}.json", :basic_auth => @auth
    return_channel response
  end

  # Creates a channel.
  #   create_channel :name => 'foo', :kind => 'qst_server', :protocol => 'sms', :configuration => {:password => 'bar'}
  def create_channel(channel)
    write_configuration channel
    response = self.class.post "#{@url}/api/channels.json", :basic_auth => @auth, :body => channel.to_json
    return_channel response
  end

  # Updates a channel.
  #   update_channel :name => 'foo', :kind => 'qst_server', :protocol => 'sms', :configuration => {:password => 'bar'}
  def update_channel(channel)
    write_configuration channel
    response = self.class.put "#{@url}/api/channels/#{channel['name']}.json", :basic_auth => @auth, :body => channel.to_json
    return_channel response
  end

  # Deletes a chnanel given its name.
  def delete_channel(name)
    self.class.delete "#{@url}/api/channels/#{name}", :basic_auth => @auth
  end

  # Returns the list of candidate channels when simulating routing the given
  # AO message.
  #   candidate_channels_for_ao :from => 'sms://1', :to => 'sms://2', :subject => 'hello', :body => 'hi!'
  def candidate_channels_for_ao(message)
    chans = self.class.get "#{@url}/api/candidate/channels.json", :basic_auth => @auth, :body => message
    return nil if chans.class <= String
    chans.each do |channel|
      read_configuration channel
    end
  end

  # Sends one or many AO messages.
  # Returns an enhanced HTTParty::Response instance with id, guid and token readers that matches those x-headers
  # returned by Nuntium.
  # To send a token, just include it in the message as :token => 'my_token'
  #   send_ao :from => 'sms://1', :to => 'sms://2', :subject => 'hello', :body => 'hi!'
  #   send_ao [{:from => 'sms://1', :to => 'sms://2', :subject => 'hello', :body => 'hi!'}, {...}]
  def send_ao(messages)
    response = if messages.is_a? Array
      self.class.post "#{@url}/#{@account}/#{@application}/send_ao.json", :basic_auth => @auth, :body => messages.to_json
    else
      self.class.post "#{@url}/#{@account}/#{@application}/send_ao", :basic_auth => @auth, :body => messages
    end
    def response.id; headers['x-nuntium-id']; end
    def response.token; headers['x-nuntium-token']; end
    def response.guid; headers['x-nuntium-guid']; end
    response
  end

  # Gets AO messages that have the given token. The response is an array of hashes with the messages' attributes.
  def get_ao(token)
    self.class.get "#{@url}/#{@account}/#{@application}/get_ao.json?token=#{token}", :basic_auth => @auth
  end

  # Gets the custom attributes specified for a given address. Returns a hash with the attributes
  def get_custom_attributes(address)
    attrs = self.class.get "#{@url}/api/custom_attributes?address=#{address}", :basic_auth => @auth
    return nil unless attrs.is_a? Hash
    attrs
  end

  def set_custom_attributes(address, attributes)
    self.class.post "#{@url}/api/custom_attributes?address=#{address}", :basic_auth => @auth, :body => attributes
  end

  private

  def write_configuration(channel)
    configuration = []
    channel[:configuration].each do |name, value|
      configuration << {:name => name, :value => value}
    end
    channel[:configuration] = configuration
  end

  def read_configuration(channel)
    configuration = {}
    channel['configuration'].each do |hash|
      configuration[hash['name']] = hash['value']
    end
    channel['configuration'] = configuration
  end
  
  def return_channel(response)
    return nil if response.class <= String
    if response.response.class <= Net::HTTPSuccess
      channel = response.parsed_response.with_indifferent_access
      read_configuration channel 
      channel
    else
      # TODO should wrap in exception
      response
    end
  end

end
