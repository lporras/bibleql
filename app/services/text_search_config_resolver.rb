class TextSearchConfigResolver
  CONFIGS = YAML.load_file(Rails.root.join("config/text_search_configs.yml")).freeze
  DEFAULT = "simple"

  def self.for(language)
    candidate = CONFIGS.fetch(language.to_s, DEFAULT)
    installed?(candidate) ? candidate : DEFAULT
  end

  def self.stemming?(language) = self.for(language) != DEFAULT

  def self.installed?(config_name) = installed_configs.include?(config_name)

  def self.installed_configs
    @installed_configs ||= ActiveRecord::Base.connection
      .select_values("SELECT cfgname FROM pg_ts_config").to_set
  end

  def self.reset_installed_configs_cache!
    @installed_configs = nil
  end
end
