require_relative '../types/snac_constellation'
require_relative '../types/snac_resource'
require_relative '../helpers/snac_record_helper'
require_relative '../convert/snac_export'
require_relative '../../../common/snac_preferences'
require_relative '../../../common/snac_link_helper'

class SnacPullHandler
  include JSONModel

  class SnacPullHandlerException < StandardError; end

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

    case type
    when /^agent/
      pfx = "[#{I18n.t('snac_job.common.agent_label')}]"
      pull_agent(pfx, uri)

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


  def agent_names_identical?(n1, n2)
    # gloss over person/family/corporate body distinction
    # and just do a straight compare of any possible fields

    fields = [
      'name_order',
      'primary_name',
      'rest_of_name',
      'qualifier',
      'number',
      'fuller_form',
      'dates',
      'family_name',
      'family_type',
      'location',
      'jurisdiction',
      'conference_meeting',
      'subordinate_name_1',
      'subordinate_name_2',
    ]

    fields.each do |field|
      return false if n1[field] != n2[field]
    end

    true
  end


  def pull_agent(pfx, uri, linked_resources = [])
    # grabs constellation from snac, and updates any agent info that has changed

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_agent')}: #{uri}"

    # read aspace agent json
    agent = SnacRecordHelper.new(uri)
    agent_json = agent.load

    # read snac agent json, as it would be if imported
    agent_snac = SnacConstellation.new(@snac_prefs, @link_helper.agent_snac_id(agent_json)).import

    # compare these to see if anything we care about has changed

    updated = false

    # name entries?
	agent_snac[:hash]['names'].each do |sname|
      match = false
      agent_json['names'].each do |aname|
        match = match || agent_names_identical?(sname, aname)
      end
      next if match
      output "#{pfx} #{I18n.t('snac_job.pull.found_new_name_entry')}"
      agent_json['names'] << sname
      updated = true
	end

    # finish up

    if updated
      output "#{pfx} #{I18n.t('snac_job.pull.updating_agent')}"
      agent.save(agent_json)
    else
      output "#{pfx} #{I18n.t('snac_job.pull.agent_unchanged')}"
    end

    @modified << uri
  end


end
