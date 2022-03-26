require_relative '../../../common/snac_api_client'
require_relative '../convert/snac_export'
require_relative '../convert/snac_import'

class SnacResource

  class SnacResourceException < StandardError; end

  attr_accessor :resource


  def initialize(prefs, from = nil)
    @prefs = prefs
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

    @resource['id'].to_i
  end


  def version
    raise SnacResourceException.new("resource is missing version") unless @resource.key?('version')

    @resource['version'].to_i
  end


  def url
    @prefs.resource_url(id)
  end


  def export(resource)
    # converts the given ArchivesSpace resource to a SNAC resource, and uploads it to SNAC
    stub = normalize(SnacExport.resource_from_resource(resource))

    res = @client.create_resource(stub)

    @resource = normalize(res)
  end


  def update(data)
    res = normalize(@client.update_resource(id, version, data))

    @resource['version'] = res['version']
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
