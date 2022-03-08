require_relative '../types/snac_constellation'
require_relative '../types/snac_resource'
require_relative '../helpers/snac_record_helper'
require_relative '../helpers/snac_link_helpers'
require_relative '../convert/snac_export'

class SnacExportHandler
  include JSONModel

  class SnacExportHandlerException < StandardError; end

  def initialize(job, json)
    @job = job
    @json = json
  end


  def process_uri(uri)
    @modified = []

    parsed = JSONModel.parse_reference(uri)
    type = parsed[:type]

    case type
    when /^agent/
      pfx = "[#{I18n.t('snac_job.common.agent_label')}]"
      export_top_level_agent(pfx, uri)

    when /^resource/
      pfx = "[#{I18n.t('snac_job.common.resource_label')}]"
      export_top_level_resource(pfx, uri)

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


  ### repository export functions ###


  def export_repository
    # exports the current repository to a snac constellation, if not already exported.
    # returns the snac id for the constellation in either case.

    return @holding_repo_id if @holding_repo_id

    repo = Repository.to_jsonmodel(@job.repo_id)

    agent_uri = repo['agent_representation']['ref']

    agent = SnacRecordHelper.new(agent_uri)
    agent_json = agent.load

    if SnacLinkHelpers.agent_exported?(agent_json)
      @holding_repo_id = SnacLinkHelpers.agent_snac_id(agent_json)
      return @holding_repo_id
    end

    pfx = "  + [#{I18n.t('snac_job.common.holding_repository_label')}]"
    @holding_repo_id = export_agent(pfx, agent_uri)
    # cosmetic: also add the repo to the list of modified records (to go along with agent representation)
    # ...actually it's not so cosmetic, so maybe not (it displays as '/resolve/readonly?uri=%2Frepositories%2F...')
    #@modified << repo['uri'] if repo['uri']

    @holding_repo_id
  end


  ### agent export functions ###


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

          # find roles matching this agent
          # "creator", "source", "subject"
          roles = json['linked_agents'].select { |a| a['ref'] == agent_uri }.map { |a| a['role'] }
          linked_resources << {
            'roles' => roles,
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


  def export_linked_resources(pfx, agent_uri)
    # exports each linked resource, if specified

    return [] unless include_linked_resources?

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_linked_resources')}"

    linked_resources = get_linked_resources(agent_uri)

    # export each linked resource
    linked_resources.each_with_index do |linked_resource, index|
      pfx = "  + [#{I18n.t('snac_job.common.linked_resource_label', :index => index+1, :length => linked_resources.length)}]"
      id = export_resource(pfx, linked_resource['uri'])
      linked_resource['snac_id'] = id
    end

    linked_resources
  end


  def update_agent(pfx, id, linked_resources = [])
    # adds resource relations to this identity in SNAC, if not already present

    return if linked_resources.empty?

    output "#{pfx} #{I18n.t('snac_job.export.linked_agent_checking_relations')}"

    con = SnacConstellation.new(id)

    # determine resource relation changes, if any

    cur_resource_relations = con.constellation['resourceRelations'] || []
    new_resource_relations = SnacExport.build_resource_relations(linked_resources)

    # collect existing resource id/role pairs in snac
    cur_id_role_pairs = []
    cur_resource_relations.each do |r|
      cur_id_role_pairs << {
        :resource_id => r['resource']['id'].to_i,
        :role_id => r['role']['id'].to_i
      }
    end

    # for each new linked resource/role pair, queue it for export if not already in snac
    resource_relations = []
    new_resource_relations.each do |r|
      pair = {:resource_id => r['resource']['id'], :role_id => r['role']['id']}
      next if cur_id_role_pairs.include?({:resource_id => r['resource']['id'], :role_id => r['role']['id']})
      resource_relations << r
    end

    # update snac identity with new resource relations, if any

    if resource_relations.empty?
      output "#{pfx} #{I18n.t('snac_job.export.linked_agent_relations_exist')}"
      return
    end

    output "#{pfx} #{I18n.t('snac_job.export.linked_agent_adding_relations')}"

    con.update_and_publish({'resourceRelations' => resource_relations})
  end


  def export_agent(pfx, uri, linked_resources = [])
    # exports an agent to a snac constellation, if not already exported.
    # returns the snac id for the constellation in either case.

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_agent')}: #{uri}"

    agent = SnacRecordHelper.new(uri)
    agent_json = agent.load

    # check for existing snac link
    snac_entry = SnacLinkHelpers.agent_snac_entry(agent_json)
    unless snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.export.already_exported')}: #{snac_entry['record_identifier']}"

      # already exported, but might need more resources linked to it...
      update_agent(pfx, SnacLinkHelpers.agent_snac_id(agent_json), linked_resources)

      return SnacLinkHelpers.agent_snac_id(agent_json)
    end

    snac_agent = agent_json
    snac_agent['linked_resources'] = linked_resources

    con = SnacConstellation.new
    con.export(snac_agent)

    output "#{pfx} #{I18n.t('snac_job.export.exported_to_snac')}: #{con.url}"

    # add snac constellation url and ark to agent
    agent_json = SnacLinkHelpers.agent_link(agent_json, con.url, con.ark)

    agent.save(agent_json)
    @modified << agent_json.uri if agent_json.uri

    con.id
  end


  def export_top_level_agent(pfx, uri)
    # exports an agent, optionally including any resources linked to it.

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_top_level_agent')}: #{uri}"

    # first, export linked resources (if specified, and if not already in snac)
    linked_resources = export_linked_resources(pfx, uri)

    # now export this agent
    export_agent(pfx, uri, linked_resources)
  end


  ### resource export functions ###


  def include_linked_agents?
    @json.job['include_linked_agents']
  end


  def include_linked_agent?(json)
    json['publish']
  end


  def get_linked_agents(resource_uri)
    # returns a list of agents that are linked with this resource,
    # each containing a single linked resource entry for the passed
    # resource along with any roles that agent has with it.

    linked_agents = []

    resource = SnacRecordHelper.new(resource_uri)
    resource_json = resource.load
    snac_id = SnacLinkHelpers.resource_snac_id(resource_json)

    # accumulate roles per agent
    agent_roles = {}
    resource_json['linked_agents'].each do |linked_agent|
      agent_uri = linked_agent['ref']

      agent = SnacRecordHelper.new(agent_uri)
      agent_json = agent.load

      next unless include_linked_agent?(agent_json)

      agent_roles[agent_uri] = [] unless agent_roles[agent_uri]
      agent_roles[agent_uri] << linked_agent['role']
    end

    agent_roles.each do |uri, roles|
      linked_agents << {
        'uri' => uri,
        'linked_resources' => [
          {
            'roles' => roles,
            'uri' => resource_uri,
            'snac_id' => snac_id
          }
        ]
      }
    end

    linked_agents
  end


  def export_linked_agents(pfx, resource_uri)
    # exports each linked agent, if specified

    return [] unless include_linked_agents?

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_linked_agents')}"

    linked_agents = get_linked_agents(resource_uri)

    # export each linked agent
    linked_agents.each_with_index do |linked_agent, index|
      pfx = "  + [#{I18n.t('snac_job.common.linked_agent_label', :index => index+1, :length => linked_agents.length)}]"
      id = export_agent(pfx, linked_agent['uri'], linked_agent['linked_resources'])
      linked_agent['snac_id'] = id
    end

    linked_agents
  end


  def export_resource(pfx, uri, linked_agents = [])
    # exports a resource to a snac resource, if not already exported.
    # returns the snac id for the resource in either case.

    # first, ensure this repository exists as a holding repository in snac
    repo_id = export_repository

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_resource')}: #{uri}"

    resource = SnacRecordHelper.new(uri)
    resource_json = resource.load

    # check for existing snac link
    snac_entry = SnacLinkHelpers.resource_snac_entry(resource_json)
    unless snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.export.already_exported')}: #{snac_entry['location']}"
      return SnacLinkHelpers.resource_snac_id(resource_json)
    end

    snac_resource = resource_json
    snac_resource['holding_repo_id'] = repo_id

    res = SnacResource.new
    res.export(snac_resource)

    output "#{pfx} #{I18n.t('snac_job.export.exported_to_snac')}: #{res.url}"

    # add snac resource url to AS resource
    resource_json = SnacLinkHelpers.resource_link(resource_json, res.url)

    resource.save(resource_json)
    @modified << resource_json.uri if resource_json.uri

    res.id
  end


  def export_top_level_resource(pfx, uri)
    # exports a resource, optionally including any agents linked to it.

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_top_level_resource')}: #{uri}"

    # first, export this resource
    export_resource(pfx, uri)

    # now export linked agents (if specified, and if not already in snac)
    export_linked_agents(pfx, uri)
  end


end
