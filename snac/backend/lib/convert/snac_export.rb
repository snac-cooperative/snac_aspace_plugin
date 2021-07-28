class SnacExport

  class SnacExportException < StandardError; end


  def constellation_from_agent(agent)
    build_constellation(agent)
  end


  def resource_from_resource(resource)
    build_resource(resource)
  end


  private


  def build_constellation(agent)
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
      raise SnacExportException.new("unhandled agent type: [#{type}]")
    end

    resource_relations = []
    linked_resources = agent['linked_resources'] || []
    linked_resources.each do |res|
      resource_relations.concat(build_resource_relations(res))
    end
    resource_relations.compact!

    con = {
      'dataType' => 'Constellation',
      'operation' => 'insert',
      'entityType' => entity_type,
      'nameEntries' => name_entries
    }

    con['resourceRelations'] = resource_relations unless resource_relations.empty?

    con
  end


  def build_entity_type_person
    {
      'type' => 'entity_type',
      'dataType' => 'Term',
      'id' => 700,
      'term' => 'person'
    }
  end


  def build_entity_type_family
    {
      'type' => 'entity_type',
      'dataType' => 'Term',
      'id' => 699,
      'term' => 'family'
    }
  end


  def build_entity_type_corporate_body
    {
      'type' => 'entity_type',
      'dataType' => 'Term',
      'id' => 698,
      'term' => 'corporateBody'
    }
  end


  def build_name_component(order, text, id, term)
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


  def build_name_entries_person(names)
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


  def build_name_entries_family(names)
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


  def build_name_entries_corporate_body(names)
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


  def build_combined_name_heading_person(components)
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


  def build_combined_name_heading_family(components)
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


  def build_combined_name_heading_corporate_body(components)
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


  def build_document_type_archival_resource
    {
      'type' => 'document_type',
      'id' => 696,
      'term' => 'ArchivalResource'
    }
  end


  def build_document_type_bibliographic_resource
    {
      'type' => 'document_type',
      'id' => 697,
      'term' => 'BibliographicResource'
    }
  end


  def build_document_type_digital_archival_resource
    {
      'type' => 'document_type',
      'id' => 400479,
      'term' => 'DigitalArchivalResource'
    }
  end


  def build_document_type_oral_history_resource
    {
      'type' => 'document_type',
      'id' => 400623,
      'term' => 'OralHistoryResource'
    }
  end


  def build_resource(resource)
    # required:

    # title
    title = resource['title']

    # documentType
    # AS default resource types: ["collection", "publications", "papers", "records"]
    # but these can be modified.  no reliable way to map, so default to archival resource
    doc_type = build_document_type_archival_resource

    # optional:

    # link
    # "link": "https:\/\/mylink.com",
    # TODO: link to this AS repo, if public?
    link = ''

    # abstract
    # get source note, preferring prefer abstract over scope and contents
    # FIXME: should only grab first paragraph of scope and contents
    abstract = ''
    src_note = resource['notes'].find { |note| note['type'] == 'abstract' }
    src_note = resource['notes'].find { |note| note['type'] == 'scopecontent' } unless src_note
    if src_note
      case src_note['jsonmodel_type']
      when 'note_singlepart'
        abstract = src_note['content'].join("\n\n\n")
      when 'note_multipart'
        abstract = src_note['subnotes'].select { |s| s['jsonmodel_type'] == 'note_text' }.map { |s| s['content'] }.join("\n\n\n")
      end
    end

    # extents
    extents = []
    resource['extents'].each do |ext|
      type = I18n.t("enumerations.extent_extent_type.#{ext['extent_type']}")
      portion = I18n.t("enumerations.extent_portion.#{ext['portion']}")
      s = "#{ext['number']} #{type} (#{portion})"

      ['container_summary', 'physical_details', 'dimensions'].each do |field|
        if ext[field] and ext[field] != ''
          label = I18n.t("extent.#{field}")
          s += ", #{label}: #{ext[field]}"
        end
      end

      extents << s
    end

    repository = existing_repository(resource['holding_repo_id'])

    res = {
      'dataType' => 'Resource',
      'operation' => 'insert',
      'title' => title,
      'documentType' => doc_type
    }

    res['link'] = link unless link == ''
    res['abstract'] = abstract unless abstract == ''
    res['extent'] = extents.join('; ') unless extents.empty?
    res['repository'] = repository unless repository.nil?

    res
  end


  def build_resource_relation_creator_of
    {
      'type' => 'document_role',
      'id' => 692,
      'term' => 'creatorOf'
    }
  end


  def build_resource_relation_contributor_of
    {
      'type' => 'document_role',
      'id' => 695,
      'term' => 'contributorOf'
    }
  end


  def build_resource_relation_editor_of
    {
      'type' => 'document_role',
      'id' => 694,
      'term' => 'editorOf'
    }
  end


  def build_resource_relation_referenced_in
    {
      'type' => 'document_role',
      'id' => 693,
      'term' => 'referencedIn'
    }
  end


  def existing_resource(id)
    {
      'dataType' => 'Resource',
      'id' => id
    }
  end


  def existing_repository(id)
    {
      'dataType' => 'Constellation',
      'id' => id
    }
  end


  def build_resource_relations(linked_resource)
    relations = []

    relation = {
      'dataType' => 'ResourceRelation',
      'operation' => 'insert',
      'resource' => existing_resource(linked_resource['snac_id'])
    }

    # "creator", "source", "subject"
    linked_resource['roles'].each do |role|
      case role
      when 'creator'
        role = build_resource_relation_creator_of
      when 'source'
        role = build_resource_relation_contributor_of
      when 'subject'
        role = build_resource_relation_referenced_in
      else
        next
      end

      relation['role'] = role
      relations << relation
    end

    relations
  end


end
