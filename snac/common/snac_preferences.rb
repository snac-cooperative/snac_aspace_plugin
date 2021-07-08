class SnacPreferences

  class SnacPreferencesException < StandardError; end

  # these correspond to the snac_environment enum in schemas/defaults_ext.rb
  SNAC_ENV_PROD = :production
  SNAC_ENV_DEV = :development
  SNAC_ENV_DEFAULT = SNAC_ENV_PROD

  SNAC_ENV_MAPPINGS = {
    SNAC_ENV_PROD => {
      :env_name   => I18n.t("plugins.defaults.snac_environment_production"),
      :web_url    => 'https://snaccooperative.org/',
      :api_url    => 'https://api.snaccooperative.org/',
      :search_url => 'https://snaccooperative.org/search'
    },
    SNAC_ENV_DEV => {
      :env_name   => I18n.t("plugins.defaults.snac_environment_development"),
      :web_url    => 'http://snac-dev.iath.virginia.edu/',
      :api_url    => 'http://snac-dev.iath.virginia.edu/api/',
      :search_url => 'https://snac-dev.iath.virginia.edu/search'
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


  def env_name
    SNAC_ENV_MAPPINGS[@prefs[:env]][:env_name]
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


  def view_url(id = nil)
    url_with_id("#{web_url}view", id)
  end


  def snippet_url(id = nil)
    url_with_id("#{web_url}snippet", id)
  end


  private


  def url_with_id(url, id)
    if id
      url + "/#{id}"
    else
      url
    end
  end


  def get_env(from)
    return SNAC_ENV_DEFAULT if from.nil?

    env = from.to_sym
    return SNAC_ENV_DEFAULT unless SNAC_ENV_MAPPINGS.key?(env)

    env
  end


end
