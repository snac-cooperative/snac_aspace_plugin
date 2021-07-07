require_relative '../../common/snac_api_client'
require_relative 'snac_export_helper'
require_relative 'snac_import_helper'

class SnacConstellation

  class SnacConstellationException < StandardError; end

  attr_accessor :constellation


  def initialize(from = nil)
    @prefs = SnacPreferences.new(Preference.current_preferences)
    @client = SnacApiClient.new(@prefs)

    # determine whether we were passed a SNAC constellation, or an ID to look one up
    if from.is_a?(Hash)
      con = from
    elsif from.is_a?(Integer) or from.is_a?(String)
      con = @client.read_constellation(from.to_i)
    else
      con = {}
    end

    @constellation = normalize(con)
  end


  def url
    raise SnacConstellationException.new("constellation is missing id") unless @constellation.key?('id')

    @prefs.view_url(@constellation['id'])
  end


  def import
    # returns an ArchivesSpace agent hash (used in snac_import jobs)
    SnacImportHelper.new.constellation_to_agent(@constellation)
  end


  def export(agent)
    # converts the given agent to a SNAC constellation, and uploads it to SNAC
    stub = normalize(SnacExportHelper.new.constellation_from_agent(agent))

    con = @client.create_constellation(stub)

    @constellation = normalize(con)
  end


  private


  def normalize(con)
    # data could be in multiple forms:
    # * constellation data wrapped in "constellation" key (e.g. data from SNAC API "read" command)
    # * constellation data itself (e.g. data provided by SNAC "Export JSON" link in Detailed View)
    # we make sure @constellation contains just the internal constellation data.

    if con.key?('constellation')
      con = con['constellation']
    end

    con
  end

end
