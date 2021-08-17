ArchivesSpace::Application.extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

ArchivesSpace::Application.config.after_initialize do
  ApplicationHelper
  module ApplicationHelper

    def agent_has_snac_link?(agent)
      agent['agent_record_identifiers'].each do |id|
        return true if id['source'] == 'snac'
      end

      false
    end

    def agent_snac_url(agent)
      agent['agent_record_identifiers'].each do |id|
        return id['record_identifier'] if id['source'] == 'snac'
      end

      ''
    end

    def resource_has_snac_link?(resource)
      resource['external_documents'].each do |ext|
        return true if ext['title'] == 'snac'
      end

      false
    end

    def resource_snac_url(resource)
      resource['external_documents'].each do |ext|
        return ext['location'] if ext['title'] == 'snac'
      end

      ''
    end

    def has_snac_link?(type, obj)
      case type
      when 'agent'
        agent_has_snac_link?(obj)
      when 'resource'
        resource_has_snac_link?(obj)
      else
        false
      end
    end

    def snac_url(type, obj)
      case type
      when 'agent'
        agent_snac_url(obj)
      when 'resource'
        resource_snac_url(obj)
      else
        ''
      end
    end

  end
end
