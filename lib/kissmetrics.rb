# Need to pass in the full path to the config when running the daemon
require(ENV['km_config_path'] || 'km_conf')

require 'sha1'
require 'base64'
require "cgi"
require 'singleton'
require 'md5'
require 'km_cgi'
require 'fileutils'
include KMConf 


KM_API_VERSION   = '0.9.1'
KM_STRING        = 'string'
KM_INTEGER       = 'integer'
KM_FLOAT         = 'float'
KM_TIME_DURATION = 'time_duration'
KM_TIMESTAMP     = 'timestamp'
KM_URL           = 'url'
KM_TAGS          = 'tags'
KM_IP_ADDRESS    = 'ip_address'
KM_BOOL          = 'bool'
KM_UNKNOWN       = nil
KM_LOG_FILE_PATTERN = /^(.{32}_\d+\_\d+)\.log/
KM_MAT_DAEMON = File.expand_path( File.dirname(__FILE__) )+'/km_mat.rb'

$__km_plugins__ = []

class String
  def b64enc_sha1
    Base64.encode64([SHA1.sha1(self).to_s].pack('H*')).chomp
  end
end

class KMCore
  include Singleton

  # we really want a new instance. really.
  # this is for testing only.
  def really_new
    return self.new
  end

  def initialize
    @count   = 0
    @assigns = {}
    @actions = []
  end

  def record(name, props={},timestamp=nil)
    begin
      if do_track
        @actions << KMAction.new(name,props)
      end
    rescue Exception => e
      log_error(e.message)
    end
  end

  def debug(message)
    fp = File.open('/tmp/km_debug', 'a')
    fp.puts message
    fp.close
  end


  # Returns true if we track the current request's actions.
  #
  # By default KISSmetrics does not track any activity by robots.
  # However, if you define KM_TRACK_ROBOTS to true, then KISSmetrics
  # will track all activity. You can also call set_do_track(true)
  # for individual pages and KM will record all activity regardless of
  # if KM things the current client is a robot.
  #
  # @return boolean  Whether or not to track the current request's actions.
  # @see set_do_track()
  # @ignore
  #/

  def do_track
    # If the user has specified whether to track or not via set_do_track
    # then use that regardless of the robot setting
    return @track unless @track == nil

    return true if Module.constants.include?('KM_TRACK_ROBOTS') and KM_TRACK_ROBOTS

    if user_agent = KMServer['HTTP_USER_AGENT']
      # Track only if this is not a robot
      return !is_robot(user_agent)
    end

    # No user agent defined - this could be because this is behind a proxy, so
    # we track it anyways.
    return true
  end

  def sha1_b64(str)
    str.b64enc_sha1
  end

  def log_all_actions
    begin
      @actions.each do |action|
        if not action.logged
          action.logged = true
          log_action action.name, action.props
        end
      end
      @actions = []
    rescue Exception => e
      log_error(e.message)
    end
  end

  def check_if_log_needs_rotating(force=false)
    log_file_size = log_start_time = nil

    if File.exists? KM_CURRENT_LOG
      log_file_size = FileTest.size KM_CURRENT_LOG
      if log_file_size >= 12
        fp = File.open KM_CURRENT_LOG, 'r'
        if not fp
          log_error('check_if_log_needs_rotating: Could not open log ' + KM_CURRENT_LOG + ' for reading')
          fp.close
          return false
        end
        chunk = fp.read 12
        fp.close
        if chunk =~ /\d{10}\|/
          log_start_time = chunk.gsub(/\D/,'').to_i
        end

      end
    end


    if (log_file_size &&  log_start_time && (now - log_start_time >= KM_ROTATE_PERIOD || log_file_size > KM_ROTATE_SIZE)) || force
      # Make the transfer directory if it does not exist yet
      if not FileTest.directory? KM_TRANSFER_DIR
        begin
          FileUtils.mkdir_p KM_TRANSFER_DIR
        rescue
          log_error('check_if_log_needs_rotating: Could not create KM_TRANSFER_DIR => ' + KM_TRANSFER_DIR.inspect)
          return false
        end
      end
      name = MD5.md5( (Time.now.to_f + log_file_size).to_s).to_s + '_' + log_start_time.to_s + '_' + now.to_s + '.log' # php version uses md5 TODO: do we really need to?
      File.rename KM_CURRENT_LOG, File.join( KM_TRANSFER_DIR, name )

      launch_mat_daemons
    end
  end

  def launch_mat_daemons
    if not FileTest.directory? KM_TRANSFER_DIR
      log_error 'launch_mat_daemons: KM_TRANSFER_DIR => ' + KM_TRANSFER_DIR.inspect + ' is not a directory.'
    else
      # Scan through the transfer directory and get the unique listing of log IDs
      log_files = {}

      Dir.entries(KM_TRANSFER_DIR).each do |file|
        if file =~ KM_LOG_FILE_PATTERN
          log_files[file] = true
        end
      end

      first = true
      # Launch MAT Dameons for each file in the transfer directory
      log_files.each do |id,ignore|
        sleep 0.5 if not first
        run_in_background KM_RUBY_CLI + ' ' + KM_MAT_DAEMON, { 'km_id' => id, 'km_config_path' => "#{RAILS_ROOT}/vendor/plugins/app_engine/lib/km_conf.rb", 'km_log_dir' => KMConf::KM_LOG_DIR }
        first = false
      end
    end
  end

  def run_in_background(command, env={}, priority=0, out='/dev/null', err='/dev/null')
    precmd = ''
    env.each do |key,value|
      precmd += 'export ' + key + '="' + value + '" && '
    end

    if priority
      cmd = %|#{precmd} nohup nice -n #{priority} #{command} > #{out} 2> #{err} & echo 0|
      cmd = %|#{precmd}  #{command}| # TODO needs fixing too
      puts cmd
      #pid = IO.popen(cmd).pid # TODO wtf is going on here?
      pid = %x|#{cmd}|
    else
      cmd = precmd + "nohup #{command} > #{out} 2> #{err} & echo 0"
      pid = %x|#{cmd}|
    end
  end

  def now
    unless @now
      @now = Time.now.to_i
    end
    @now
  end

  def log_action(name, props)
    begin
      # Build the line
      line = ''
      # Add the timestamp
      line += now.to_s
      line += '|'
      # Add the action name
      line += escape( name )
      line += '|'
      # Add the person id
      line += get_current_person_id
      line += '|'
      # Build all the valid props
      props_escaped = []

      props = @assigns.merge props

      props.each do |prop_name,data|
        prop_name = escape( prop_name )
        # Validate the prop data
        if data.class == Array
          data.size == 2
          type = data[1]
          ext = get_type_extension type
          if ext
            prop_name += '.' + ext
            prop_value = validate_value(data[0], type)

            if ( prop_value != nil )
              prop_value = escape(prop_value)
              props_escaped << prop_name+'='+prop_value
            end
          end
        end
      end
      line += props_escaped.join('&')
      write_to_log(line)
      check_if_log_needs_rotating
    rescue Exception => e
      log_error(e.message)
    end
  end
  
  def get_type_extension(type)
    types = {
      KM_FLOAT         =>'f',
      KM_INTEGER       =>'i',
      KM_STRING        =>'s',
      KM_TIME_DURATION =>'t',
      KM_TIMESTAMP     =>'d',
      KM_URL           =>'u',
      KM_IP_ADDRESS    =>'a',
      KM_BOOL          =>'b',
      KM_TAGS          =>'c'
    }

    return types[type]
  end

  def is_robot(user_agent)
    if user_agent
      user_agent = user_agent.to_s.downcase

      # We mark something as a bot if it contains any of the $bot_indicators
      # or if it does not contain one of the $browser_indicators. In addition,
      # if the user-agent string contains "mozilla" we make sure it has version
      # information. Finally anything that starts with a word in the $whitelist
      # is never considered a bot.

      whitelist = %w(w3m dillo links elinks lynx)
      whitelist.each do |word|
        return false if user_agent.index(word) == 0
      end

      bot_indicators = %w(bot spider search jeeves crawl seek heritrix slurp thumbnails capture ferret webinator scan retriever accelerator upload digg extractor grub scrub)
      bot_indicators.each do |word|
        return true if user_agent.index word
      end

      browser_indicators = %w(mozilla browser iphone lynx mobile opera icab)
      has_browser_indicator = false

      browser_indicators.each do |word|
        if user_agent.index word
          has_browser_indicator = true
          break
        end
      end

      return true if not has_browser_indicator

      # Check for mozilla version information
      if user_agent.include? "mozilla"
        return true if not user_agent.include? "("
        return true if user_agent !~ /mozilla\/\d+/i
      end
    end
    return false
  end

  def open_log
    # to mimick the PHP behavior. we don't want to have the
    # opening of the log file to fail.
    begin
      @log_fp = File.open KM_CURRENT_LOG, 'a'
    rescue
      #however, let's atleast log that in the error log if we can.
      puts('open_log: Could not open log ' + KM_CURRENT_LOG + ' for writing')
      log_error('open_log: Could not open log ' + KM_CURRENT_LOG + ' for writing')
      @log_fp = nil
    end
  end

  def log_error(message)
    log_message("[ERROR] #{message}", true)
  end

  def log_warning(message)
    log_message("[WARNING] #{message}")
  end

  def close_log
    @log_fp.close if @log_fp
    @log_fp = nil
  end

  #
  # Checks to see if the log needs rotating
  #
  # Checks to see if the log hasn't been rotated in {@link KM_ROTATE_PERIOD} or if the log is over {@link KM_ROTATE_SIZE}
  # Launches MAT Daemons to upload rotated logs
  # @param Boolean If true the log will rotate regardless of {@link KM_ROTATE_PERIOD} and {@link KM_ROTATE_SIZE}
  # @ignore
  #
  def check_if_log_needs_rotating(force=false)
    log_file_size = log_start_time = nil

    if File.exists? KM_CURRENT_LOG
      log_file_size = File.size KM_CURRENT_LOG
      if log_file_size >= 12
        fp = File.open KM_CURRENT_LOG, 'r'
        if not fp
          log_error('check_if_log_needs_rotating: Could not open log ' + KM_CURRENT_LOG + ' for reading')
          return false
        end
        chunk = fp.read 12
        fp.close

        if chunk =~ /\d{10}\|/
          log_start_time = chunk.gsub(/\D/,'').to_i
        end

      end
    end

    if ( (log_file_size &&  log_start_time && (now - log_start_time >= KM_ROTATE_PERIOD || log_file_size > KM_ROTATE_SIZE)) || force )
      # Make the transfer directory if it does not exist yet
      if not File.directory? KM_TRANSFER_DIR
        FileUtils.mkdir_p KM_TRANSFER_DIR
        if not File.directory? KM_TRANSFER_DIR
          log_error('check_if_log_needs_rotating: Could not create KM_TRANSFER_DIR => ' + KM_TRANSFER_DIR.inspect)
          return false
        end
      end
      name = MD5.md5((Time.now.to_f + log_file_size).to_s).to_s + '_' + log_start_time.to_s  +  '_'  +  now.to_s  +  '.log'

      FileUtils.mv KM_CURRENT_LOG, KM_TRANSFER_DIR + '/' + name

      launch_mat_daemons
    end
  end

  def write_to_log(line,skip_rotate_log_check=false)
    opened_here = false
    if not @log_fp
      opened_here = true
      open_log
    end

    if @log_fp #TODO This code is weird. We really expect this to be here, so why check again?
      @log_fp.puts line.gsub("\n",'').gsub("\r",'')
      close_log if opened_here
      if not skip_rotate_log_check
        check_if_log_needs_rotating
      end
      return true
    end
    return false
  end

  def assign(name, value, type)
    begin
      @assigns[name] = [value,type]
    rescue Exception => e
      log_error(e.message)
    end
  end


  def get_current_person_id()
    return KMCookie[:person_id][:value] if KMCookie[:person_id].class == Hash # used for test
    return KMCookie[:person_id] if KMCookie[:person_id]
    # Create a unique person id
    person_id = [ rand, Time.now.to_f, KMServer.to_s ].join('|').b64enc_sha1
    KMCookie['person_id'] = person_id
    return person_id
  end

  def validate_value(prop_value, type)
    return nil if prop_value.nil?

    case type
    when KM_STRING:
      return prop_value.to_s
    when KM_URL:
      return prop_value.to_s
    when KM_TAGS:
      if prop_value.class != Array
        prop_value = prop_value.to_s.split(',')
      end
    result = []
    prop_value.each do |tag|
      result << tag.to_s.downcase.gsub(',','').strip
    end
    return result.join(',')
    when KM_INTEGER:
      begin
        Float(prop_value)
      rescue
        return nil
      end
    return prop_value.to_i
    when KM_TIME_DURATION:
      begin
        Float(prop_value)
      rescue
        return nil
      end
    return prop_value.to_i
    when KM_TIMESTAMP:
      #Float raises an exception if it fails to convert to numeric.
      # perfect way to check if something is numeric
      begin
        Float(prop_value)
      rescue
        return nil
      end
    return prop_value.to_i
    when KM_FLOAT:
      begin
        Float(prop_value)
      rescue
        return nil
      end
    return prop_value.to_i if prop_value.to_i == prop_value #emulate PHP where 3.0 is returned as 3. TODO: come back and check. Code review with john since it can be dangerous.
    return (prop_value.to_f * 1000).round / 1000.0
    when KM_BOOL
      # TODO mimicking behavior of PHP to get tests to pass. code review on this. john
      if prop_value.class == String
        case prop_value.downcase
        when "false"
          return 0
        when "0"
          return 0
        when ""
          return 0
        when "null"
          return nil
        else
          return 1
        end
      end

      case prop_value
      when 0
        return 0
      when false
        return 0
      when nil
        return nil
      else
        return 1
      end
      return nil #it can't come to this
    when KM_IP_ADDRESS
      return prop_value.to_s
    end
    return nil
  end

  def escape(value)
    return CGI::escape(value.to_s)
  end

  def log_message(message, force=false)
    begin
      # Only log the error if KM_ERROR_LOG is a non-NULL value
      if KM_ERROR_LOG
        do_log_error = true

        # If we are checking the mtime of the error log...
        if KM_ERROR_LOG_MIN_TIME and not force
          # If we haven't cached the mtime, then get it
          if not @error_log_mtime or @error_log_mtime == 0
            if File.exists? KM_ERROR_LOG
              @error_log_mtime = File.mtime(KM_ERROR_LOG).to_i
            else
              @error_log_mtime = 0
            end
          end
          # See if the time since the file was last modified was less than our minimum time
          if now - @error_log_mtime < KM_ERROR_LOG_MIN_TIME
            do_log_error = false
          end
        end
        # Log the error
        if do_log_error
          begin
            fp = File.open(KM_ERROR_LOG,'a')
            fp.puts "#{Time.now} #{message}"
            fp.close
          rescue # PHP doesn't handle error, so neither will we for now.
            # TODO should we handle error?
          end
        end
      end
    rescue Exception => e
    end
  end
end

class KMAction
  #@param string $name Tthe name of the action.
  #@param Array $props Properties of the action
  attr_reader :name, :props
  attr_accessor :logged
  def initialize(name, props)
    @name = name
    @props = props
    @logged = false
  end
end
