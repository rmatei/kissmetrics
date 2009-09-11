#
# Minimal Amazon Transfer Daemon
#
# This is executed automatically from {@link KISSmetrics} to transfer the logs to the KISSmetrics storehouse in the background.
# You shouldn't ever need to use this directly.
# @package KISSmetrics
# @see km_diagnostics.php
#/

#
# load the core library.
# @see KMCore
#/
$: << File.expand_path(File.dirname(__FILE__))
require 'rubygems'
require 'kissmetrics'
require 'fileutils'

# Instantiate a KISSmetrics object in order to use its logging methods
km = KMCore.instance


class Mat
  class << self
    #
    # Determine whether a process is running.
    # @ignore
    # @param int $pid The process ID.
    # @return bool
    #/
    def km_is_process_running(pid)
      process_state = %x|ps #{pid}|
        return process_state.size >= 2
    end

    #
    # Get the full path of the PID-file for the log with a certain ID.
    # @ignore
    # @param int $id The log file id.
    # @return string
    #/
    def pid_file_for(id)
      return KM_TRANSFER_DIR + '/' + id + '.pid'
    end

    #
    # Returns the process ID of the km_mat.php process with a certain ID.
    # @ignore
    # @param int The process ID.
    #/
    def mat_process_for(km_id)
      pid_file = pid_file_for(km_id)
      return false if not File.file? pid_file
      pid = get_pid(pid_file)

      return pid if km_is_process_running(pid)

      return false
    end

    #
    # Reads a process ID from a PID file.
    # @ignore
    # @param string $pid_file
    # @return int
    #/
    def get_pid(pid_file)
      read_file_chunk(pid_file)
    end

    #
    # Returns the ID of a log file that is not currently being uploaded by another daemon.
    # @ignore
    # @param string $km_id The ID of the log file.
    # @param array $ids_to_ignore A list of IDs.  These will not be checked or returned.
    # @return string A log file ID.
    #/
    def get_next_km_id(km_id, ids_to_ignore)
      # Check if that file exists and no one is using it, if so return it
      return km_id if km_id && ! mat_process_for(km_id)
      # Find the first file that does not have a MATDaemon running it

      Dir.entries(KM_TRANSFER_DIR).each do |file|
        file.scan(KM_LOG_FILE_PATTERN) do |id|
          id = id.first
          if not ids_to_ignore.include? id and not mat_process_for(id)
            return id
          end
        end
      end
      return nil
    end

    #
    # Returns the number of daemons currently running.
    # @ignore
    # @return int
    #/
    def num_mat_daemons
      %x{ps wwux | grep km_mat}.split("\n").reject { |line| line =~ /(grep|&&|vim)/ }.size
    end

    def read_file_chunk(file,chunk_size=1024)
      if File.file? file
        fp = File.open file, "r"
        return nil unless fp
        chunk = fp.read(chunk_size).strip
        fp.close
        begin
          Float(pid)
        rescue
          return nil
        end
        return chunk.to_i
      end
      return nil
    end


    #
    # Checks to see if curl and gzip are available.  Prints out the last time the logs were uploaded.
    # @ignore
    # @return int return code
    #/
    def run_diagnostic
      # print out time of last successful upload
      found_last_upload = false
      last_upload_path = KM_LOG_DIR + '/last_upload'
      print("\n----------------------------------------------------------------------\nTIME OF LAST UPLOAD: ")
      last_upload = read_file_chunk(last_upload_path)
      if last_upload
        puts Time.at(last_upload).strftime("%D %T (%Z)")
      else
        print("You have not uploaded any logs yet (or unable to read time of last upload).\n")
      end
      print("----------------------------------------------------------------------\n")
      return 7
    end
  end
end


#
# A process for uploading a log file.
# @ignore
# @package KISSmetrics
#/
class MATDaemon

  #
  # Constructor
  # @param string $id The ID of the log file to upload.
  #/
  def initialize(id)
    @id             = id
    @file_to_upload = KM_TRANSFER_DIR + '/' + id  + '.log'
    @gzip_file      = KM_TRANSFER_DIR + '/' + File.basename(@file_to_upload) + '.gz'
    @pid_file       = Mat::pid_file_for(id)
  end

  #
  # Get the process ID for this daemon.
  # @ignore
  # @return int
  #/
  def get_pid
    return Mat::get_pid(@pid_file)
  end

  def write_int_to_file(file,int)
    fp = File.open file, 'w'
    fp.write int
    fp.close
  end


  #
  # Write the processed ID to a file.  The PID is used to signify to other daemons that the corresponding log file is being uploaded by a daemon.
  # @ignore
  #/
  def write_pid_file
    write_int_to_file @pid_file, $$
  end

  #
  # Delete the PID file.
  # @ignore
  #/
  def remove_pid_file
    FileUtils.rm @pid_file if File.file? @pid_file
  end


  #
  # Upload the log file to S3.
  # @ignore
  #
  def run
    km = KMCore.instance

    # if pid_file
    already_running = false
    pid = get_pid
    if not pid.nil?
      # see if process specified in pid file is running
      already_running = km_is_process_running(pid)
    end

    # if no pid file or process is not running
    if not already_running
      # if no .log and .tar file
      if !File.file?(@gzip_file) && !File.file?(@file_to_upload)
        # log error
        km.log_error('MATDaemon :: No log (' + @file_to_upload.inspect + ') and no tar file (' + @gzip_file.inspect + ')' )
        return false
      end

      # create pid file with my pid as the value
      write_pid_file

      # if there is .log file
      if File.file? @file_to_upload
        # rm the .tar.gz if it exists
        # this is to handle a case where creating the tar got interuppted
        FileUtils.rm @gzip_file if File.file? @gzip_file

        # gzip && rm .log
        cmd = %|#{KM_GZIP}  -c #{@file_to_upload} > #{@gzip_file}|
        output = %x|#{cmd}|
        return_value = $?.exitstatus

        # Only remove the .log if creating the .tar is succcessful
        if (return_value == 0)
          FileUtils.rm @file_to_upload if File.file? @gzip_file
        end
      end

      if File.file? @gzip_file
        km_sleep_time = ENV['km_sleep_time']; # For unit testing purposes
        sleep km_sleep_time.to_i if km_sleep_time

        # use curl to upload the .gz
        upload_cmd = upload_command(@gzip_file)
        output = %x|#{upload_cmd}|
          return_value = $?.exitstatus

        # if curl was successful
        if (return_value == 0)
          FileUtils.rm @gzip_file if File.file? @gzip_file

          # write time of last successful upload to a file
          write_int_to_file(KM_LOG_DIR + '/last_upload', Time.now.to_i)
          return true
        else
          km.log_error('MATDaemon :: curl `' + upload_cmd + '` failed (' + return_value.inspect + ') => ' + output)
          return false
        end
      end
    end
    return false
  end

  # Return a curl command - complete with policy file, signature, and output redirection - for POSTing a file to S3.
  # @ignore
  # @param string $file_path A path to a file.
  # @return string
  #/
  def upload_command(file_path)
    command = "#{KM_CURL} -f --silent --show-error --connect-timeout #{KM_UPLOAD_CONNECT_TIMEOUT} --form 'AWSAccessKeyId=#{KM_AWS_ID}' " \
      + "--form 'key=#{KM_UPLOAD_PATH_PREFIX}#{KM_API_KEY}/#{File.basename(file_path)}' --form 'policy=#{KM_UPLOAD_POLICY}' " \
      + "--form 'signature=#{KM_UPLOAD_POLICY_SIGNATURE}' --form 'file=@#{file_path}' #{KM_UPLOAD_URL}" \
      + ' 2>&1'
    return command
  end
end

def main
  km_id = ENV['km_id']
  if not km_id
    raise 'No km_id'
  else
    if (km_id == 'diagnostic')
      exit(Mat::run_diagnostic)
    end

    ids_to_ignore = {}

    if ( Mat::num_mat_daemons > KM_MAX_MAT_DAEMONS )
      raise("num_mat_daemons: " + Mat::num_mat_daemons.to_s + ' (vs ' + KM_MAX_MAT_DAEMONS.to_s + ') - exiting now')
    end

    while km_id = Mat::get_next_km_id(km_id,ids_to_ignore)
      daemon = MATDaemon.new km_id
      ids_to_ignore[km_id] = true if not daemon.run
      daemon.remove_pid_file

      km_id = nil
    end
  end
end

begin
  main
rescue
  error_msg = "MATDaemon :: #{$!} from " + $!.backtrace.join(" ")
  puts "MATDaemon :: #{$!} from " + $!.backtrace.join("\n    ")
  km.log_error error_msg
  exit(1)
end
