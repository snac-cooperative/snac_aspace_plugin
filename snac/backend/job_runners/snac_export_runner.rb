require_relative '../lib/snac_constellation'

class SnacExportRunner < JobRunner
  include JSONModel

  register_for_job_type('snac_export_job', :run_concurrently => true)

  class SnacExportRunnerException < StandardError; end

  def run
    uris = @json.job['uris']

    terminal_error = nil
    modified = []

    begin
      DB.open(DB.supports_mvcc?,
              :retry_on_optimistic_locking_fail => true) do

        begin
          RequestContext.open(:current_username => @job.owner.username,
                              :repo_id => @job.repo_id) do

            uris.each_with_index do |uri, index|
              output "==========[ Exporting item #{index+1} of #{uris.length} ]=========="
              output "Processing URI: #{uri}"

              parsed = JSONModel.parse_reference(uri)
              id = parsed[:id]
              type = parsed[:type]
              output "Looking up #{type} with ID #{id}..."

              # get cleaned record
              model = Kernel.const_get(type.camelize)
              json = JSONModel(type.to_sym).from_hash(model.to_jsonmodel(id).to_hash)

              # eventually this will handle other types of data
              case type
              when /^agent/
                json = export_agent(json)
              end

              next unless json

              output "Updating #{type} record..."
              model.any_repo[id].update_from_json(json)
              modified << json.uri if json.uri

              output "Done!"
            end

          end

          modified.uniq!

          output "============================================="
          output "SUCCESS: Exported #{modified.length} item#{"s" unless modified.length == 1}"

          self.success!

          @job.record_created_uris(modified)

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


  def export_agent(json)
    # exports an agent to a SNAC constellation, and returns
    # a modified Agent with a link to the entry in SNAC

    output "Preparing to export this agent to SNAC..."

    # check for existing snac link, as well as whether this
    # this agent already has a primary identifier (used later)

    ids = json['agent_record_identifiers']
    has_primary = false

    ids.each do |id|
      if id['source'] == 'snac'
        output "Skipping export because this agent is already linked to SNAC: #{id['record_identifier']}"
        return nil
      end
      has_primary ||= id['primary_identifier']
    end

    output "Exporting agent to new SNAC constellation..."

    con = SnacConstellation.new
    res = con.export(json)

    output "SNAC URL: #{con.url}"

    output "Linking SNAC constellation to this agent..."

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

    json['agent_record_identifiers'] = ids

    json
  end


end
