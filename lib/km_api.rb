# Wrapper for the Kissmetrics API in Ruby.
# 
# Usage:
# km_api = KMApi.new(public_token, secret_key)
# km_api.get(:method => '...', ...)

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
    response = get(:method => 'get_salt')
    raise SecurityError, "Authentication failed: #{response.inspect}" if response["salt"].blank?
    @sid = response["sid"]
    hash = Digest::SHA1.hexdigest("__km__#{response["salt"]}#{@secret_key}")
    response = get(:method => 'login', :sid => response["sid"], :h => hash)
    response['logged_in'] ? puts("Success!") : raise(SecurityError, "Authentication failed.")
  end
  
  def get(params = {})
    params[:t] ||= @token
    params[:sid] ||= @sid
    self.class.get('/index.php', :query => params)
  end
end
