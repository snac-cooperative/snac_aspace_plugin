require_relative '../../common/snac_constellation'

class SnacExportRunner < JobRunner
  include JSONModel

  register_for_job_type('snac_export_job', :run_concurrently => true)

  class SNACExportRunnerException < StandardError; end

  def run
    begin
      agent_id = @json.job['agent_id']
      agent_type = @json.job['agent_type']

      output "Looking up #{agent_type} with ID #{agent_id}..."

      # get cleaned agent record
      agent_model = Kernel.const_get(agent_type.camelize)
      agent = JSONModel(agent_type.to_sym).from_hash(agent_model.to_jsonmodel(agent_id).to_hash)

      output "Checking for existing SNAC resource identifier..."

      # check for existing snac link
      ids = agent['agent_record_identifiers']
      has_primary = false

      ids.each do |id|
        raise SNACExportRunnerException.new("this agent is already linked to SNAC: #{id['record_identifier']}") if id['source'] == 'snac'
        has_primary ||= id['primary_identifier']
      end

      # otherwise, insert into snac
      output "Exporting agent to new SNAC constellation..."

      con = SNACConstellation.new
      res = con.export(agent)
      log "res = [#{res}]"
      log "url = [#{con.url}]"

      output "Linking SNAC constellation to this agent..."

      # add snac constellation url to agent
      ids << {
        'record_identifier' => con.url,
        'primary_identifier' => !has_primary,
        'source' => 'snac'
      }

      agent['agent_record_identifiers'] = ids

      modified = []

      DB.open(DB.supports_mvcc?,
              :retry_on_optimistic_locking_fail => true) do

        begin
          RequestContext.open(:current_username => @job.owner.username,
                              :repo_id => @job.repo_id) do

            agent_model.any_repo[agent_id].update_from_json(agent)
          end

          output "SUCCESS: #{con.url}"

          self.success!

          @job.record_created_uris([agent.uri])

        rescue Exception => e
          terminal_error = e
          raise Sequel::Rollback
        end

      end

    rescue
      terminal_error = $!
    end

    if terminal_error
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

end
