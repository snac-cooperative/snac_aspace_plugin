# Modified by SNAC
require 'net/http'
require 'asutils'
require 'json'

class SNACQuery
  class SNACQueryException < StandardError; end


  def self.name_search(api_url, family_name, given_name)
    query = { 'local.FamilyName' => family_name}
    query['local.FirstName'] = given_name unless ( given_name.nil? or given_name.empty? )
    new(api_url, query)
  end


  def self.lccn_search(api_url, lccns)
    new(api_url, { 'local.LCCN' => lccns.join(' ')})
  end


  def initialize(api_url, query = {}, relation = 'any')
    @api_url = api_url
    @query = query
    @fields = query.keys 
    @relation = relation
    @boolean = 'and'
  end


  def clean(query)
    query = query.join(' ') if query.is_a?( Array ) 
    query.gsub('"', '')
  end


  def to_s
    @fields.map { |field| "#{field} #{@relation} \"#{clean(@query[field])}\"" unless @query[field].empty? }.
           compact.join(" #{@boolean} ")
  end

end
