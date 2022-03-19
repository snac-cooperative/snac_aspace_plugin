require 'json'
require_relative '../lib/types/snac_constellation'

class SnacConverter < Converter
  class SnacConverterException < StandardError; end

  include JSONModel


  def self.import_types(show_hidden = false)
    [
      {
        :name => "snac_json",
        :description => I18n.t('import_job.import_type_snac_json_desc')
      }
    ]
  end


  def self.instance_for(type, input_file)
    names = import_types(true).map do |type|
      type[:name]
    end

    if names.include?(type)
      self.new(input_file)
    else
      nil
    end
  end


  def run
    file = File.read(@input_file)
    data = ASUtils.json_parse(file)

    # data could be in multiple forms:
    #
    # * array of constellations (either SNAC JSON or IDs), via:
    #    ArchivesSpace -> Plug-ins -> SNAC Import
    #    ArchivesSpace -> Create -> Background Job -> Import Data -> SNAC Constellation JSON/IDs
    #
    # * single constellation (either SNAC JSON or ID), via:
    #    ArchivesSpace -> Create -> Background Job -> Import Data -> SNAC Constellation JSON/IDs

    # it could even be other things in the future... resources/holding reposoitories, etc.

    # use specified environment/wrapped records, if passed (typically via snac import plugin,
    # or an astute user); otherwise, use the currently configured snac environment
    if data.key?('snac_environment')
      @snac_prefs = SnacPreferences.new(Preference.current_preferences, data['snac_environment'])
      records = data['records']
    else
      @snac_prefs = SnacPreferences.new(Preference.current_preferences)
      records = data
    end

    if records.is_a?(Array)
      records.each do |record|
        create_from(record)
      end
    else
      create_from(record)
    end
  end


  private


  def create_from(data)
    # eventually this will handle other types of data

    case data['type']
    when 'constellation'
      record = create_agent(data)
    else
      return
    end

    @batch << record

    record.to_json
  end


  def create_agent(data)
    # determine whether data was passed as id or json, preferring id

    if data.key?('id')
      from = data['id']
    elsif data.key?('json')
      from = data['json']
    else
      return
    end

    agent_info = SnacConstellation.new(@snac_prefs, from).import

    agent_hash = agent_info[:hash]
    agent_type = agent_info[:type]

    agent = JSONModel(agent_type).from_hash(agent_hash)

    agent
  end


end
