require_relative 'snac_environment'
require 'net/http'
require 'json'

module SNACAPIClient

  class SNACAPIClientException < StandardError; end


  def self.read_constellation(id)
    req = {
      'command' => 'read',
      'constellationid' => id.to_i
    }

    perform_api_request(req)
  end


  def self.create_constellation(con)
    req = {
      'command' => 'insert_and_publish_constellation',
      'apikey': AppConfig[:snac_api_key],
      'constellation' => con,
      'message' => 'import from ArchivesSpace'
    }

    perform_api_request(req)
  end


  private


  def self.perform_api_request(req)
    uri = URI(SnacEnvironment.api_url)

    query = JSON.generate(req)

    res = Net::HTTP::post(uri, query, 'Content-Type' => 'application/json')
    raise SNACAPIClientException.new("Error during SNAC API query: #{res.body}") unless res.is_a?(Net::HTTPSuccess)

    body = JSON.parse(res.body, max_nesting: false, create_additions: false)

    if body.key?('result')
      raise SNACAPIClientException.new("SNAC API: unexpected result: [#{body['result']}]") unless body['result'] == 'success'
    else
      raise SNACAPIClientException.new("SNAC API: missing result")
    end

    body
  end

end
