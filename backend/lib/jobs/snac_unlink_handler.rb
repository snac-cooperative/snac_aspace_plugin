require_relative '../types/snac_constellation'
require_relative '../types/snac_resource'
require_relative '../helpers/snac_record_helper'
require_relative '../../../common/snac_preferences'
require_relative '../../../common/snac_link_helper'

class SnacUnlinkHandler
  include JSONModel

  class SnacUnlinkHandlerException < StandardError; end

  def initialize(job, json)
    @job = job
    @json = json
  end


  def process_uri(uri)
    @modified = []

    parsed = JSONModel.parse_reference(uri)
    type = parsed[:type]

    @snac_prefs = SnacPreferences.new(Preference.current_preferences, @json.job['snac_environment'])
    @link_helper = SnacLinkHelper.new(@snac_prefs)

    case type
    when /^agent/
      pfx = "[#{I18n.t('snac_job.common.agent_label')}]"
      unlink_top_level_agent(pfx, uri)

    when /^resource/
      pfx = "[#{I18n.t('snac_job.common.resource_label')}]"
      unlink_top_level_resource(pfx, uri)

    else
      output "#{I18n.t('snac_job.common.unhandled_type')}: #{type} (#{uri})"
    end

    @modified
  end


  private


  def log(msg)
    puts "[SNACJOB] #{msg}"
  end


  def output(msg)
    log msg
    @job.write_output(msg)
  end


  ### agent unlink functions ###


  def include_linked_resources?
    @json.job['include_linked_resources']
  end


  def include_linked_resource?(json)
    json['publish']
  end


  def get_linked_resources(agent_uri)
    # returns a list of resources that link to this agent,
    # along with any roles that agent has with it.

    linked_resources = []

    params = {
      :q => "agent_uris:\"#{agent_uri}\" AND primary_type:\"resource\"",
      :fields => ['*'],
      :page_size => 10,
      :sort => ''
    }

    begin
      # iterate over search result pages, collecting resource relations as we go
      page = 0
      loop do
        page = page + 1
        params[:page] = page

        search = Search.search(params, @job.repo_id)

        search['results'].each do |result|
          json = ASUtils.json_parse(result['json'])

          next unless include_linked_resource?(json)

          linked_resources << {
            'uri' => json['uri']
          }
        end

        break if page == search['last_page'] || search['last_page'] == 0 || search['total_results'] == 0
      end
    rescue
      # just use what we've collected thus far?
    end

    linked_resources
  end


  def unlink_linked_resources(pfx, agent_uri)
    # unlinks each linked resource, if specified

    return unless include_linked_resources?

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_linked_resources')}"

    linked_resources = get_linked_resources(agent_uri)

    # unlink each linked resource
    linked_resources.each_with_index do |linked_resource, index|
      pfx = "  + [#{I18n.t('snac_job.common.linked_resource_label', :index => index+1, :length => linked_resources.length)}]"
      unlink_resource(pfx, linked_resource['uri'])
    end
  end


  def unlink_agent(pfx, uri)
    # removes any snac links from the given agent

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_agent')}: #{uri}"

    agent = SnacRecordHelper.new(uri)
    agent_json = agent.load

    # check for existing snac link
    snac_entry = @link_helper.agent_snac_entry(agent_json)
    if snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.unlink.already_unlinked')}"
      return
    end

    agent_json = @link_helper.agent_unlink(agent_json)

    agent.save(agent_json)
    @modified << agent_json.uri if agent_json.uri

    output "#{pfx} #{I18n.t('snac_job.unlink.unlinked_with_snac')}"
  end


  def unlink_top_level_agent(pfx, uri)
    # unlinks an agent, optionally including any resources linked to it.

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_top_level_agent')}: #{uri}"

    # first, unlink this agent
    unlink_agent(pfx, uri)

    # now unlink linked resources (if specified)
    unlink_linked_resources(pfx, uri)
  end


  ### resource unlink functions ###


  def include_linked_agents?
    @json.job['include_linked_agents']
  end


  def include_linked_agent?(json)
    json['publish']
  end


  def get_linked_agents(resource_uri)
    # returns a list of agents that are linked with this resource

    linked_agents = []

    resource = SnacRecordHelper.new(resource_uri)
    resource_json = resource.load

    resource_json['linked_agents'].each do |linked_agent|
      agent_uri = linked_agent['ref']

      agent = SnacRecordHelper.new(agent_uri)
      agent_json = agent.load

      next unless include_linked_agent?(agent_json)

      linked_agents << {
        'uri' => agent_uri
      }
    end

    linked_agents
  end


  def unlink_linked_agents(pfx, resource_uri)
    # unlinks each linked agent, if specified

    return unless include_linked_agents?

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_linked_agents')}"

    linked_agents = get_linked_agents(resource_uri)

    # unlink each linked agent
    linked_agents.each_with_index do |linked_agent, index|
      pfx = "  + [#{I18n.t('snac_job.common.linked_agent_label', :index => index+1, :length => linked_agents.length)}]"
      unlink_agent(pfx, linked_agent['uri'])
    end
  end


  def unlink_resource(pfx, uri)
    # removes any snac links from the given resource

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_resource')}: #{uri}"

    resource = SnacRecordHelper.new(uri)
    resource_json = resource.load

    # check for existing snac link
    snac_entry = @link_helper.resource_snac_entry(resource_json)
    if snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.unlink.already_unlinked')}"
      return
    end

    resource_json = @link_helper.resource_unlink(resource_json)

    resource.save(resource_json)
    @modified << resource_json.uri if resource_json.uri

    output "#{pfx} #{I18n.t('snac_job.unlink.unlinked_with_snac')}"
  end


  def unlink_top_level_resource(pfx, uri)
    # unlinks a resource, optionally including any agents linked to it.

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_top_level_resource')}: #{uri}"

    # first, unlink this resource
    unlink_resource(pfx, uri)

    # now unlink linked agents (if specified)
    unlink_linked_agents(pfx, uri)
  end


end
