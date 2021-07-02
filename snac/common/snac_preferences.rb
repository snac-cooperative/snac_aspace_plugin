class SnacPreferences
  include JSONModel

  class SnacPreferencesException < StandardError; end

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


  def initialize
    @prefs = get_preferences
puts ''
puts "########## @prefs: #{@prefs}"
puts ''
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


  def view_url(id)
    "#{web_url}view/#{id}"
  end

  private


  def get_preferences
    # gets the preferences for the current request context

    prefs = Preference.current_preferences
    #prefs = JSONModel::HTTP::get_json("/current_global_preferences")

puts ''
puts "########## prefs: #{prefs}"
puts ''

    key = prefs['defaults']['snac_api_key'] || ''
    env = get_env(prefs['defaults']['snac_environment'])
    cfg = get_env_from_config

puts ''
puts "######### key: #{key}"
puts "######### env: #{env}"
puts "######### cfg: #{cfg}"
puts ''

    {:key => key, :env => cfg}
  end


  def get_env(from)
    return SNAC_ENV_DEFAULT if from.nil?

    env = from.to_sym
    return SNAC_ENV_DEFAULT unless SNAC_ENV_MAPPINGS.key?(env)

    env
  end


  def get_env_from_config
    return SNAC_ENV_DEFAULT unless AppConfig.has_key?(:snac_environment)
    get_env(AppConfig[:snac_environment])
  end


end
