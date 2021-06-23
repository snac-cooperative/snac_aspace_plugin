module SnacEnvironment

  class SNACEnvironmentException < StandardError; end

  SNAC_ENV_MAPPINGS = {
    :alpha => {
      :web_url    => 'http://snac-dev.iath.virginia.edu/alpha/',
      :api_url    => 'http://snac-dev.iath.virginia.edu/alpha/rest/api/',
      :search_url => 'https://snac-dev.iath.virginia.edu/alpha/www/search'
    },
    :dev => {
      :web_url    => 'http://snac-dev.iath.virginia.edu/',
      :api_url    => 'http://snac-dev.iath.virginia.edu/api/',
      :search_url => 'https://snac-dev.iath.virginia.edu/search'
    },
    :prod => {
      :web_url    => 'https://snaccooperative.org',
      :api_url    => 'https://api.snaccooperative.org/',
      :search_url => 'https://snaccooperative.org/search'
    }
  }


  def self.web_url
    SNAC_ENV_MAPPINGS[get_env][:web_url]
  end


  def self.api_url
    SNAC_ENV_MAPPINGS[get_env][:api_url]
  end


  def self.search_url
    SNAC_ENV_MAPPINGS[get_env][:search_url]
  end


  private


  def self.get_env
    snac_env = AppConfig[:snac_environment].to_sym
    raise SNACEnvironmentException.new("invalid SNAC environment: [#{snac_env}]") unless SNAC_ENV_MAPPINGS.key?(snac_env)
    snac_env
  end
end
