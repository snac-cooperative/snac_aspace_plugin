# Modified by SNAC
require 'net/http'
require 'nokogiri'

require_relative 'snacquery'
require_relative 'snacresultset'

class SNACSearcher

  class SNACSearchException < StandardError; end


  def initialize(base_url)
    @base_url = base_url
  end


  def default_params
    {
      'format' => 'json',
      'entity_type' => ''
    }
  end


  def calculate_start_record(page, records_per_page)
    ((page - 1) * records_per_page) #+ 1
  end


  def search(sru_query, page, records_per_page)
    uri = URI(@base_url)
    start_record = calculate_start_record(page, records_per_page)
    params = default_params.merge('term' => sru_query.to_s,
                                  'count' => records_per_page,
                                  'start' => start_record)
    uri.query = URI.encode_www_form(params)

    HTTPRequest.new.get(uri) do |response|
      if response.code != '200'
        raise SNACSearchException.new("Error during SNAC search: #{response.body}")
      end
      File.open("/tmp/sru.txt", "a+") { |a| a << uri.to_s + "\n" + response.body }
      SNACResultSet.new(response.body, sru_query, page, records_per_page)
    end
  end


  def results_to_marcxml_file(query)
    page = 1
    tempfile = ASUtils.tempfile('snac_import')

    tempfile.write("<collection>\n")

    while true
      results = search(query, page, 10)

      results.each do |xml|
        tempfile.write(xml)
      end

      break if results.at_end?

      page += 1
    end

    tempfile.write("\n</collection>")

    tempfile.flush
    tempfile.rewind

    return tempfile
  end

end
