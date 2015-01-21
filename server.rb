require 'sinatra'
require 'newrelic_rpm'
require 'json'
require 'redis'
require 'yaml'
require 'sucker_punch'

require_relative 'config_manager'
require_relative 'deploy_job'

CONFIG_PATH = File.join __dir__, 'ci-deploys.json'

class ApiKeys
  class << self
    attr_writer :keys

    def keys
      @keys ||= {}
    end

    def load(h)
      keys.merge(h)
      h.each do |k,v|
        ENV[k.to_s] = v.to_s
      end
    end
  end
end

configure do
  if ENV["REDISTOGO_URL"]
    uri = URI.parse(ENV["REDISTOGO_URL"])
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  else
    REDIS = Redis.new
  end
  APPS = (ENV['DEPLOY_URLS'] || '').split(',')
  if File.exist? 'secrets.yml'
    ApiKeys.load YAML.load open('secrets.yml').read
  end

  ConfigManager.load_or_init_config
end

get '/reserve_next_app/:branch' do
  content_type :json

  next_app = ConfigManager.next_available_heroku_app(params[:branch])

  if next_app
    ConfigManager.update_config(next_app, params[:branch])
    { success: true, app: next_app }.to_json
  else
    { success: false, message: "No available apps" }.to_json
  end
end

get '/config' do
  content_type :json
  ConfigManager.to_hash.to_json
end

get '/reset_config/:password' do
  content_type :json
  if params[:password] == ENV['RESET_PASSWORD']
    ConfigManager.reset_config

    status 200
    ConfigManager.to_hash.to_json
  else
    status 401
    {nope: "wrong"}.to_json
  end
end

post '/pr_webhook' do
  data = JSON.parse(request.body.read)
  if data['action'] == 'closed'
    puts "Detected PR closed: #{data['number']}"
    ConfigManager.release_app_for_branch(data['pull_request']['head']['ref'])
  end
end
