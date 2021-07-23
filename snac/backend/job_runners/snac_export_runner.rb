require_relative '../lib/snac_constellation'
require_relative '../lib/snac_resource'

class SnacExportRunner < JobRunner
  include JSONModel

  register_for_job_type('snac_export_job', :run_concurrently => true)

  class SnacExportRunnerException < StandardError; end

  def run
    uris = @json.job['uris']

    terminal_error = nil
    @modified = []

    begin
      DB.open(DB.supports_mvcc?,
              :retry_on_optimistic_locking_fail => true) do

        begin
          RequestContext.open(:current_username => @job.owner.username,
                              :repo_id => @job.repo_id) do

            uris.each_with_index do |uri, index|
              output ""
              output "=====================[ #{I18n.t('snac_export_job.exporting_item', :index => index+1, :length => uris.length)} ]====================="

              parsed = JSONModel.parse_reference(uri)
              type = parsed[:type]

              case type
              when /^agent/
                pfx = "[#{I18n.t('snac_export_job.agent_label')}]"
                export_top_level_agent(pfx, uri)

              when /^resource/
                pfx = "[#{I18n.t('snac_export_job.resource_label')}]"
                export_top_level_resource(pfx, uri)

              else
                output "#{I18n.t('snac_export_job.skipping_item')}: #{type} (#{uri})"
                next
              end
            end

          end

          @modified.uniq!

          output "==================================================================="
          output "#{I18n.t('snac_export_job.success_label')}: #{I18n.t('snac_export_job.success_message', :count => @modified.length)}"

          self.success!

          @job.record_created_uris(@modified)

        rescue Exception => e
          terminal_error = e
          raise Sequel::Rollback
        end
      end

    rescue
      terminal_error ||= $!
    end

    if terminal_error
      output "==================================================================="
      output "#{I18n.t('snac_export_job.error_label')}: #{terminal_error.message}"

      terminal_error.backtrace.each do |line|
        log "TRACE: #{line}"
      end

      raise terminal_error
    end
  end


  private


  def log(msg)
    puts "[SNACEXPORT] #{msg}"
  end


  def output(msg)
    log msg
    @job.write_output(msg)
  end


  class SnacRecordHelper
    include JSONModel

    def initialize(uri)
      parsed = JSONModel.parse_reference(uri)

      @id = parsed[:id]
      @type = parsed[:type]
      @model = Kernel.const_get(@type.camelize)
    end

    def load
      JSONModel(@type.to_sym).from_hash(@model.to_jsonmodel(@id).to_hash)
    end

    def save(json)
      @model.any_repo[@id].update_from_json(json)
    end

  end


  ### repository export functions ###


  def export_repository
    # exports the current repository to a snac constellation, if not already exported.
    # returns the snac id for the constellation in either case.

    return @holding_repo_id if @holding_repo_id

    repo = Repository.to_jsonmodel(@job.repo_id)

    agent_uri = repo['agent_representation']['ref']

    agent = SnacRecordHelper.new(agent_uri)
    json = agent.load

    if agent_exported?(json)
      @holding_repo_id = agent_snac_id(json)
      return @holding_repo_id
    end

    pfx = "  + [#{I18n.t('snac_export_job.holding_repository_label')}]"
    @holding_repo_id = export_agent(pfx, agent_uri)
    # cosmetic: also add the repo to the list of modified records (to go along with agent representation)
    # ...actually it's not so cosmetic, so maybe not (it displays as '/resolve/readonly?uri=%2Frepositories%2F...')
    #@modified << repo['uri'] if repo['uri']

    @holding_repo_id
  end


  ### agent export functions ###


  def agent_snac_entry(json)
    # returns the entry containing the snac link, if any
    json['agent_record_identifiers'].find { |id| id['source'] == 'snac' }
  end


  def agent_snac_id(json)
    # returns the snac constellation id for the snac link if it exists, otherwise 0
    snac_entry = agent_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['record_identifier'].split('/').last.to_i
  end


  def agent_exported?(json)
    # returns true if this agent has a snac link
    return !agent_snac_entry(json).nil?
  end


  def get_linked_resources(agent_uri)
    # returns a list of resources that link to this agent,
    # along with any roles that agent has with it.

    resources = []

    params = {
      :q => "agent_uris:\"#{agent_uri}\" AND primary_type:\"resource\"",
      :fields => ['json'],
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
          # find roles matching this agent
          # "creator", "source", "subject"
          roles = json['linked_agents'].select { |a| a['ref'] == agent_uri }.map { |a| a['role'] }
          resources << {
            'roles' => roles,
            'uri' => json['uri']
          }
        end

        break if page == search['last_page'] || search['last_page'] == 0 || search['total_results'] == 0
      end
    rescue
      # just use what we've collected thus far?
    end

    resources
  end


  def export_linked_resources(pfx, agent_uri)
    # exports each linked resource, if specified

    return [] unless @json.job['include_linked_resources']

    output ""
    output "#{pfx} #{I18n.t('snac_export_job.processing_linked_resources')}"

    linked_resources = get_linked_resources(agent_uri)

    # export each linked resource
    linked_resources.each_with_index do |linked_resource, index|
      pfx = "  + [#{I18n.t('snac_export_job.linked_resource_label', :index => index+1, :length => linked_resources.length)}]"
      id = export_resource(pfx, linked_resource['uri'])
      linked_resource['snac_id'] = id
    end

    linked_resources
  end


  def export_agent(pfx, uri, linked_resources = [])
    # exports an agent to a snac constellation, if not already exported.
    # returns the snac id for the constellation in either case.

    output ""
    output "#{pfx} #{I18n.t('snac_export_job.processing_agent')}: #{uri}"

    agent = SnacRecordHelper.new(uri)
    json = agent.load

    # check for existing snac link
    snac_entry = agent_snac_entry(json)
    unless snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_export_job.already_exported')}: #{snac_entry['record_identifier']}"
      return agent_snac_id(json)
    end

    snac_agent = json
    snac_agent['linked_resources'] = linked_resources

    con = SnacConstellation.new
    con.export(snac_agent)

    output "#{pfx} #{I18n.t('snac_export_job.exported_to_snac')}: #{con.url}"

    # add snac constellation url and ark to agent
    has_primary_id = json['agent_record_identifiers'].map { |id| id['primary_identifier'] }.any?

    json['agent_record_identifiers'] << {
      'record_identifier' => con.url,
      'primary_identifier' => !has_primary_id,
      'source' => 'snac'
    }

    json['agent_record_identifiers'] << {
      'record_identifier' => con.ark,
      'primary_identifier' => false,
      'source' => 'nad'
    }

    agent.save(json)
    @modified << json.uri if json.uri

    con.id
  end


  def export_top_level_agent(pfx, uri)
    # exports an agent, optionally including any resources linked to it.

    output ""
    output "#{pfx} #{I18n.t('snac_export_job.processing_top_level_agent')}: #{uri}"

    # first, export linked resources (if specified, and if not already in snac)
    linked_resources = export_linked_resources(pfx, uri)

    # now export this agent
    export_agent(pfx, uri, linked_resources)
  end


  ### resource export functions ###


  def resource_snac_entry(json)
    # returns the entry containing the snac link, if any
    json['external_documents'].find { |ext| ext['title'] == 'snac' }
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


  def get_linked_agents(resource_uri)
    # returns a list of agents that are linked with this resource,
    # each containing a single linked resource entry for the passed
    # resource along with any roles that agent has with it.

    agents = []

    resource = SnacRecordHelper.new(resource_uri)
    json = resource.load
    snac_id = resource_snac_id(json)

    # accumulate roles per agent
    agent_roles = {}
    json['linked_agents'].each do |agent|
      ref = agent['ref']
      agent_roles[ref] = [] unless agent_roles[ref]
      agent_roles[ref] << agent['role']
    end

    agents = []
    agent_roles.each do |uri, roles|
      agents << {
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

    agents
  end


  def export_linked_agents(pfx, resource_uri)
    # exports each linked agent, if specified

    return [] unless @json.job['include_linked_agents']

    output ""
    output "#{pfx} #{I18n.t('snac_export_job.processing_linked_agents')}"

    linked_agents = get_linked_agents(resource_uri)

    # export each linked agent
    linked_agents.each_with_index do |linked_agent, index|
      pfx = "  + [#{I18n.t('snac_export_job.linked_agent_label', :index => index+1, :length => linked_agents.length)}]"
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
    output "#{pfx} #{I18n.t('snac_export_job.processing_resource')}: #{uri}"

    resource = SnacRecordHelper.new(uri)
    json = resource.load

    # check for existing snac link
    snac_entry = resource_snac_entry(json)
    unless snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_export_job.already_exported')}: #{snac_entry['location']}"
      return resource_snac_id(json)
    end

    snac_resource = json
    snac_resource['holding_repo_id'] = repo_id

    res = SnacResource.new
    res.export(snac_resource)

    output "#{pfx} #{I18n.t('snac_export_job.exported_to_snac')}: #{res.url}"

    # add snac resource url to AS resource
    json['external_documents'] << {
      'location' => res.url,
      'title' => 'snac'
    }

    resource.save(json)
    @modified << json.uri if json.uri

    res.id
  end


  def export_top_level_resource(pfx, uri)
    # exports a resource, optionally including any agents linked to it.

    output ""
    output "#{pfx} #{I18n.t('snac_export_job.processing_top_level_resource')}: #{uri}"

    # first, export this resource
    export_resource(pfx, uri)

    # now export linked agents (if specified, and if not already in snac)
    export_linked_agents(pfx, uri)
  end


end
