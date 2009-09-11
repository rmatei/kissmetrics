require 'cgi'
require 'kissmetrics'

KM_BLACKLISTED_URL_PARAMS = %w(sid PHPSESSID session jsessionid __VIEWSTATE)
class  KMURL
  class << self

     #
     # Takes a URL and normalizes it by removing all blacklisted parameters.
     # Blacklisted parameters are params that should be ignored. By default this list contains
     # parameters related to sessions.
     #
     # The list is defined as $KM_BLACKLISTED_URL_PARAMS in {@link km_url.php}
     # <code>
     # KMURL::normalize('http://site.com/index.php?sid=1231231231231&page=1')
     # => 'http://site.com/index.php?page=1'
     # </code>
     # @param string $url The URL to normalize
     # @return string The URL without the blacklisted parameters
     #/
  def normalize(url)

    return '' unless url

    if KM_BLACKLISTED_URL_PARAMS
      # Break up the URL into it's pairs
      parts = parts url

      if parts['params'].size != 0
        fragment = parts['fragment'] ? '#' + parts['fragment'] : ''

        # Strip blacklisted params
        pre_query_string, query_string = url.split '?'
        query_string_parts = query_string.split '&'
        valid_query_string_parts = []

        query_string_parts.each do |query_string_part|
          key,trash = query_string_part.split '='
          if not KM_BLACKLISTED_URL_PARAMS.include? key
            valid_query_string_parts << query_string_part
          end
        end

        if valid_query_string_parts.size == 0
          return pre_query_string + fragment
        end

        return pre_query_string + '?' + valid_query_string_parts.join('&') + fragment
      end
    end
    return url
  end


  # 
  # Takes a URL, parses it, and returns all the parts
  #
  # @param string $url The URL to parse
  # @param boolean $path_based_params If true, then search through the path for params. This is for URLs in the form
  # /zoom=off/qi=21/qk=20/bepersistence=true/ (example from the search engine DogPile).
  # @return string An associative array with the following parts: scheme, host, port, user, pass, path, query, fragment
  # params is an associative array with each param broken down by param name and URL-unencoded value.
  #/
  def parts(url, path_based_params=false)
    return {} unless url

    # Parse out the URL parts
    parts = parse_url url

    return {} if not parts

    params = {}
    # Parse out the param-based parts
    if parts['query']
      pairs = parts['query'].split '&'
      pairs.each do |pair|
        key,value = pair.split '='
        value = CGI::unescape value.to_s
        params[key] = value
      end
    end
    # Parse bath-based URL params
    if path_based_params
      if parts['path']
        pairs = parts['path'].split '/'
        pairs.each do |pair|
          if pair.include? '='
            key,value = pair.split '='
            value = CGI::unescape value
            params[key] = value
          end
        end
      end
    end
    parts['params'] = params

    return parts
  end

  # this function is meant to mimick PHP's parse_url
  def parse_url(str)
    # regexp borrowed from js client
    parser = Regexp.new /^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/\/?)?((?:(([^:@]*):?([^:@]*))?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/
    key = ["scheme","authority","userInfo","user","pass","host","port","relative","path","directory","file","query"]
    match_data = parser.match str
    m = match_data.captures
    uri = {}
    11.downto(0) do |i|
      uri[key[i]] = m[i] || nil
    end
    # this regex doesn't work the same as PHP parse_url
    # and it was stolen from the js client so that gives us more differences
    # so let's fix the discrepancies
    uri['fragment'] = str.scan(/#(.*)$/).to_s
    %w|relative directory authority file|.each { |w| uri.delete w }
    return uri.reject { |k,v| v == nil or v == "" } # remove values that are nil or empty
  end


    def verify
      return true
    end
  end
end
$__km_plugins__ << 'KMURL'
