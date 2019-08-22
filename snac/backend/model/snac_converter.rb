# Modified by SNAC

class SNACConverter < MarcXMLConverter

  def self.import_types(show_hidden = false)
    if show_hidden
      [
       {
         :name => "marcxml_snac_subjects_and_agents",
         :description => "Import all subjects and agents from a MARC XML file, setting source to SNAC"
       }
      ]
    else
      []
    end
  end


  def self.instance_for(type, input_file)
    if type == "marcxml_snac_subjects_and_agents"
      self.for_subjects_and_agents_only(input_file)
    else
      nil
    end
  end

  def self.sets_authority_properties(primary = false, authorized = false, type = :name)
    -> auth, node {
      if record_properties[:type] == :authority
        authority_id = primary ? node.inner_text : nil
        auth['authority_id'] = authority_id
        if authorized
          auth['authorized']      = true
          auth['is_display_name'] = true
        end
        if type == :name
          auth['rules']  = 'rda' 
          auth['source'] = 'Social Networks and Archival Context' 
        end
      end
    }
  end
end


SNACConverter.configure do |config|
  [
   "[@tag='720']['@ind1'='1']",
   "[@tag='720']['@ind1'='2']",
   "[@tag='100' or @tag='700'][@ind1='0' or @ind1='1']"
  ].each do |selector|
    config["/record"][:map]["datafield#{selector}"][:map]\
    ["self::datafield"][:defaults][:source] = 'snac'
  end
end
