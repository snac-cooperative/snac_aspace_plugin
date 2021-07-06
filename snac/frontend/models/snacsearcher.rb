# Modified by SNAC
require 'net/http'

require_relative 'snacresultset'

class SnacSearcher

  class SnacSearchException < StandardError; end


  def initialize(search_url)
    @search_url = search_url
  end


  def default_params
    {
      'format' => 'json',
      'entity_type' => ''
    }
  end


  def calculate_start_record(page, records_per_page)
    ((page - 1) * records_per_page) + 1
  end


  def search(query, page, records_per_page)
    uri = URI(@search_url)
    start_record = calculate_start_record(page, records_per_page)
    params = default_params.merge('term' => query.to_s,
                                  'count' => records_per_page,
                                  'start' => start_record)
    uri.query = URI.encode_www_form(params)

    res = Net::HTTP::get_response(uri)
    raise SnacSearchException.new("Error during SNAC search: #{res.body}") unless res.is_a?(Net::HTTPSuccess)

    SnacResultSet.new(res.body, query, page, records_per_page)
  end


end
