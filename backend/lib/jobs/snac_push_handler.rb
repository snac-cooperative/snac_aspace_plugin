require_relative '../types/snac_constellation'
require_relative '../types/snac_resource'
require_relative '../helpers/snac_record_helper'
require_relative '../convert/snac_export'
require_relative '../../../common/snac_preferences'
require_relative '../../../common/snac_link_helper'

require "active_support/core_ext/string"

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


  ### agent push functions ###


  def include_linked_resources?
    @json.job['include_linked_resources']
  end


  def include_linked_resource?(json)
    json['publish']
  end


  def get_linked_resource_uris(agent_uri)
    # returns a list of resource uris that link to this agent

    linked_resource_uris = []

    params = {
      :q => "agent_uris:\"#{agent_uri}\" AND primary_type:\"resource\"",
      :fields => ['*'],
      :page_size => 10,
      :sort => ''
    }

    begin
      # iterate over search result pages, collecting resource relations as we go
      page = 0
      loop do
        page = page + 1
        params[:page] = page

        search = Search.search(params, @job.repo_id)

        search['results'].each do |result|
          json = ASUtils.json_parse(result['json'])

          next unless include_linked_resource?(json)

          linked_resource_uris << json['uri']
        end

        break if page == search['last_page'] || search['last_page'] == 0 || search['total_results'] == 0
      end
    rescue
      # just use what we've collected thus far?
    end

    linked_resource_uris
  end


  def push_linked_resources(pfx, agent_uri)
    # pushes each linked resource, if specified

    return [] unless include_linked_resources?

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_linked_resources')}"

    linked_resource_uris = get_linked_resource_uris(agent_uri)

    # push each linked resource
    linked_resource_uris.each_with_index do |linked_resource_uri, index|
      pfx = "  + [#{I18n.t('snac_job.common.linked_resource_label', :index => index+1, :length => linked_resource_uris.length)}]"
      id = push_resource(pfx, linked_resource_uri)
    end
  end


  def name_entry_pieces(name_entry)
    pieces = []

    pieces << name_entry['original']

    name_entry['components'].each do |component|
      pieces << component['text']
      pieces << component['type']['term']
    end

    pieces
  end


  def name_entries_identical?(n1, n2)
    p1 = name_entry_pieces(n1)
    p2 = name_entry_pieces(n2)
    p1 == p2
  end


  def push_agent(pfx, uri)
    # pushes agent differences to a snac constellation, if any

    agent = SnacRecordHelper.new(uri)
    agent_json = agent.load

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_agent')}: #{uri} (#{abbrev(agent.title)})"

    # check for existing snac link
    snac_entry = @link_helper.agent_snac_entry(agent_json)
    if snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.push.not_linked')}"
      return
    end

    # get snac json, generate agent export json, compare

    con = SnacConstellation.new(@snac_prefs, @link_helper.agent_snac_id(agent_json))

    snac_con = con.constellation
    aspace_con = SnacExport.constellation_from_agent(agent_json)

    # compare these to see if anything we care about is different

    different = false
    update_json = snac_con

    # name entries?
	aspace_con['nameEntries'].each do |aname|
      match = false
      snac_con['nameEntries'].each do |sname|
        match = match || name_entries_identical?(aname, sname)
      end
      next if match
      output "#{pfx} #{I18n.t('snac_job.push.found_name_entry')}: #{abbrev(aname['original'])}"
      update_json['nameEntries'] << aname
      different = true
	end

    # finish up

    if different
      if dry_run?
        output "#{pfx} #{I18n.t('snac_job.push.would_have_updated_agent')}"
      else
        output "#{pfx} #{I18n.t('snac_job.push.updating_agent')}"
        con.update_and_publish(update_json)
        output "#{pfx} #{I18n.t('snac_job.push.pushed_to_snac')}: #{con.url}"
      end
    else
      output "#{pfx} #{I18n.t('snac_job.push.no_differences')}"
    end

    # include this agent uri in list of modified records.  it may or may not have been modified,
    # but either way we just want to make it easy to navigate back to from the job page
    @modified << uri
  end


  def push_top_level_agent(pfx, uri)
    # pushes agent differences, optionally including any resources linked to it.

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_top_level_agent')}: #{uri}"

    # first, push this agent
    push_agent(pfx, uri)

    # now, push linked resource differences
    push_linked_resources(pfx, uri)
  end


  ### resource push functions ###


  def include_linked_agents?
    @json.job['include_linked_agents']
  end


  def include_linked_agent?(json)
    json['publish']
  end


  def get_linked_agent_uris(resource_uri)
    # returns a list of agent uris that are linked with this resource

    linked_agent_uris = []

    resource = SnacRecordHelper.new(resource_uri)
    resource_json = resource.load
    snac_id = @link_helper.resource_snac_id(resource_json)

    # accumulate uris
    resource_json['linked_agents'].each do |linked_agent|
      agent_uri = linked_agent['ref']

      agent = SnacRecordHelper.new(agent_uri)
      agent_json = agent.load

      next unless include_linked_agent?(agent_json)

      linked_agent_uris << agent_uri
    end

    linked_agent_uris
  end


  def push_linked_agents(pfx, resource_uri)
    # pushes each linked agent, if specified

    return [] unless include_linked_agents?

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_linked_agents')}"

    linked_agent_uris = get_linked_agent_uris(resource_uri)

    # push each linked agent
    linked_agent_uris.each_with_index do |linked_agent_uri, index|
      pfx = "  + [#{I18n.t('snac_job.common.linked_agent_label', :index => index+1, :length => linked_agent_uris.length)}]"
      id = push_agent(pfx, linked_agent_uri)
    end
  end


  def should_update?(s1, s2)
    from = s1.to_s
    to = s2.to_s
    (from != '') && (from != to)
  end


  def push_resource(pfx, uri)
    # pushes resource differences to a snac resource, if any

    resource = SnacRecordHelper.new(uri)
    resource_json = resource.load

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_resource')}: #{uri} (#{abbrev(resource.title)})"

    # check for existing snac link
    snac_entry = @link_helper.resource_snac_entry(resource_json)
    if snac_entry.nil?
      output "#{pfx} #{I18n.t('snac_job.push.not_linked')}"
      return
    end

    # get snac json, generate resource export json, compare

    res = SnacResource.new(@snac_prefs, @link_helper.resource_snac_id(resource_json))

    snac_res = res.resource
    aspace_res = SnacExport.resource_from_resource(resource_json)

    # compare these to see if anything we care about is different

    different = false
    update_json = snac_res

    [ 'title', 'link', 'abstract', 'extent'].each do |field|
      if should_update?(aspace_res[field], snac_res[field])
        output "#{pfx} #{I18n.t("snac_job.push.found_#{field}")}: #{abbrev(aspace_res[field])}"
        update_json[field] = aspace_res[field]
        different = true
      end
    end

    # finish up

    if different
      if dry_run?
        output "#{pfx} #{I18n.t('snac_job.push.would_have_updated_resource')}"
      else
        output "#{pfx} #{I18n.t('snac_job.push.updating_resource')}"
        res.update(update_json)
        output "#{pfx} #{I18n.t('snac_job.push.pushed_to_snac')}: #{res.url}"
      end
    else
      output "#{pfx} #{I18n.t('snac_job.push.no_differences')}"
    end

    # include this resource uri in list of modified records.  it may or may not have been modified,
    # but either way we just want to make it easy to navigate back to from the job page
    @modified << uri
  end


  def push_top_level_resource(pfx, uri)
    # pushes resources differences, optionally including any agents linked to it.

    output ""
    output "#{pfx} #{I18n.t('snac_job.common.processing_top_level_resource')}: #{uri}"

    # first, push this resource
    push_resource(pfx, uri)

    # now push linked agent differences
    push_linked_agents(pfx, uri)
  end


end
