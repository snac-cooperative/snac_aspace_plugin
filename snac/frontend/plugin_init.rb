ArchivesSpace::Application.extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

ArchivesSpace::Application.config.after_initialize do
  ApplicationHelper
  module ApplicationHelper

    def agent_has_snac_link?(agent)
      agent.agent_record_identifiers.each do |id|
        return true if id['source'] == 'snac'
      end

      false
    end

    def agent_snac_url(agent)
      agent.agent_record_identifiers.each do |id|
        return id['record_identifier'] if id['source'] == 'snac'
      end

      ''
    end

    def resource_has_snac_link?(resource)
      resource.external_documents.each do |ext|
        return true if ext['title'] == 'snac'
      end

      false
    end

    def resource_snac_url(resource)
      resource.external_documents.each do |ext|
        return ext['location'] if ext['title'] == 'snac'
      end

      ''
    end

  end
end
