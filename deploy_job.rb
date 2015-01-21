class DeployJob
  include SuckerPunch::Job

  CONFIG_MASTER_ADDRESS = 'https://config-master-gthrive.herokuapp.com/'
  REPO = ENV['TRAVIS_REPO_SLUG']
  ACCESS_TOKEN = ENV['GITHUB_ACCESS_TOKEN']
  HEROKU_TOKEN = ENV['HEROKU_TOKEN']
  LOG = Logger.new(STDOUT)

  def redis
    if ENV["REDISTOGO_URL"]
      uri = URI.parse(ENV["REDISTOGO_URL"])
      @redis ||= Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    else
      @redis ||= Redis.new
    end
  end

  def git_wrapper
    @git_wrapper ||= Git.open(Rails.root, log: LOG)
  end

  def gh_client
    @gh_client ||= Octokit::Client.new(access_token: ACCESS_TOKEN)
  end

  def heroku_client
    @heroku_client ||= Heroku::API.new(api_key: HEROKU_TOKEN)
  end

  def create_remote_for(app)
    git_wrapper.add_remote(app, "git@heroku.com:#{app}.git")
  end

  def deploy_to_app(app, branch)
    remote = git_wrapper.remote(app)
    remote = create_remote_for(app) unless remote.url

    `git fetch --unshallow`
    git_wrapper.push(remote, "HEAD:master", force: true)
  end

  def perform(branch, app)
    deploy_result = deploy_to_app(app, branch)
  end
end
