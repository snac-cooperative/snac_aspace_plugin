require 'net/http'
require 'json'

class SnacApiClient

  class SnacApiClientException < StandardError; end


  def initialize(prefs)
    @prefs = prefs
  end


  def read_constellation(id)
    req = {
      'command' => 'read',
      'constellationid' => id.to_i
    }

    perform_api_request(req, 'constellation')
  end


  def create_constellation(con)
    req = {
      'command' => 'insert_and_publish_constellation',
      'apikey': @prefs.api_key,
      'constellation' => con,
      'message' => 'imported from ArchivesSpace'
    }

    perform_api_request(req)
  end


  def edit_constellation(id)
    req = {
      'command' => 'edit',
      'apikey': @prefs.api_key,
      'constellationid' => id.to_i
    }

    perform_api_request(req, 'constellation')
  end


  def update_constellation(id, version, data)
    con = {
      'dataType' => 'Constellation',
      'id' => id.to_i,
      'version' => version.to_i
    }.merge(data)

    req = {
      'command' => 'update_constellation',
      'apikey': @prefs.api_key,
      'constellation' => con,
      'message' => 'updated by ArchivesSpace'
    }

    perform_api_request(req, 'constellation')
  end


  def publish_constellation(id, version)
    req = {
      'command' => 'publish_constellation',
      'apikey': @prefs.api_key,
      'constellation' => {
        'dataType' => 'Constellation',
        'id' => id.to_i,
        'version' => version.to_i
      },
      'message' => 'published by ArchivesSpace'
    }

    perform_api_request(req, 'constellation')
  end


  def unlock_constellation(id, version)
    req = {
      'command' => 'unlock_constellation',
      'apikey': @prefs.api_key,
      'constellation' => {
        'dataType' => 'Constellation',
        'id' => id.to_i,
        'version' => version.to_i
      },
    }

    perform_api_request(req, 'constellation')
  end


  def search_constellations(term)
    req = {
      'command' => 'search',
      'term' => term,
      'start' => 0,
      'count' => 50,
      'entity_type' => ''
    }

    perform_api_request(req, 'results')
  end


  def read_resource(id)
    req = {
      'command' => 'read_resource',
      'resourceid' => id.to_i
    }

    perform_api_request(req, 'resource')
  end


  def create_resource(res)
    req = {
      'command' => 'insert_resource',
      'apikey': @prefs.api_key,
      'resource' => res,
      'message' => 'imported from ArchivesSpace'
    }

    perform_api_request(req)
  end


  def update_resource(id, version, data)
    res = {
      'dataType' => 'Resource',
      'id' => id.to_i,
      'version' => version.to_i
    }.merge(data)

    req = {
      'command' => 'insert_resource',
      'apikey': @prefs.api_key,
      'resource' => res,
      'message' => 'updated by ArchivesSpace'
    }

    perform_api_request(req, 'resource')
  end


  def search_resources(term)
    req = {
      'command' => 'resource_search',
      'term' => term,
      'start' => 0,
      'count' => 50
    }

    perform_api_request(req, 'results')
  end


  private


  def perform_api_request(req, success_key = nil)
    uri = URI(@prefs.api_url)

    query = JSON.generate(req)

    res = Net::HTTP::post(uri, query, 'Content-Type' => 'application/json')

    if @prefs.debug?
      puts '###'
      puts '### SNAC request:'
      puts '###'
      puts "### #{query}"
      puts '###'
      puts '### SNAC response:'
      puts '###'
      puts "### #{res.body}"
      puts '###'
    end

    begin
      json = JSON.parse(res.body, max_nesting: false, create_additions: false)
      raise SnacApiClientException.new("expected JSON response") unless json.is_a?(Hash)
      valid = true
    rescue
      valid = false
      json = {
        'error' => {
          'type' => 'Parse Error',
          'message' => $!
        }
      }
    end

    # if there was an HTTP error, or if the response from HTTP success could not be
    # parsed, then build an error message from the actual or a mocked JSON response
    unless res.is_a?(Net::HTTPSuccess) and valid
      error = json['error'] || {'type' => 'General Error', 'message' => 'Unable to determine error from SNAC API response'}
      errmsg = [error['type'], error['message']].compact.join(': ')
      raise SnacApiClientException.new("SNAC API: #{errmsg}")
    end

    # at this point there should be a result field, fail if it doesn't exist or doesn't indicate success
    if json.key?('result')
      raise SnacApiClientException.new("SNAC API: Error: response contained unexpected result: [#{json['result']}]") unless json['result'] == 'success'
    else
      # welp, turns out a resource read doesn't contain a result... so let's check for an expected key in the response instead
      raise SnacApiClientException.new("SNAC API: Error: response is missing result") unless json.key?(success_key)
    end

    json
  end


end
