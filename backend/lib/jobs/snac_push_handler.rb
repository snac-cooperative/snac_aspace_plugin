require_relative '../types/snac_constellation'
require_relative '../types/snac_resource'
require_relative '../helpers/snac_record_helper'
require_relative '../convert/snac_export'
require_relative '../../../common/snac_preferences'
require_relative '../../../common/snac_link_helper'

class SnacPushHandler
  include JSONModel

  class SnacPushHandlerException < StandardError; end

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

    output 'not yet implemented'
    @modified << uri

=begin
    case type
    when /^agent/
      pfx = "[#{I18n.t('snac_job.common.agent_label')}]"
      push_top_level_agent(pfx, uri)

    when /^resource/
      pfx = "[#{I18n.t('snac_job.common.resource_label')}]"
      push_top_level_resource(pfx, uri)

    else
      output "#{I18n.t('snac_job.common.unhandled_type')}: #{type} (#{uri})"
    end
=end

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


end
