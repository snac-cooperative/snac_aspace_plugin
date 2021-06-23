require 'json'
require_relative '../../common/snac_constellation'

class SnacConverter < Converter
  class SNACConverterException < StandardError; end

  include JSONModel


  def self.import_types(show_hidden = false)
    [
     {
       :name => "snac_constellation_json",
       :description => I18n.t('import_job.import_type_snac_constellation_json_desc')
     },
     {
       :name => "snac_constellation_ids",
       :description => I18n.t('import_job.import_type_snac_constellation_ids_desc')
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

    if data.is_a?(Array)
      data.each do |datum|
        create_agent(datum)
      end
    else
      create_agent(data)
    end
  end


  private


  def create_agent(data)
    agent_info = SNACConstellation.new(data).import

    agent_hash = agent_info[:hash]
    agent_type = agent_info[:type]

    agent = JSONModel(agent_type).from_hash(agent_hash)

    @batch << agent

    agent.to_json
  end


end
