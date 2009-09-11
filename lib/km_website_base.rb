#* Website Base Plugin
#
# Records basic page view and session properties
#
# @package KISSmetrics
#/
$: << File.expand_path(File.dirname(__FILE__))
require 'kissmetrics'
require 'km_url'
#*
# A class for recording basic properties of a request such as the URL, referrrer, the 
# initial referrer (i.e. the incoming link that brought the user to the site),
# and the time since the user last visited the site.
#
# Actions:
# <ul>
#  <li><kbd>page_view</kbd></li>
#  <li><kbd>session</kbd></li>
# </ul>
#
# Global properties:
# <ul>
#  <li><kbd>url</kbd> (url) - the current URL</li>
#  <li><kbd>referrer</kbd> (url) - the previous URL</li>
#  <li><kbd>initial_referrer</kbd> (url) - the URL from which the user arrived at the site</li>
#  <li><kbd>time_since_last_session</kbd> (duration) - the length of time since the user's last visit</li>
# </ul>
#
# @uses KMCore
# @package KISSmetrics
#/
class KMWebsiteBase
  class << self
    def init
      KMWebsiteBase::record_page_view
    end
    
    def record_page_view
      begin
        km = KMCore.instance

        # Get the current URL for this request
        current_url = nil
        if KMServer['REQUEST_URI']
          current_url = KMURL::normalize(KMServer['REQUEST_URI'])
        end
        km.assign('url', current_url, KM_URL)

        referrer = nil
        if KMServer['HTTP_REFERER']
          referrer = KMURL::normalize(KMServer['HTTP_REFERER'])
        end
        km.assign('referrer', referrer, KM_URL)

        initial_referrer = nil
        if !KMSession[KM_COOKIE_PREFIX + 'initial_referrer']
          KMSession[KM_COOKIE_PREFIX + 'initial_referrer'] = referrer
        end

        if KMSession[KM_COOKIE_PREFIX + 'initial_referrer']
          initial_referrer = KMSession[KM_COOKIE_PREFIX + 'initial_referrer']
        end
        km.assign('initial_referrer', initial_referrer, KM_URL)

        # See if we need to record a session
        record_session = false
        if not KMSession[KM_COOKIE_PREFIX + 'recorded_session']
          KMSession[KM_COOKIE_PREFIX + 'recorded_session'] = true
          last_session_at = KMCookie[:last_session_at]
          if ( last_session_at )
            last_session_at = last_session_at.to_i
            KMSession[KM_COOKIE_PREFIX + 'time_since_last_session'] = Time.now.to_i - last_session_at
          end
          KMCookie[:last_session_at] = Time.now.to_i

          record_session = true
        end

        time_since_last_session = nil
        if KMSession[KM_COOKIE_PREFIX + 'time_since_last_session']
          time_since_last_session = KMSession[KM_COOKIE_PREFIX + 'time_since_last_session']
        end
        km.assign('time_since_last_session', time_since_last_session, KM_TIME_DURATION)

        km.record('session') if record_session
        km.record('page_view')
      rescue Exception => e
        if KMCore.instance
          begin; KMCore.instance.log_error(e.message); rescue; end
        end
      end
    end

    def verify
      return true
    end
  end
end
$__km_plugins__ << 'KMWebsiteBase'
