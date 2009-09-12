namespace :km do
  
  task :log, :roles => :app do
    run "tail -f #{shared_path}/log/km.current.log" do |channel, stream, data|
      puts "#{data}"
      break if stream == :err
    end
  end
  
  task :errors, :roles => :app do
    run "tail -f #{shared_path}/log/km.error.log" do |channel, stream, data|
      puts "#{data}"
      break if stream == :err
    end
  end
  
  task :last_upload, :roles => :app do
    run "ls -alh #{shared_path}/log/last_upload | awk '{print $8}'"
    run "echo Current time: && date"
  end
  
end
