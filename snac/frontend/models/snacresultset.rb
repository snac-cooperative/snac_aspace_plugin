# Modified by SNAC
require 'asutils'
require 'json'

class SNACResultSet

  attr_reader :hit_count


  def initialize(response_body, query, page, records_per_page)
    @query = query
    
    @page = page
    @records_per_page = records_per_page
    @at_start = 1
    @at_end = 1
    @response_body = response_body
  end


  def at_start?
    @at_start
  end


  def first_record_index
    ((@page - 1) * @records_per_page) #+ 1
  end


  def last_record_index
    [first_record_index + @records_per_page - 1, @hit_count].min
  end


  def at_end?
    @at_end
  end


  def to_json
    @response_body
  end

end
