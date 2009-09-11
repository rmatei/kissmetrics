#* User Agent Plugin
#
# Records users' operating system and browser.
#/

require 'kissmetrics'

#
# A class used to determine and record a user's browser and OS.
# 
# Global properties:
# <ul>
#  <li><kbd>os</kbd> (string) - the operating system of the user making the request</li>
#  <li><kbd>browser</kbd> (string) - the browser of the user making the request</li>
# </ul>
# 
# @uses KMCore
# @package KISSmetrics
#/
class KMUserAgent
  class << self

    #
    # Tries to guess the OS based on a user-agent string.
    #
    # <code>
    # KMUserAgent::os_from_ua('Opera/9.63 (Windows NT 6.0; U; en) Presto/2.1.1')
    # => 'Windows Vista'
    # </code>
    # @param string $user_agent User agent information. Typically contents of $_SERVER['HTTP_USER_AGENT']
    # @return string OS name
    #/
    def os_from_ua(user_agent)

      case user_agent
      when /UNIX/i
        return 'Unix'
      when /os x/i
        return 'OS X'
      when /Windows\s9\d/i
        return 'Windows 9X'
      when /(Windows ME)|(Windows NT 5\.0)/i
        return 'Windows 2000'
      when /(Windows XP)|(Windows NT 5\.[12])/i
        return 'Windows XP'
      when /(Windows Vista)|(Windows NT 6\.0)/i
        return 'Windows Vista'
      when /(Windows Vista)|(Windows NT 6\.1)/i
        return 'Windows 7'
      when /Windows NT/i
        return 'Windows NT'
      when /Linux/i
        return 'Linux'
      when /Solaris/i
        return 'Solaris'
      when /mobile/i
        return 'Mobile'
      else
        return KM_UNKNOWN
      end

    end

    #
    #
    # Tries to guess the browser based on a user-agent string.
    #
    # <code>
    # KMUserAgent::os_from_ua('Opera/9.63 (Windows NT 6.0 U en) Presto/2.1.1')
    # => 'Opera'
    # </code>
    # @param string $user_agent User agent information. Typically contents of $_SERVER['HTTP_USER_AGENT']
    # @return string browser name
    #/

    def browser_from_ua(user_agent)
      case user_agent
      when /Flock(\s+|\/)(\d)/i
        return 'Flock ' + $2 + '.x'
      when /Galeon(\s+|\/)(\d)/i
        return 'Galeon ' + $2 + '.x'
      when /Chrome/i
        return 'Chrome'
      when /iPhone/i
        return 'iPhone'
      when /Shiira/i
        return 'Shiira'
      when /Opera(\s+|\/)(\d)/i
        return 'Opera ' + $2 + '.x'
      when /Camino/i
        return 'Camino'
      when /Omniweb/i
        return 'Omniweb'
      when /(Netscape|Navigator)(\s+|\/)(\d)/i
        return 'Netscape ' + $3 + '.x'
      when /safari/i
        if user_agent =~ /Version(\s+|\/)(\d)/i
          return 'Safari ' + $2 + '.x'
        end
      when /Firefox(\s+|\/)(\d)/i
        return 'Firefox ' + $2 + '.x'
      when /IE(\s+|\/)(\d)/i
        return 'IE ' + $2 + '.x'
      when /Opera(\s+|\/)(\d)/i
        return 'Opera ' + $2 + '.x'
      when /Konqueror(\s+|\/)(\d)/i
        return 'Konqueror ' + $2 + '.x'
      when /Lynx(\s+|\/)(\d)/i
        return 'Lynx ' + $2 + '.x'
      else
        return KM_UNKNOWN
      end
    end

    def init
      begin
        if KMServer['HTTP_USER_AGENT']
          user_agent = KMServer['HTTP_USER_AGENT']
          km = KMCore.instance
          km.assign('os', KMUserAgent::os_from_ua(user_agent), KM_STRING)
          km.assign('browser', KMUserAgent::browser_from_ua(user_agent), KM_STRING)
        end
      rescue Exception => e
        if KMCore.instance
          begin; KMCore.instance.log_error(e.message); rescue; end
        end
      end
    end

    def verify()
      return true
    end
  end
end
$__km_plugins__ << 'KMUserAgent'
