class ConfigManager
  class << self
    def load_or_init_config
      APPS.each { |a| REDIS.set(a, '') if REDIS.get(a) == nil }
    end

    def reset_config
      APPS.each { |u| REDIS.set(u, '') }
    end

    def update_config(app, branch)
      REDIS.set(app, branch)
    end

    def next_available_heroku_app(branch)
      APPS.each do |a|
        if REDIS.get(a) == branch
          return a
        end
      end

      APPS.each do |a|
        if REDIS.get(a) == ''
          return a
        end
      end

      nil
    end

    def to_hash
      APPS.each_with_object({}) do |a, h|
        h[a] = REDIS.get(a)
      end
    end

    def release_app_for_branch(branch)
      app = APPS.find{|a| REDIS.get(a) == branch}
      REDIS.set(app, '')
    end
  end
end
