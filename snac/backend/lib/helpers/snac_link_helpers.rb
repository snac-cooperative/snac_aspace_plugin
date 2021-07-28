module SnacLinkHelpers


  def self.agent_snac_entry(json)
    # returns the entry containing the snac link, if any
    json['agent_record_identifiers'].find { |id| id['source'] == 'snac' }
  end


  def self.agent_snac_id(json)
    # returns the snac constellation id for the snac link if it exists, otherwise 0
    snac_entry = agent_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['record_identifier'].split('/').last.to_i
  end


  def self.agent_exported?(json)
    # returns true if this agent has a snac link
    return !agent_snac_entry(json).nil?
  end


  def self.agent_link(json, url, ark = '')
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


  def self.agent_unlink(json)
    json['agent_record_identifiers'].reject! { |id| id['source'] == 'snac' }
    json['agent_record_identifiers'].reject! { |id| id['record_identifier'].match(/ark:\/99166/) }
    json['agent_record_identifiers'].reject! { |id| id['record_identifier'].match(/snaccooperative/) }

    json
  end


  def self.resource_snac_entry(json)
    # returns the entry containing the snac link, if any
    json['external_documents'].find { |ext| ext['title'] == 'snac' }
  end


  def self.resource_snac_id(json)
    # returns the snac resource id for the snac link if it exists, otherwise 0
    snac_entry = resource_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['location'].split('/').last.to_i
  end


  def self.resource_exported?(json)
    # returns true if this resource has a snac link
    return !resource_snac_entry(json).nil?
  end


  def self.resource_link(json, url)
    json['external_documents'] << {
      'location' => url,
      'title' => 'snac'
    }

    json
  end


  def self.resource_unlink(json)
    json['external_documents'].reject! { |ext| ext['title'] == 'snac' }

    json
  end


end
