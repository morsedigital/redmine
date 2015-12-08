set :application, 'redmine'
set :stage, "production"
set :branch, "master"
set :deploy_to, "/home/sites/production/redmine"
set :rvm_string, "2.1.3"

server '83.170.70.107', user: 'www-data', roles: %w{web app}

namespace :symlinks do
  desc "create links to secrets"
  task :secure do
    on roles(:app) do
      within release_path do
        ['database','secrets'].each do |secret|
          secret_file_link="#{release_path}/config/#{secret}.yml"
          secret_file_target="#{shared_path}/config/#{secret}.yml"
          execute "rm -f #{secret_file_link}"
          execute "ln -s #{secret_file_target} #{secret_file_link}"
        end
      end
    end
  end
  desc "create linked folders"
  task :create do
    on roles(:app) do
      within release_path do
        ["log","tmp"].each do |shared_folder|
          shared_folder_path="#{shared_path}/#{shared_folder}"
          begin
            execute "mkdir #{shared_folder_path}"
          rescue
          end
          execute "rm -rf #{release_path}/#{shared_folder}"
          execute "ln -s #{shared_folder_path} #{release_path}/#{shared_folder}"
        end
      end
    end
  end
end

namespace :bundle do
  desc "bundle install"
  task :install do
    on roles(:app) do
      within release_path do
        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use #{fetch(:rvm_string)} && bundle install'"
      end
    end
  end
end

namespace :db do
  desc "migrate database"
  task :migrate do
    on roles(:app) do
      within release_path do

        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use #{fetch(:rvm_string)} && rake RAILS_ENV=production db:migrate'"
      end
    end
  end
end

namespace :rails do
  desc "precompile assets"
  task :precompile_assets do
    on roles(:app) do
      within release_path do
        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use #{fetch(:rvm_string)} && rake RAILS_ENV=production assets:precompile'"
      end
    end
  end

  desc "restart"
  task :restart do
    on roles(:app) do
      within release_path do
        execute "/bin/bash -l -i -c 'cd #{release_path} && rvm use #{fetch(:rvm_string)} && touch tmp/restart.txt'"
      end
    end
  end
end

after "symlinks:create", "symlinks:secure"
after "deploy:updated", "symlinks:create"
after "deploy:updated", "rails:precompile_assets"
before "rails:precompile_assets","bundle:install"
after "deploy:updated", "db:migrate"
after "deploy:finished", "rails:restart"

