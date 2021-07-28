require_relative '../types/snac_constellation'
require_relative '../types/snac_resource'
require_relative '../helpers/snac_record_helper'
require_relative '../helpers/snac_link_helpers'

class SnacLinkHandler
  include JSONModel

  class SnacLinkHandlerException < StandardError; end

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
      link_agent(pfx, uri)

    when /^resource/
      pfx = "[#{I18n.t('snac_job.common.resource_label')}]"
      link_resource(pfx, uri)

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


  def link_agent(pfx, uri)
    # adds snac links to the given agent

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_agent')}: #{uri}"

    agent = SnacRecordHelper.new(uri)
    json = agent.load

    # check for existing snac link
    snac_entry = SnacLinkHelpers.agent_snac_entry(json)
    unless snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.link.already_linked')}: #{snac_entry['record_identifier']}"
      return
    end

    # load constellation to ensure it's valid and get its canonical url
    snac_id = @json.job['snac_source']
    output "#{pfx} #{I18n.t('snac_job.link.looking_up_snac_id')}: #{snac_id}"
    con = SnacConstellation.new(snac_id)

    json = SnacLinkHelpers.agent_link(json, con.url, con.ark)

    agent.save(json)
    @modified << json.uri if json.uri

    output "#{pfx} #{I18n.t('snac_job.link.linked_with_snac')}: #{con.url}"
  end


  def link_resource(pfx, uri)
    # adds snac links to the given resource

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_resource')}: #{uri}"

    resource = SnacRecordHelper.new(uri)
    json = resource.load

    # check for existing snac link
    snac_entry = SnacLinkHelpers.resource_snac_entry(json)
    unless snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.link.already_linked')}: #{snac_entry['location']}"
      return
    end

    # load resource to ensure it's valid and get its canonical url
    snac_id = @json.job['snac_source']
    output "#{pfx} #{I18n.t('snac_job.link.looking_up_snac_id')}: #{snac_id}"
    res = SnacResource.new(snac_id)

    json = SnacLinkHelpers.resource_link(json, res.url)

    resource.save(json)
    @modified << json.uri if json.uri

    output "#{pfx} #{I18n.t('snac_job.link.linked_with_snac')}: #{res.url}"
  end


end
