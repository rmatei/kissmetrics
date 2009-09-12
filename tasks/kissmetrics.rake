namespace :km do
  
  desc "Upload the logs right now"
  task :force_upload => :environment do
    KMCore.instance.launch_mat_daemons
  end
  
end
