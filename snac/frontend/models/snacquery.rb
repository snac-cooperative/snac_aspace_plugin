# Modified by SNAC
require 'net/http'
require 'nokogiri'
require 'asutils'
require 'json'

class SNACQuery
  class SNACQueryException < StandardError; end

  def self.name_search(family_name, given_name )
    query = { 'local.FamilyName' => family_name}
    query['local.FirstName'] = given_name unless ( given_name.nil? or given_name.empty? )
    new( query )
  end


  def self.lccn_search(lccns)
    new({ 'local.LCCN' => lccns.join(' ')})
  end
  #'https://snaccooperative.org/search'

  def self.query_list_marcxml(ids)
    uri = URI('https://api.snaccooperative.org/')
    default_params = {'command' => 'read'}

    tempfile = ASUtils.tempfile('snac_import')

    tempfile.write("<collection>\n")

    ids.each do |id|
        jsonbody = JSON.generate(default_params.merge('constellationid' => id))
        #req = Net::HTTP::Put.new('/alpha/rest/', initheader = { 'Content-Type' => 'text/json'})
        #req.body = jsonbody
        #response = Net::HTTP.new('snac-dev.iath.virginia.edu', 80).start {|http| http.request(req) }
        
        req = Net::HTTP::Put.new('/', initheader = { 'Content-Type' => 'text/json'})
        req.body = jsonbody
        response = Net::HTTP.new('api.snaccooperative.org', 80).start {|http| http.request(req) }
        if response.code != '200'
          raise SNACQueryException.new("Error during SNAC search: #{response.body}")
        end
        File.open("/tmp/sqr.txt", "a+") { |a| a << uri.to_s + "\n" + response.body }
        json = ASUtils.json_parse(response.body)
        tempfile.write('<record>'+"\n")
        tempfile.write('    <leader>111111z11111111111111111</leader>')
        tempfile.write('<controlfield tag="001">'+json["constellation"]["ark"]+'</controlfield>'+"\n")
        tempfile.write('    <controlfield tag="003">SNAC</controlfield>')
        tempfile.write('    <controlfield tag="008">0000000000sz1111111111111111|a aaa      </controlfield>')
        # 11 = source, 10 = rules 
        tempfile.write('  <datafield tag="010" ind1=" " ind2=" ">'+"\n")
        tempfile.write('   <subfield code="a">'+json["constellation"]["ark"]+'</subfield>'+"\n")
        tempfile.write(' </datafield>'+"\n")

        if json["constellation"]["entityType"]["term"] == "person"
            tag = '100'
            json["constellation"]["nameEntries"].each do |entry|
                # if person: ind1=1 (surname) ind1=0 (forename only)  if family: ind1=3
                # a = personal name Last, First, b numeration, q fuller form, d dates, c titles
                tempfile.write('  <datafield tag="'+tag+'" ind1="1" ind2=" ">'+"\n")
                primary = ""
                entry["components"].each do |comp|
                    code = 'a'
                    if comp["type"]["term"] == "Forename" or comp["type"]["term"] == "Name"
                        primary += comp["text"] + " "
                    elsif comp["type"]["term"] == "Surname"
                        primary += comp["text"] + ", "
                    else
                        if comp["type"]["term"] == "Numeration"
                            code = 'b'
                        end
                        if comp["type"]["term"] == "Date"
                            code = 'd'
                        end
                        if comp["type"]["term"] == "NameExpansion"
                            code = 'q'
                        end
                        tempfile.write('   <subfield code="'+code+'">'+comp["text"]+'</subfield>'+"\n")
                    end
                end
                clean = primary.strip
                tempfile.write('   <subfield code="a">'+ clean +'</subfield>'+"\n")
                tempfile.write(' </datafield>'+"\n")
                tag = '400'
            end
        elsif json["constellation"]["entityType"]["term"] == "family"
            tag = '100'
            json["constellation"]["nameEntries"].each do |entry|
                tempfile.write('  <datafield tag="'+tag+'" ind1="3" ind2=" ">'+"\n")
                tempfile.write('   <subfield code="a">'+entry["original"]+'</subfield>'+"\n")
                tempfile.write(' </datafield>'+"\n")
                tag = '400'
            end
        else
            # corporate body
            tag = '110'
            json["constellation"]["nameEntries"].each do |entry|
                tempfile.write('  <datafield tag="'+tag+'" ind1="2" ind2=" ">'+"\n")
                tempfile.write('   <subfield code="a">'+entry["original"]+'</subfield>'+"\n")
                tempfile.write(' </datafield>'+"\n")
                tag = '410'
            end
        end
        if json["constellation"].key?("biogHists")
            tempfile.write('  <datafield tag="678" ind1=" " ind2=" ">'+"\n")
            tempfile.write('   <subfield code="a">'+json["constellation"]["biogHists"][0]["text"].gsub('<biogHist>','').gsub('</biogHist>','')+'</subfield>'+"\n")
            tempfile.write(' </datafield>'+"\n")
        end
        tempfile.write('</record>'+"\n")
        # if corpbody: ind1=2 (direct order)
        # a = name,  d dates
    end
    tempfile.write("\n</collection>")

    tempfile.flush
    tempfile.rewind

    return tempfile
  end


  def initialize(query, relation = 'any')
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
