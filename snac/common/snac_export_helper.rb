require_relative 'snac_environment'

module SNACExportHelper

  class SNACExportHelperException < StandardError; end


  def self.constellation_from_agent(agent)
    build_constellation(agent)
  end


  private


  def self.build_constellation(agent)
    type = agent['jsonmodel_type']

    case type
    when 'agent_person'
      entity_type = build_entity_type_person
      name_entries = build_name_entries_person(agent['names'])

    when 'agent_family'
      entity_type = build_entity_type_family
      name_entries = build_name_entries_family(agent['names'])

    when 'agent_corporate_entity'
      entity_type = build_entity_type_corporate_body
      name_entries = build_name_entries_corporate_body(agent['names'])

    else
      raise SNACExportHelperException.new("unhandled agent type: [#{type}]")
    end

    con = {
      'dataType' => 'Constellation',
      'operation' => 'insert',
      'entityType' => entity_type,
      'nameEntries' => name_entries
    }

    con
  end


  def self.build_entity_type_person
    {
      'type' => 'entity_type',
      'dataType' => 'Term',
      'id' => 700,
      'term' => 'person'
    }
  end


  def self.build_entity_type_family
    {
      'type' => 'entity_type',
      'dataType' => 'Term',
      'id' => 699,
      'term' => 'family'
    }
  end


  def self.build_entity_type_corporate_body
    {
      'type' => 'entity_type',
      'dataType' => 'Term',
      'id' => 698,
      'term' => 'corporateBody'
    }
  end


  def self.build_name_component(order, text, id, term)
    return nil if text.nil? or text.empty?

    {
      'dataType' => 'NameComponent',
      'text' => text,
      'operation' => 'insert',
      'order' => order,
      'type' => {
        'id' => id,
        'term' => term,
        'type' => 'name_component'
      }
    }
  end


  def self.build_name_entries_person(names)
    name_entries = []

    names.each do |name|
      # TODO: split SNAC-repeatable fields on commas?  qualifier

      # combine separate fields from AS into SNAC NameAddition field
      pieces = [
        name['title'],
        name['prefix'],
        name['suffix'],
        name['qualifier']
      ].compact

      # attempt to detect and handle (Spirit) entries and build them correctly in SNAC
      additional = []
      spirit = ''
      pieces.each do |piece|
        if piece.match(/\(spirit\)$/i)
          spirit = piece[piece.length - 8..piece.length]
          piece = piece[0..piece.length - 9]
        end
        additional << piece.strip
      end

      # TODO: determine best way to combine separate fields (as well as the order of the pieces above)
      addition = additional.compact.join(', ').gsub(', (', ' (')

      components = []

      components << build_name_component(components.length, name['primary_name'], 400223, 'Surname')       ; components.compact!
      components << build_name_component(components.length, name['rest_of_name'], 400224, 'Forename')      ; components.compact!
      components << build_name_component(components.length, name['number'],       400225, 'Numeration')    ; components.compact!
      components << build_name_component(components.length, name['fuller_form'],  400226, 'NameExpansion') ; components.compact!
      components << build_name_component(components.length, addition,             400236, 'NameAddition')  ; components.compact!
      components << build_name_component(components.length, name['dates'],        400237, 'Date')          ; components.compact!
      components << build_name_component(components.length, spirit,               400236, 'NameAddition')  ; components.compact!

      name_entries << {
        'dataType' => 'NameEntry',
        'operation' => 'insert',
        'preferenceScore' => if name['authorized'] then 99 else 98 end,
        'original' => build_combined_name_heading_person(components),
        'components' => components
      }
    end

    name_entries
  end


  def self.build_name_entries_family(names)
    name_entries = []

    names.each do |name|
      # TODO: split SNAC-repeatable fields on commas?  qualifier, location

      components = []

      components << build_name_component(components.length, name['family_name'], 400233, 'FamilyName')      ; components.compact!
      components << build_name_component(components.length, name['family_type'], 400234, 'FamilyType')      ; components.compact!
      components << build_name_component(components.length, name['qualifier'],   400474, 'ProminentMember') ; components.compact!
      components << build_name_component(components.length, name['location'],    400235, 'Place')           ; components.compact!
      components << build_name_component(components.length, name['dates'],       400237, 'Date')            ; components.compact!

      name_entries << {
        'dataType' => 'NameEntry',
        'operation' => 'insert',
        'preferenceScore' => if name['authorized'] then 99 else 98 end,
        'original' => build_combined_name_heading_family(components),
        'components' => components
      }
    end

    name_entries
  end


  def self.build_name_entries_corporate_body(names)
    name_entries = []

    names.each do |name|
      # TODO: split SNAC-repeatable fields on commas?  qualifier, subordinate_name_2

      components = []

      # TODO: improve subordinates => subdivision mapping when more than two?  requires careful parsing of subordinate_name_2

      if name['jurisdiction']
        components << build_name_component(components.length, name['primary_name'], 400229, 'JurisdictionName') ; components.compact!
      else
        components << build_name_component(components.length, name['primary_name'], 400228, 'Name')             ; components.compact!
      end
      components << build_name_component(components.length, name['qualifier'],          400236, 'NameAddition')    ; components.compact!
      components << build_name_component(components.length, name['subordinate_name_1'], 400230, 'SubdivisionName') ; components.compact!
      components << build_name_component(components.length, name['subordinate_name_2'], 400230, 'SubdivisionName') ; components.compact!
      components << build_name_component(components.length, name['number'],             400231, 'Number')          ; components.compact!
      components << build_name_component(components.length, name['dates'],              400237, 'Date')            ; components.compact!
      components << build_name_component(components.length, name['location'],           400232, 'Location')        ; components.compact!

      name_entries << {
        'dataType' => 'NameEntry',
        'operation' => 'insert',
        'preferenceScore' => if name['authorized'] then 99 else 98 end,
        'original' => build_combined_name_heading_corporate_body(components),
        'components' => components
      }
    end

    name_entries
  end


  def self.build_combined_name_heading_person(components)
    parts = []

    components.each_with_index do |component, index|
      type = component['type']['term']
      part = component['text']

      case type
      when 'Surname', 'Forename'
        # if the surname or forename are followed by a roman numeral, then don't put a comma after them
        unless index < components.length - 1 and components[index + 1]['type']['term'] == 'Numeration'
          part += ','
        end

      when 'Numeration', 'NameAddition', 'Date'
        part += ','

      when 'NameExpansion'
        part = '(' + part + '),'
      end

      parts << part.strip
    end

    name = parts.join(' ').gsub(/,$/, '').gsub(', (', ' (').strip

    name
  end


  def self.build_combined_name_heading_family(components)
    parts = []

    opened_paren = false

    components.each_with_index do |component, index|
      type = component['type']['term']
      part = component['text']

      case type
      when 'FamilyType', 'Date', 'ProminentMember', 'Place'
        unless opened_paren
          part = '(' + part
          opened_paren = true
        end

        if index == components.length - 1
          part = part + ')'
        else
          part = part + ' :'
        end
      end

      parts << part.strip
    end

    name = parts.join(' ').strip

    name
  end


  def self.build_combined_name_heading_corporate_body(components)
    parts = []

    opened_paren = false

    components.each_with_index do |component, index|
      type = component['type']['term']
      part = component['text']

      case type
      when 'Name', 'JurisdictionName', 'SubdivisionName'
        if index < components.length - 1 and components[index + 1]['type']['term'] == 'SubdivisionName'
          part += '.'
        end

      when 'NameAddition'
        part = '(' + part + ').'

      when 'Number', 'Date', 'Location'
        unless opened_paren
          part = '(' + part
          opened_paren = true
        end

        if index == components.length - 1
          part = part + ')'
        else
          part = part + ' :'
        end
      end

      parts << part.strip
    end

    name = parts.join(' ').gsub('..', '.').gsub(/\.$/, '').strip

    name
  end

end
