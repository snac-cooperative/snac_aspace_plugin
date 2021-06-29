require_relative 'snac_environment'

module SNACImportHelper

  class SNACImportHelperException < StandardError; end


  def self.constellation_to_agent(con)
    build_agent(con)
  end


  private


  def self.build_agent(con)
    @agent_hash = {}

    raise SNACImportHelperException.new("missing entity type") unless con.key?('entityType')

    entity_type = con['entityType']['term']

    # set up agent type based on entity type
    case entity_type
    when 'person'
      agent_type = :agent_person
      uri_part = 'people'
    when 'family'
      agent_type = :agent_family
      uri_part = 'families'
    when 'corporateBody'
      agent_type = :agent_corporate_entity
      uri_part = 'corporate_entities'
    else
      raise SNACImportHelperException.new("unhandled entity type: #{entity_type}")
    end

    # build individual pieces of the agent
    build_agent_record_identifiers(con['id'])
    build_agent_names(entity_type, con['nameEntries'])
    # TODO: more pieces?
    #build_agent_languages(con['languagesUsed'])

    # finalize agent
    @agent_hash['uri'] = "/agents/#{uri_part}/import_#{SecureRandom.hex}"

    # return as agent hash plus agent type, as both are needed in the import job
    agent = {:hash => @agent_hash, :type => agent_type}

    agent
  end


  def self.build_agent_record_identifiers(snacid)
    ids = []

    ids <<
      {
        'record_identifier' => "#{SnacEnvironment.web_url}view/#{snacid}",
        'primary_identifier' => true,
        'source' => 'snac'
      }

    @agent_hash['agent_record_identifiers'] = ids
  end


  def self.build_agent_names(entity_type, name_entries)
    names = []

    case entity_type
    when 'person'
      names = build_agent_names_person(name_entries)
    when 'family'
      names = build_agent_names_family(name_entries)
    when 'corporateBody'
      names = build_agent_names_corporate_body(name_entries)
    end

    return if names.empty?

    @agent_hash['names'] = names
  end


  def self.new_name(entry)
    {
      'authorized' => entry['preferenceScore'] == '99',
      'sort_name_auto_generate' => true
    }
  end


  def self.build_agent_names_person(entries)
    names = []

    entries.each do |entry|
      primary_names = []
      rest_of_names = []
      qualifiers = []
      numbers = []
      fuller_forms = []
      dates = []

      if entry.key?('components')
        # also UnspecifiedName?
        entry['components'].each do |component|
          case component['type']['term']
            when 'Name', 'Surname'
              primary_names << component['text']
            when 'Forename'
              rest_of_names << component['text']
            when 'NameAddition'
              qualifiers << component['text']
            when 'Numeration'
              numbers << component['text']
            when 'NameExpansion'
              fuller_forms << component['text']
            when 'Date'
              dates << component['text']
          end
        end
      else
        primary_names << entry['original']
      end

      # adjust for odd cases...

      primary_name = primary_names.first unless primary_names.empty?
      rest_of_name = rest_of_names.first unless rest_of_names.empty?
      fuller_form = fuller_forms.first unless fuller_forms.empty?

      # surname not defined, but forename and/or fuller form is (e.g. "Poor Richard" in Ben Franklin's constellation)
      unless primary_name
        if rest_of_name
          primary_name, rest_of_name = rest_of_name, nil
        elsif fuller_form
          primary_name, fuller_form = fuller_form, nil
        end
      end

      # skip this entry if we still can't determine a primary name
      next unless primary_name

      # now fill out the name entry

      name = new_name(entry)

      name['name_order'] = if primary_names.any? then 'indirect' else 'direct' end
      name['primary_name'] = primary_name
      name['rest_of_name'] = rest_of_name
      name['qualifier'] = qualifiers.join(', ').gsub(', (', ' (') unless qualifiers.empty?
      name['number'] = numbers.first unless numbers.empty?
      name['fuller_form'] = fuller_form
      name['dates'] = dates.first unless dates.empty?

      names << name
    end

    names
  end


  def self.build_agent_names_family(entries)
    names = []

    entries.each do |entry|
      family_names = []
      family_types = []
      qualifiers = []
      locations = []
      dates = []

      if entry.key?('components')
        entry['components'].each do |component|
          case component['type']['term']
            when 'Name', 'FamilyName'
              family_names << component['text']
            when 'FamilyType'
              family_types << component['text']
            when 'ProminentMember'
              qualifiers << component['text']
            when 'Place'
              locations << component['text']
            when 'Date'
              dates << component['text']
          end
        end
      else
        family_names << entry['original']
      end

      name = new_name(entry)

      name['family_name'] = family_names.first unless family_names.empty?
      name['family_type'] = family_types.first unless family_types.empty?
      name['qualifier'] = qualifiers.join(', ').gsub(', (', ' (') unless qualifiers.empty?
      name['location'] = locations.join(', ').gsub(', (', ' (') unless locations.empty?
      name['dates'] = dates.first unless dates.empty?

      names << name
    end

    names
  end


  def self.build_agent_names_corporate_body(entries)
    names = []

    entries.each do |entry|
      primary_names = []
      qualifiers = []
      subordinates = []
      numbers = []
      locations = []
      dates = []
      jurisdiction = false
      conference = false

      if entry.key?('components')
        entry['components'].each do |component|
          case component['type']['term']
            when 'Name'
              primary_names << component['text']
            when 'JurisdictionName'
              primary_names << component['text']
              jurisdiction = true
            when 'NameAddition'
              qualifiers << component['text']
            when 'SubdivisionName'
              subordinates << component['text']
            when 'Number'
              numbers << component['text']
              conference = true
            when 'Location'
              locations << component['text']
              conference = true
            when 'Date'
              dates << component['text']
              conference = true
          end
        end
      else
        primary_names << entry['original']
      end

      name = new_name(entry)

      name['primary_name'] = primary_names.first unless primary_names.empty?
      name['qualifier'] = qualifiers.join(', ').gsub(', (', ' (') unless qualifiers.empty?
      name['number'] = numbers.first unless numbers.empty?
      name['location'] = locations.first unless locations.empty?
      name['dates'] = dates.first unless dates.empty?
      name['jurisdiction'] = jurisdiction
      name['conference_meeting'] = conference

      if subordinates.any?
        name['subordinate_name_1'] = subordinates.shift
        name['subordinate_name_2'] = subordinates.join(', ').gsub(', (', ' (') unless subordinates.empty?
      end

      names << name
    end

    names
  end


  def self.build_agent_languages(langs)
    return if langs == nil or langs.empty?

    # default to the first language in the list
    @agent_hash['language'] = langs[0]['language']['term']
    @agent_hash['script'] = langs[0]['script']['term']
  end


end
