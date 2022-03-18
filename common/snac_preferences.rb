class SnacPreferences

  class SnacPreferencesException < StandardError; end

  # these correspond to the snac_environment enum in schemas/defaults_ext.rb
  SNAC_ENV_PROD = :production
  SNAC_ENV_DEV = :development
  SNAC_ENV_DEFAULT = SNAC_ENV_PROD

  SNAC_ENV_MAPPINGS = {
    SNAC_ENV_PROD => {
      :env_label  => I18n.t("plugins.defaults.snac_production_label"),
      :web_url    => 'https://snaccooperative.org/',
      :api_url    => 'https://api.snaccooperative.org/',
      :search_url => 'https://snaccooperative.org/search'
    },
    SNAC_ENV_DEV => {
      :env_label  => I18n.t("plugins.defaults.snac_development_label"),
      :web_url    => 'http://snac-dev.iath.virginia.edu/',
      :api_url    => 'http://snac-dev.iath.virginia.edu/api/',
      :search_url => 'https://snac-dev.iath.virginia.edu/search'
    }
  }


  def initialize(from)
    # from will be either:
    # * Preference.current_preferences (backend)
    # * user_prefs (frontend)

    if from.is_a?(Hash) && from.key?('defaults')
      from = from['defaults']
    end

    env = get_env(from)
    key = from["snac_#{env}_api_key"] || ''

    @prefs = {:key => key, :env => env}
  end


  def env_label
    SNAC_ENV_MAPPINGS[@prefs[:env]][:env_label]
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


  def has_api_key?
    api_key != ''
  end


  def environment
    @prefs[:env].to_s
  end


  def view_url(id = nil)
    url_with_id("#{web_url}view", id)
  end


  def snippet_url(id = nil)
    url_with_id("#{web_url}snippet", id)
  end


  def resource_url(id = nil)
    url_with_id("#{web_url}vocab_administrator/resources", id)
  end


  def is_prod?
    @prefs[:env] == SNAC_ENV_PROD
  end


  def is_dev?
    @prefs[:env] == SNAC_ENV_DEV
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

    if from.is_a?(Hash) && from.key?('snac_environment')
      val = from['snac_environment']
    elsif from.is_a?(String)
      val = from
    else
      return SNAC_ENV_DEFAULT
    end

    env = val.to_sym
    return SNAC_ENV_DEFAULT unless SNAC_ENV_MAPPINGS.key?(env)

    env
  end


end
