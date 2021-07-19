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
              output "=====================[ Exporting item #{index+1} of #{uris.length} ]====================="

              parsed = JSONModel.parse_reference(uri)
              type = parsed[:type]

              case type
              when /^agent/
                pfx = "[agent]"
                export_top_level_agent(pfx, uri)

              when /^resource/
                pfx = "[resource]"
                export_top_level_resource(pfx, json)

              else
                output "Skipping unhandled type: #{type} (URI: #{uri})"
                next
              end
            end

          end

          @modified.uniq!

          output "==================================================================="
          output "SUCCESS: Exported #{@modified.length} item#{"s" unless @modified.length == 1}"

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
      output "ERROR: #{terminal_error.message}"

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


  def export_repository
    # exports the current repository to a SNAC constellation, if not already exported.
    # returns the SNAC id for the constellation in either case.

    return @holding_repo_id if @holding_repo_id

    repo = Repository.to_jsonmodel(@job.repo_id)

    agent_uri = repo['agent_representation']['ref']

    agent = SnacRecordHelper.new(agent_uri)
    json = agent.load

    if agent_exported?(json)
      @holding_repo_id = agent_snac_id(json)
      return @holding_repo_id
    end

    pfx = "  + [holding repository]"
    @holding_repo_id = export_agent(pfx, agent_uri)
    # cosmetic: also add the repo to the list of modified records (to go along with agent representation)
    # actually it's not so cosmetic (displays as '/resolve/readonly?uri=%2Frepositories%2F3')
    #@modified << repo['uri'] if repo['uri']

    @holding_repo_id
  end


  def get_linked_resources(agent_uri)
    # FIXME: implement pagination.  for now, grab a whole bunch

    params = {
      :q => "agent_uris:\"#{agent_uri}\" AND primary_type:\"resource\"",
      :fields => ['json'],
      :page => 1,
      :page_size => 1000,
      :sort => ''
    }

    begin
      search = Search.search(params, nil)
      results = search['results']
    rescue
      results = []
    end

    resources = []
    results.each do |result|
      json = ASUtils.json_parse(result['json'])
      # find roles matching this agent
      # "creator", "source", "subject"
      roles = json['linked_agents'].select { |a| a['ref'] == agent_uri }.map { |a| a['role'] }
      resources << {
        'roles' => roles,
        'json' => json
      }
    end

    resources
  end


  def export_linked_resources(pfx, agent_uri)
    return [] unless @json.job['include_linked_records']

    linked_resources = get_linked_resources(agent_uri)

    # export each linked resource
    linked_resources.each_with_index do |linked_resource, index|
      pfx = "  + [linked resource #{index+1} of #{linked_resources.length}]"
      id = export_resource(pfx, linked_resource['json']['uri'])
      linked_resource['snac_id'] = id
    end

    linked_resources
  end


  def agent_snac_entry(json)
    json['agent_record_identifiers'].find { |id| id['source'] == 'snac' }
  end


  def agent_snac_id(json)
    snac_entry = agent_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['record_identifier'].split('/').last.to_i
  end


  def agent_exported?(json)
    return !agent_snac_entry(json).nil?
  end


  def export_agent(pfx, uri, linked_resources = [])
    # exports an agent to a SNAC constellation, if not already exported.
    # returns the SNAC id for the constellation in either case.

    output ""
    output "#{pfx} Processing agent: #{uri}"

    agent = SnacRecordHelper.new(uri)
    json = agent.load

    # check for existing snac link
    snac_entry = agent_snac_entry(json)
    unless snac_entry.nil?
      output "#{pfx} Already exported: #{snac_entry['record_identifier']}"
      return agent_snac_id(json)
    end

    snac_agent = json
    snac_agent['linked_resources'] = linked_resources

    con = SnacConstellation.new
    con.export(snac_agent)

    output "#{pfx} Exported to SNAC: #{con.url}"

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
    # exports an agent to a SNAC constellation,
    # possibly including any resources linked to it

    output "#{pfx} Processing top-level agent: #{uri}"

    # first, export linked resources (if specified, and if not already in SNAC)
    linked_resources = export_linked_resources(pfx, uri)

    # now export this agent
    export_agent(pfx, uri, linked_resources)
  end


  def resource_snac_entry(json)
    json['external_documents'].find { |ext| ext['title'] == 'snac' }
  end


  def resource_snac_id(json)
    snac_entry = resource_snac_entry(json)
    return 0 if snac_entry.nil?
    snac_entry['location'].split('/').last.to_i
  end


  def resource_exported?(json)
    return !resource_snac_entry(json).nil?
  end


  def export_resource(pfx, uri, linked_agents = [])
    # exports a resource to a SNAC resource, if not already exported.
    # returns the SNAC id for the resource in either case.

    # first, ensure this repository exists as a holding repository in SNAC
    repo_id = export_repository

    output ""
    output "#{pfx} Processing resource: #{uri}"

    resource = SnacRecordHelper.new(uri)
    json = resource.load

    # check for existing snac link
    snac_entry = resource_snac_entry(json)
    unless snac_entry.nil?
      output "#{pfx} Already exported: #{snac_entry['location']}"
      return resource_snac_id(json)
    end

    snac_resource = json
    snac_resource['holding_repo_id'] = repo_id

    res = SnacResource.new
    res.export(snac_resource)

    output "#{pfx} Exported to SNAC: #{res.url}"

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
    # exports a resource to a SNAC resource

    output "#{pfx} Processing top-level resource: #{uri}"

    # TODO: implement linked agent export

    export_resource(pfx, uri)
  end


end
