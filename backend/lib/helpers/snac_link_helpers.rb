require_relative '../../../common/snac_preferences'

class SnacLinkHelpers

  class SnacLinkHelpersException < StandardError; end

  attr_reader :prefs


  def initialize
    @prefs = SnacPreferences.new(Preference.current_preferences)
    @env = @prefs.environment
  end


  def agent_snac_entry(json)
    send("agent_snac_entry_#{@env}", json)
  end


  def agent_snac_id(json)
    send("agent_snac_id_#{@env}", json)
  end


  def agent_exported?(json)
    send("agent_exported_#{@env}?", json)
  end


  def agent_link(json, url, ark = '')
    send("agent_link_#{@env}", json, url, ark)
  end


  def agent_unlink(json)
    send("agent_unlink_#{@env}", json)
  end


  def resource_snac_entry(json)
    send("resource_snac_entry_#{@env}", json)
  end


  def resource_snac_id(json)
    send("resource_snac_id_#{@env}", json)
  end


  def resource_exported?(json)
    send("resource_exported_#{@env}?", json)
  end


  def resource_link(json, url)
    send("resource_link_#{@env}", json, url)
  end


  def resource_unlink(json)
    send("resource_unlink_#{@env}", json)
  end


  private


  def agent_snac_entry_production(json)
    # returns the entry containing the snac link, if any
    json['agent_record_identifiers'].find { |id| id['source'] == 'snac' }
  end


  def agent_snac_entry_development(json)
    # returns the entry containing the snac link, if any
    json['agent_record_identifiers'].find { |id| id['source'] == 'snac' }
  end


  def agent_snac_id_production(json)
    # returns the snac constellation id for the snac link if it exists, otherwise 0
    snac_entry = agent_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['record_identifier'].split('/').last.to_i
  end


  def agent_snac_id_development(json)
    # returns the snac constellation id for the snac link if it exists, otherwise 0
    snac_entry = agent_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['record_identifier'].split('/').last.to_i
  end


  def agent_exported_production?(json)
    # returns true if this agent has a snac link
    return !agent_snac_entry(json).nil?
  end


  def agent_exported_development?(json)
    # returns true if this agent has a snac link
    return !agent_snac_entry(json).nil?
  end


  def agent_link_production(json, url, ark = '')
    has_primary_id = json['agent_record_identifiers'].map { |id| id['primary_identifier'] }.any?

    json['agent_record_identifiers'] << {
      'record_identifier' => url,
      'primary_identifier' => !has_primary_id,
      'source' => 'snac'
    }

    if ark != ''
      json['agent_record_identifiers'] << {
        'record_identifier' => ark,
        'primary_identifier' => false,
        'source' => 'nad'
      }
    end

    json
  end


  def agent_link_development(json, url, ark = '')
    has_primary_id = json['agent_record_identifiers'].map { |id| id['primary_identifier'] }.any?

    json['agent_record_identifiers'] << {
      'record_identifier' => url,
      'primary_identifier' => !has_primary_id,
      'source' => 'snac'
    }

    if ark != ''
      json['agent_record_identifiers'] << {
        'record_identifier' => ark,
        'primary_identifier' => false,
        'source' => 'nad'
      }
    end

    json
  end


  def agent_unlink_production(json)
    json['agent_record_identifiers'].reject! { |id| id['source'] == 'snac' }
    json['agent_record_identifiers'].reject! { |id| id['record_identifier'].match(/ark:\/99166/) }
    json['agent_record_identifiers'].reject! { |id| id['record_identifier'].match(/snaccooperative/) }

    json
  end


  def agent_unlink_development(json)
    json['agent_record_identifiers'].reject! { |id| id['source'] == 'snac' }
    json['agent_record_identifiers'].reject! { |id| id['record_identifier'].match(/ark:\/99166/) }
    json['agent_record_identifiers'].reject! { |id| id['record_identifier'].match(/snaccooperative/) }

    json
  end


  def resource_snac_entry_production(json)
    # returns the entry containing the snac link, if any
    json['external_documents'].find { |ext| ext['title'] == 'snac' }
  end


  def resource_snac_entry_development(json)
    # returns the entry containing the snac link, if any
    json['external_documents'].find { |ext| ext['title'] == 'snac' }
  end


  def resource_snac_id_production(json)
    # returns the snac resource id for the snac link if it exists, otherwise 0
    snac_entry = resource_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['location'].split('/').last.to_i
  end


  def resource_snac_id_development(json)
    # returns the snac resource id for the snac link if it exists, otherwise 0
    snac_entry = resource_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['location'].split('/').last.to_i
  end


  def resource_exported_production?(json)
    # returns true if this resource has a snac link
    return !resource_snac_entry(json).nil?
  end


  def resource_exported_development?(json)
    # returns true if this resource has a snac link
    return !resource_snac_entry(json).nil?
  end


  def resource_link_production(json, url)
    json['external_documents'] << {
      'location' => url,
      'title' => 'snac'
    }

    json
  end


  def resource_link_development(json, url)
    json['external_documents'] << {
      'location' => url,
      'title' => 'snac'
    }

    json
  end


  def resource_unlink_production(json)
    json['external_documents'].reject! { |ext| ext['title'] == 'snac' }

    json
  end


  def resource_unlink_development(json)
    json['external_documents'].reject! { |ext| ext['title'] == 'snac' }

    json
  end


end
