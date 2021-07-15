require_relative '../../common/snac_api_client'
require_relative 'snac_export_helper'
require_relative 'snac_import_helper'

class SnacResource

  class SnacResourceException < StandardError; end

  attr_accessor :resource


  def initialize(from = nil)
    @prefs = SnacPreferences.new(Preference.current_preferences)
    @client = SnacApiClient.new(@prefs)

    # determine whether we were passed a SNAC resource, or an ID to look one up
    if from.is_a?(Hash)
      res = from
    elsif from.is_a?(Integer) or from.is_a?(String)
      res = @client.read_resource(from.to_i)
    else
      res = {}
    end

    @resource = normalize(res)
  end


  def id
    raise SnacResourceException.new("resource is missing id") unless @resource.key?('id')

    @resource['id']
  end


  def url
    @prefs.resource_url(id)
  end


  def export(resource)
    # converts the given ArchivesSpace resource to a SNAC resource, and uploads it to SNAC
    stub = normalize(SnacExportHelper.new.resource_from_resource(resource))

    res = @client.create_resource(stub)

    @resource = normalize(res)
  end


  private


  def normalize(res)
    # we make sure @resource contains just the internal resource data.

    if res.key?('resource')
      res = res['resource']
    end

    res
  end


end
