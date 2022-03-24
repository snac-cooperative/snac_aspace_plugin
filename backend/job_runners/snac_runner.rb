require_relative '../lib/jobs/snac_export_handler'
require_relative '../lib/jobs/snac_sync_handler'
require_relative '../lib/jobs/snac_push_handler'
require_relative '../lib/jobs/snac_pull_handler'
require_relative '../lib/jobs/snac_link_handler'
require_relative '../lib/jobs/snac_unlink_handler'

class SnacRunner < JobRunner
  include JSONModel

  register_for_job_type('snac_export_job', :run_concurrently => true)
  register_for_job_type('snac_sync_job', :run_concurrently => true)
  register_for_job_type('snac_push_job', :run_concurrently => true)
  register_for_job_type('snac_pull_job', :run_concurrently => true)
  register_for_job_type('snac_link_job', :run_concurrently => true)
  register_for_job_type('snac_unlink_job', :run_concurrently => true)

  class SnacRunnerException < StandardError; end

  def run
    uris = @json.job['uris']
    action = @json.job['action']

    terminal_error = nil
    modified = []

    begin
      handler_type = Kernel.const_get("snac_#{@json.job['action']}_handler".camelize)
      raise "#{I18n.t('snac_job.common.unhandled_action')}: #{@json.job['action']}" unless handler_type

      handler = handler_type.new(@job, @json)

      DB.open(DB.supports_mvcc?,
              :retry_on_optimistic_locking_fail => true) do

        begin
          RequestContext.open(:current_username => @job.owner.username,
                              :repo_id => @job.repo_id) do

            uris.each_with_index do |uri, index|
              output ""
              output "=====================[ #{I18n.t('snac_job.common.processing_record', :index => index+1, :length => uris.length)} ]====================="

              modified.concat(handler.process_uri(uri))
            end

          end

          modified.uniq!

          success_message = if modified.length == 1
                              I18n.t('snac_job.common.success_message_singular')
                            else
                              I18n.t('snac_job.common.success_message_plural', :count => modified.length)
                            end

          output ""
          output "======================================================================"
          output "#{I18n.t('snac_job.common.success_label')}: #{success_message}"

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
      output "==================================================================="
      output "#{I18n.t('snac_job.common.error_label')}: #{terminal_error.message}"

      terminal_error.backtrace.each do |line|
        log "TRACE: #{line}"
      end

      raise terminal_error
    end
  end


  private


  def log(msg)
    puts "[SNACJOB] #{msg}"
  end


  def output(msg)
    log msg
    @job.write_output(msg)
  end


end
