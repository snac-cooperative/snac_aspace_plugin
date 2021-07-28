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

    if data.is_a?(Array)
      data.each do |datum|
        create_from(datum)
      end
    else
      create_from(data)
    end
  end


  private


  def create_from(data)
    # eventually this will handle other types of data

    case data['type']
    when 'constellation'
      item = create_agent(data)
    else
      return
    end

    @batch << item

    item.to_json
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

    agent_info = SnacConstellation.new(from).import

    agent_hash = agent_info[:hash]
    agent_type = agent_info[:type]

    agent = JSONModel(agent_type).from_hash(agent_hash)

    agent
  end


end
