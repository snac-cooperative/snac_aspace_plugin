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
              output "================[ Exporting item #{index+1} of #{uris.length} ]================"

              parsed = JSONModel.parse_reference(uri)
              id = parsed[:id]
              type = parsed[:type]

              output "Processing URI: #{uri}"

              # get cleaned record
              model = Kernel.const_get(type.camelize)
              json = JSONModel(type.to_sym).from_hash(model.to_jsonmodel(id).to_hash)

              case type

              when /^agent/
                pfx = "[agent]"
                # 1. export linked resources (if specified, and if not already in SNAC)
                linked_resources = export_linked_resources(json['uri'])

                # 2. export agent with resource relations that reference resources above
                #    (reload agent since lock_version may have changed due to linked resource updates)
                json = JSONModel(type.to_sym).from_hash(model.to_jsonmodel(id).to_hash)
                json = export_agent(pfx, json, linked_resources)

              when /^resource/
                pfx = "[resource]"
                json = export_resource(pfx, json)

              else
                output "Skipping unhandled record type: #{type}"
                next
              end

              next unless json

              output "#{pfx} Updating ArchivesSpace #{type} record"

              model.any_repo[id].update_from_json(json)
              @modified << json.uri if json.uri

              output "#{pfx} Done"
            end

          end

          @modified.uniq!

          output "========================================================="
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
      output "============================================="
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


  def export_linked_resources(agent_uri)
    # FIXME: implement flag
    #return [] unless @json.job['include_linked_resources']

    linked_resources = get_linked_resources(agent_uri)

    # export each linked resource
    linked_resources.each_with_index do |linked_resource, index|
      pfx = "  + [linked resource]"
      output "#{pfx} ========[ Exporting resource #{index+1} of #{linked_resources.length} ]========"

      uri = linked_resource['json']['uri']

      output "#{pfx} Processing URI: #{uri}"

      parsed = JSONModel.parse_reference(uri)
      id = parsed[:id]
      type = parsed[:type]

      model = Kernel.const_get(type.camelize)
      json = JSONModel(type.to_sym).from_hash(model.to_jsonmodel(id).to_hash)
      linked_resource['json'] = json

      json = export_resource(pfx, json)

      next unless json

      linked_resource['json'] = json

      output "#{pfx} Updating ArchivesSpace #{type} record"

      model.any_repo[id].update_from_json(json)
      @modified << json.uri if json.uri

      output "#{pfx} Done"
    end

    linked_resources
  end


  def export_agent(pfx, agent, linked_resources)
    # exports an agent to a SNAC constellation, and returns
    # a modified Agent with a link to the entry in SNAC

    output "#{pfx} Preparing to export this agent to SNAC"

    # check for existing snac link, as well as whether this
    # this agent already has a primary identifier (used later)

    ids = agent['agent_record_identifiers']
    has_primary = false

    ids.each do |id|
      if id['source'] == 'snac'
        output "#{pfx} Skipping export because this agent is already linked to SNAC: #{id['record_identifier']}"
        return nil
      end
      has_primary ||= id['primary_identifier']
    end

    output "#{pfx} Exporting agent to new SNAC constellation"

    snac_agent = agent
    snac_agent['linked_resources'] = linked_resources

    con = SnacConstellation.new
    con.export(snac_agent)

    output "#{pfx} SNAC URL: #{con.url}"

    output "#{pfx} Linking SNAC constellation to this agent"

    # add snac constellation url and ark to agent
    ids << {
      'record_identifier' => con.url,
      'primary_identifier' => !has_primary,
      'source' => 'snac'
    }

    ids << {
      'record_identifier' => con.ark,
      'primary_identifier' => false,
      'source' => 'nad'
    }

    agent['agent_record_identifiers'] = ids

    agent
  end


  def export_resource(pfx, resource)
    # exports a resource to a SNAC resource, and returns
    # a modified Resource with a link to the entry in SNAC

    output "#{pfx} Preparing to export this resource to SNAC"

    # check for existing snac link

    external = resource['external_documents']

    external.each do |ext|
      if ext['title'] == 'snac'
        output "#{pfx} Skipping export because this resource is already linked to SNAC: #{ext['location']}"
        return nil
      end
    end

    output "#{pfx} Exporting resource to new SNAC resource"

    res = SnacResource.new
    res.export(resource)

    output "#{pfx} SNAC URL: #{res.url}"

    output "#{pfx} Linking SNAC resource to this resource"

    # add snac resource url to AS resource
    external << {
      'location' => res.url,
      'title' => 'snac'
    }

    resource['external_documents'] = external

    resource
  end


end
