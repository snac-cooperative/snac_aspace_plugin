module SnacEnvironment

  class SNACEnvironmentException < StandardError; end

  SNAC_ENV_ALPHA = :alpha
  SNAC_ENV_DEV = :dev
  SNAC_ENV_PROD = :prod
  SNAC_ENV_DEFAULT = SNAC_ENV_DEV

  SNAC_ENV_MAPPINGS = {
    SNAC_ENV_ALPHA => {
      :web_url    => 'http://snac-dev.iath.virginia.edu/alpha/',
      :api_url    => 'http://snac-dev.iath.virginia.edu/alpha/rest/api/',
      :search_url => 'https://snac-dev.iath.virginia.edu/alpha/www/search'
    },
    SNAC_ENV_DEV => {
      :web_url    => 'http://snac-dev.iath.virginia.edu/',
      :api_url    => 'http://snac-dev.iath.virginia.edu/api/',
      :search_url => 'https://snac-dev.iath.virginia.edu/search'
    },
    SNAC_ENV_PROD => {
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
    if AppConfig.has_key?(:snac_environment)
      # use supplied value if valid, otherwise fallback to default environment
      snac_env = AppConfig[:snac_environment].to_sym
      snac_env = SNAC_ENV_DEFAULT unless SNAC_ENV_MAPPINGS.key?(snac_env)
    else
      # no value supplied, use default environment
      snac_env = SNAC_ENV_DEFAULT
    end

    snac_env
  end
end
