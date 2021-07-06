class SnacPreferences

  class SnacPreferencesException < StandardError; end

  # these correspond to the snac_environment enum in schemas/defaults_ext.rb
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


  def initialize(from)
    # from will be either:
    # * Preference.current_preferences (backend)
    # * user_prefs (frontend)

    if from.key?('defaults')
      from = from['defaults']
    end

    key = from['snac_api_key'] || ''
    env = get_env(from['snac_environment'])

    @prefs = {:key => key, :env => env}
  end


  def web_url
    SNAC_ENV_MAPPINGS[@prefs[:env]][:web_url]
  end


  def api_url
    SNAC_ENV_MAPPINGS[@prefs[:env]][:api_url]
  end


  def search_url
    SNAC_ENV_MAPPINGS[@prefs[:env]][:search_url]
  end


  def api_key
    @prefs[:key]
  end


  def environment
    @prefs[:env]
  end


  def view_url(id)
    "#{web_url}view/#{id}"
  end


  private


  def get_env(from)
    return SNAC_ENV_DEFAULT if from.nil?

    env = from.to_sym
    return SNAC_ENV_DEFAULT unless SNAC_ENV_MAPPINGS.key?(env)

    env
  end


end
