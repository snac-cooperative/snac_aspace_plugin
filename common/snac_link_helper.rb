class SnacLinkHelper

  class SnacLinkHelperException < StandardError; end

  attr_reader :prefs


  def initialize(prefs)
    @prefs = prefs
  end


  # agent methods


  def agent_snac_entry(json)
    # returns the entry containing the snac link, if any
    json['agent_record_identifiers'].find { |id| id['source'] == 'snac' && @prefs.is_my_url?(id['record_identifier']) }
  end


  def agent_snac_url(json)
    # returns the snac link if it exists
    snac_entry = agent_snac_entry(json)
    return '' if snac_entry.nil?
    snac_entry['record_identifier']
  end


  def agent_snac_id(json)
    # returns the snac constellation id for the snac link if it exists, otherwise 0
    snac_entry = agent_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['record_identifier'].split('/').last.to_i
  end


  def agent_exported?(json)
    # returns true if this agent has a snac link for this snac environment
    return !agent_snac_entry(json).nil?
  end


  def agent_link(json, url, ark = '')
    # adds a link for this snac environment, and also the ARK if it exists and we are working with production snac
    has_primary_id = json['agent_record_identifiers'].map { |id| id['primary_identifier'] }.any?

    json['agent_record_identifiers'] << {
      'record_identifier' => url,
      'primary_identifier' => !has_primary_id,
      'source' => 'snac'
    }

    if @prefs.is_prod? && ark != ''
      json['agent_record_identifiers'] << {
        'record_identifier' => ark,
        'primary_identifier' => false,
        'source' => 'nad'
      }
    end

    json
  end


  def agent_unlink(json)
    # removes any links belonging to this snac environment, and also any ARKs if we are working with production snac
    json['agent_record_identifiers'].reject! { |id| id['source'] == 'snac' && @prefs.is_my_url?(id['record_identifier']) }
    json['agent_record_identifiers'].reject! { |id| id['record_identifier'].match(/ark:\/99166/) } if @prefs.is_prod?

    json
  end


  # resource methods


  def resource_snac_entry(json)
    # returns the entry containing the snac link, if any
    json['external_documents'].find { |ext| ext['title'] == 'snac' && @prefs.is_my_url?(ext['location']) }
  end


  def resource_snac_url(json)
    # returns the snac link if it exists
    snac_entry = resource_snac_entry(json)
    return '' if snac_entry.nil?
    snac_entry['location']
  end


  def resource_snac_id(json)
    # returns the snac resource id for the snac link if it exists, otherwise 0
    snac_entry = resource_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['location'].split('/').last.to_i
  end


  def resource_exported?(json)
    # returns true if this resource has a snac link
    return !resource_snac_entry(json).nil?
  end


  def resource_link(json, url, ignored = '')
    # adds a link for this snac environment, and also the ARK if it exists and we are working with production snac
    json['external_documents'] << {
      'location' => url,
      'title' => 'snac'
    }

    json
  end


  def resource_unlink(json)
    # removes any links belonging to this snac environment, and also any ARKs if we are working with production snac
    json['external_documents'].reject! { |ext| ext['title'] == 'snac' && @prefs.is_my_url?(ext['location']) }

    json
  end


  # convenience methods that attempt to divine underlying type
  # and call the corresponding agent/resource methods above


  def snac_entry(json)
    objtype = get_object_type(json)
    send("#{objtype}_snac_entry", json)
  end


  def snac_url(json)
    objtype = get_object_type(json)
    send("#{objtype}_snac_url", json)
  end


  def snac_id(json)
    objtype = get_object_type(json)
    send("#{objtype}_snac_id", json)
  end


  def exported?(json)
    objtype = get_object_type(json)
    send("#{objtype}_exported?", json)
  end


  def link(json, url, ark = '')
    objtype = get_object_type(json)
    send("#{objtype}_link", json)
  end


  def unlink(json)
    objtype = get_object_type(json)
    send("#{objtype}_unlink", json)
  end


  # miscellaneous methods


  def get_object_type(json)
    return 'agent' if json.key?('agent_record_identifiers')
    return 'resource' if json.key?('external_documents')
    raise SnacLinkHelperException.new('unhandled object type')
  end


end
