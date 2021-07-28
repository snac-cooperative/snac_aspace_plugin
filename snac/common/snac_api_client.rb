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
      'message' => 'import from ArchivesSpace'
    }

    perform_api_request(req)
  end


  private


  def perform_api_request(req, success_key = nil)
    uri = URI(@prefs.api_url)

    query = JSON.generate(req)

    res = Net::HTTP::post(uri, query, 'Content-Type' => 'application/json')

puts ''
puts 'SNAC request:'
puts ''
puts "#{query}"
puts ''
puts 'SNAC response:'
puts ''
puts "#{res.body}"
puts ''

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
