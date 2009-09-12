namespace :km do
  
  desc "Tail the events being logged"
  task :log, :roles => :app do
    run "tail -f #{shared_path}/log/km.current.log" do |channel, stream, data|
      puts "#{data}"
      break if stream == :err
    end
  end
  
  desc "Tail Kissmetrics' error log"
  task :errors, :roles => :app do
    run "tail -f #{shared_path}/log/km.error.log" do |channel, stream, data|
      puts "#{data}"
      break if stream == :err
    end
  end
  
  desc "Show when logs were last uploaded"
  task :last_upload, :roles => :app do
    run "ls -alh #{shared_path}/log/last_upload | awk '{print $8}'"
    run "echo Current time: && date"
  end
  
  desc "Upload the logs right now"
  task :force_upload, :roles => :app do
    rake "km:force_upload"
  end
  
end
