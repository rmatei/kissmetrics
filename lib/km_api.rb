# Wrapper for the Kissmetrics API in Ruby.
# 
# Usage:
# km_api = KMApi.new(public_token, secret_key)
# km_api.get(:method => 'single_action_query', :query => {...})

require 'httparty'
require 'digest/sha1'

class KMApi
  include HTTParty
  base_uri 'http://beta-almanac.kissmetrics.com'
  default_params :version => 1.5, :format => 'json'
  format :json
  
  def initialize(token, secret_key)
    @token = token
    @secret_key = secret_key
    authenticate
  end
  
  def authenticate
    puts "Logging in to Kissmetrics..."
    response = post_request(:method => 'get_salt')
    raise SecurityError, "Authentication failed: #{response.inspect}" if response["salt"].blank?
    @sid = response["sid"]
    hash = Digest::SHA1.hexdigest("__km__#{response["salt"]}#{@secret_key}")
    response = post_request(:method => 'login', :sid => response["sid"], :h => hash)
    response['logged_in'] ? puts("Success!") : raise(SecurityError, "Authentication failed.")
  end
  
  def get(params = {})
    @tries = 0 if @tries.nil? or @last_params != params
    @last_params = params
    response = Rails.cache.fetch(memcached_key(params)) { post_request(params.dup) }
    valid_response?(response) ? response : raise("Invalid response: #{response.inspect}")
  rescue Exception => e
    puts e.message
    Rails.cache.delete(memcached_key(params))
    @tries += 1 
    if @tries <= 3
      sleep 0.25
      puts "Retrying API query..."
      retry 
    end
    {}
  end
  
  def post_request(params = {})
    puts "Kissmetrics API call: #{params.inspect}..."
    params[:t] ||= @token
    params[:sid] ||= @sid
    params[:query] = params[:query].to_json unless params[:query].instance_of? String
    self.class.get('/index.php', :query => params)
  end
  
  private
  
  def valid_response?(response)
    response.instance_of? Hash and response["segments"]
  end
  
  def memcached_key(params)
    "km_api_#{params}" 
  end
end