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

    perform_api_request(req)
  end


  def create_constellation(con)
    req = {
      'command' => 'insert_and_publish_constellation',
      'apikey': @prefs.api_key,
      'constellation' => con,
      'message' => 'import from ArchivesSpace'
    }

    perform_api_request(req)
  end


  private


  def perform_api_request(req)
    uri = URI(@prefs.api_url)

    query = JSON.generate(req)

    res = Net::HTTP::post(uri, query, 'Content-Type' => 'application/json')

    begin
      json = JSON.parse(res.body, max_nesting: false, create_additions: false)
      valid = true
    rescue
      valid = false
      json = {}
    end

    # if there was an HTTP error, or if the response from HTTP success could not be
    # parsed, then build an error message from the actual or a mocked JSON response
    unless res.is_a?(Net::HTTPSuccess) and valid
      error = json['error'] || {'type' => 'Error', 'message' => 'Unable to parse SNAC API response'}
      errmsg = [error['type'], error['message']].compact.join(': ')
      raise SnacApiClientException.new("SNAC API: #{errmsg}")
    end

    # at this point there should be a result field, fail if it doesn't exist or doesn't indicate success
    if json.key?('result')
      raise SnacApiClientException.new("SNAC API: Error: response contained unexpected result: [#{json['result']}]") unless json['result'] == 'success'
    else
      raise SnacApiClientException.new("SNAC API: Error: response is missing result")
    end

    json
  end


end
