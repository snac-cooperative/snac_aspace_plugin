require_relative '../types/snac_constellation'
require_relative '../types/snac_resource'
require_relative '../helpers/snac_record_helper'
require_relative '../convert/snac_export'
require_relative '../../../common/snac_preferences'
require_relative '../../../common/snac_link_helper'

require "active_support/core_ext/string"

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


  def dry_run?
    @json.job['dry_run']
  end


  def abbrev(str, len = 100)
    str.truncate(len, separator: /\s/)
  end


  ### agent pull functions ###


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

    # read aspace agent json
    agent = SnacRecordHelper.new(uri)
    agent_json = agent.load

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_agent')}: #{uri} (#{abbrev(agent.title)})"

    # read snac agent json, as it would be if imported
    agent_snac = SnacConstellation.new(@snac_prefs, @link_helper.agent_snac_id(agent_json)).import

    # compare these to see if anything we care about is different

    different = false

    # name entries?
	agent_snac[:hash]['names'].each do |sname|
      match = false
      agent_json['names'].each do |aname|
        match = match || agent_names_identical?(sname, aname)
      end
      next if match

      sort_name = ''
      case agent_json['jsonmodel_type']
      when 'agent_person'
        sort_name = SortNameProcessor::Person.process(sname)
      when 'agent_family'
        sort_name = SortNameProcessor::Family.process(sname)
      when 'agent_corporate_entity'
        sort_name = SortNameProcessor::CorporateEntity.process(sname)
      end

      output "#{pfx} #{I18n.t('snac_job.pull.found_name_entry')}: #{abbrev(sort_name)}"

      sname.delete('authorized')
      agent_json['names'] << sname
      different = true
	end

    # finish up

    if different
      if dry_run?
        output "#{pfx} #{I18n.t('snac_job.pull.would_have_updated_agent')}"
      else
        output "#{pfx} #{I18n.t('snac_job.pull.updating_agent')}"
        agent.save(agent_json)
        output "#{pfx} #{I18n.t('snac_job.pull.pulled_from_snac')}"
      end
    else
      output "#{pfx} #{I18n.t('snac_job.pull.no_differences')}"
    end

    # include this agent uri in list of modified records.  it may or may not have been modified,
    # but either way we just want to make it easy to navigate back to from the job page
    @modified << uri
  end


end
