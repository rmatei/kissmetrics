require 'kissmetrics'
require 'km_url'

   #*
   # A class used to track visitors who have arrived at your site via a search
   # engine's results page.
   #
   # Actions:
   # <ul>
   #  <li><kbd>search_engine_hit</kbd></li>
   # </ul>
   # Global properties:
   # <ul>
   #  <li><kbd>search_engine</kbd> (string) - The name of the search engine</li>
   #  <li><kbd>search_terms</kbd> (string) - The search terms provided to the search engine</li>
   # </ul>
   #
   # @package KISSmetrics
   # @uses KMCore
   #/
class KMSearchEngine
  class << self
    def init
      begin
        km = KMCore.instance

        if referrer = KMServer['HTTP_REFERER']
          if info = KMSearchEngine::get_search_info(referrer)
            km.assign('search_engine', info['name'], KM_STRING)
            km.assign('search_terms', info['terms'], KM_STRING)
            props = {}
            if info['offset']
              props['search_offset'] = [info['offset'], KM_INTEGER]
            end

            km.record('search_engine_hit', props)
          end
        end
      rescue Exception => e
        if KMCore.instance
          begin; KMCore.instance.log_error(e.message); rescue; end
        end
      end
    end

    #*
    # Gets information about the search engine used to arrive at this site based on HTTP_referrer
    # @param string $referrer
    # @return array
    # @uses KMURL::parts
    #/
    def get_search_info(referrer)
      # Define the different search engine properties
      search_info = {
        'Google'    => { 'domain'=>'google.com',          'query_param'=>'q',     'offset_param'=>'start', 'offset_type'=>'seen'},
        'Yahoo'     => { 'domain'=>'search.yahoo.com',    'query_param'=>'p',     'offset_param'=>'b',     'offset_type'=>'first'},
        'Ask'       => { 'domain'=>'ask.com',             'query_param'=>'q',     'offset_param'=>'page',  'offset_type'=>'page'},
        'MSN'       => { 'domain'=>'search.msn.com',      'query_param'=>'q',     'offset_param'=>'first', 'offset_type'=>'first'},
        'Live'      => { 'domain'=>'search.live.com',     'query_param'=>'q',     'offset_param'=>'first', 'offset_type'=>'first'},
        'AOL'       => { 'domain'=>'search.aol.com',      'query_param'=>'query', 'offset_param'=>'page',  'offset_type'=>'page'},
        'Netscape'  => { 'domain'=>'search.netscape.com', 'query_param'=>'query', 'offset_param'=>'page',  'offset_type'=>'page'},
        'AltaVista' => { 'domain'=>'altavista.com',       'query_param'=>'q',     'offset_param'=>'stq',   'offset_type'=>'seen'},
        'Lycos'     => { 'domain'=>'search.lycos.com',    'query_param'=>'query', 'offset_param'=>'page2', 'offset_type'=>'page_plus_one'},
        'Dogpile'   => { 'domain'=>'dogpile.com',         'query_param'=>'/dogpile/ws/results/Web/', 'offset_param'=>'qi', 'offset_type'=>'first', 'param_type'=>'path'},
        'A9'        => { 'domain'=>'a9.com',              'query_param'=>'/',     'offset_param'=>'start', 'offset_type'=>'seen'}
      }

      results = nil
      search_info.each do |name,engine|
        # Parse out the URL parts
        url_parts = KMURL::parts(referrer, engine['param_type'] == 'path')
        params = url_parts['params'] ? url_parts['params'] : []

        # Check the host to see if it matches the engine domain
        if url_parts['host'] && url_parts['host'].include?(engine['domain'])
          terms = nil

          # Check which type of query param the search engine uses: param or path based
          if engine['query_param'].slice(0,1) == '/'
            # The search engine uses a path-based URL
            if url_parts['path']
              if url_parts['path'].index(engine['query_param']) == 0
                # Strip off the search path prefix
                terms = url_parts['path'].slice(engine['query_param'].size, url_parts['path'].size)
                # Strip of everything after the slash
                slash_pos = terms.index '/'
                if slash_pos
                  terms = terms.slice(0,slash_pos)
                end
                terms = CGI::unescape(terms)
              end
            end
          else
            # The search engine uses a query parameter, so check the params
            terms = params[engine['query_param']]
          end
          if terms
            results = { 'name'=> name, 'terms'=> terms }

            # Check to see if the offset param exists
            if offset = params[engine['offset_param']]
              offset = offset.to_i
              case engine['offset_type']

              when 'first':
                # This means the offset represents the first item on the page
                # so the number of ones you have already viewed is $offset minus 1
                results['offset'] = offset-1
              when 'page':
                # Uses a page number based offset. We assume 10 results per page, because
                # there is not a consistent way to get the number of results shown. This
                # can lead to innaccuracies in data, which is why we display that this is
                # just an estimate
                results['offset'] = (offset-1)*10
              when 'page_plus_one':
                # Uses a page number based offset. We assume 10 results per page, because
                # there is not a consistent way to get the number of results shown. This
                # can lead to innaccuracies in data, which is why we display that this is
                # just an estimate
                results['offset'] = (offset)*10
              else
                results['offset'] = offset
              end
            end
          end
        end
      end

      return results
    end

    def verify()
      return true
    end
  end
end
$__km_plugins__ << 'KMSearchEngine'
