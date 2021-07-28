require_relative '../types/snac_constellation'
require_relative '../types/snac_resource'
require_relative '../helpers/snac_record_helper'
require_relative '../helpers/snac_link_helpers'

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

    case type
    when /^agent/
      pfx = "[#{I18n.t('snac_job.common.agent_label')}]"
      unlink_agent(pfx, uri)

    when /^resource/
      pfx = "[#{I18n.t('snac_job.common.resource_label')}]"
      unlink_resource(pfx, uri)

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


  def unlink_agent(pfx, uri)
    # removes any snac links from the given agent

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_agent')}: #{uri}"

    agent = SnacRecordHelper.new(uri)
    json = agent.load

    # check for existing snac link
    snac_entry = SnacLinkHelpers.agent_snac_entry(json)
    if snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.unlink.already_unlinked')}"
      return
    end

    json = SnacLinkHelpers.agent_unlink(json)

    agent.save(json)
    @modified << json.uri if json.uri

    output "#{pfx} #{I18n.t('snac_job.unlink.unlinked_with_snac')}"
  end


  def unlink_resource(pfx, uri)
    # removes any snac links from the given resource

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_resource')}: #{uri}"

    resource = SnacRecordHelper.new(uri)
    json = resource.load

    # check for existing snac link
    snac_entry = SnacLinkHelpers.resource_snac_entry(json)
    if snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.unlink.already_unlinked')}"
      return
    end

    json = SnacLinkHelpers.resource_unlink(json)

    resource.save(json)
    @modified << json.uri if json.uri

    output "#{pfx} #{I18n.t('snac_job.unlink.unlinked_with_snac')}"
  end


end
