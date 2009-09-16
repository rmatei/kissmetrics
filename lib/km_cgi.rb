require 'cgi/session'

class KMCookie
  @@cookies = {}
  class << self
    def []=(key,value,length=157680000)
      @@cookies[KM_COOKIE_PREFIX + key.to_s] = {:value => value.to_s, :expires => Time.now + length }
    end
    def [](key)
      @@cookies[KM_COOKIE_PREFIX + key.to_s]
    end
    def init(env_hash)
      return if KMConf::KM_DISABLED
      @@cookies = env_hash
    end

    def to_self
      @@cookies
    end

    def delete(key)
      @@cookies.delete key
    end
  end
end

class KMSession
  @@session = $stdin.tty? ? {} : CGI::Session.new(CGI.new)
  class << self
    def []=(key,value)
      @@session[key] = value
    end
    def [](key)
      @@session[key]
    end
    def set_env(env_hash)
      return if KMConf::KM_DISABLED
      @@session = env_hash
    end

    def destroy
      @@session = STDIN.tty? ? {} : CGI::Session.new(CGI.new)
    end

    def to_s
      @@session.to_s
    end

    def pretty_inspect
      @@session.pretty_inspect
    end

    def inspect
      @@session.inspect
    end

    def to_self
      @@session
    end
  end
end


class KMServer
  @@server = {}
  class << self
    def []=(key,value)
      raise "You can't change the server info."
    end
    def [](key)
      @@server[key]
    end
    def set_env(env_hash)
      return if KMConf::KM_DISABLED
      @@server = env_hash
    end
    def to_s
      @@server.to_s
    end
  end
end
