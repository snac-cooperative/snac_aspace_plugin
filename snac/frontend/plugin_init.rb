ArchivesSpace::Application.extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))

ArchivesSpace::Application.config.after_initialize do
  ApplicationHelper
  module ApplicationHelper

    def has_snac_link?(agent)
      agent.agent_record_identifiers.each do |id|
        return true if id['source'] == 'snac'
      end

      false
    end

    def snac_url(agent)
      agent.agent_record_identifiers.each do |id|
        return id['record_identifier'] if id['source'] == 'snac'
      end

      ''
    end

  end
end
