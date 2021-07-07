# Modified by SNAC
require 'asutils'
require 'json'

class SnacResultSet

  def initialize(response_body, query, page, records_per_page)
    # when there are no results, SNAC sets pagination = 0, so we have caller always
    # supply records_per_page.  caller also supplies page number since it knows it.

    @query = query

    json = ASUtils.json_parse(response_body)

    # used but not totally trustable -- see comments in other methods
    @total_results = json['total'].to_i

    @records_per_page = records_per_page.to_i
    @page = page.to_i
    @start_index = (@page - 1) * @records_per_page + 1

    @records = json['results']
  end


  def first_record_index
    if total_records < 1
      # purely cosmetic for the case when there are no results, as this value is used
      # to populate "Showing results ${first_record_index} to ... of ... matches".
      0
    else
      @start_index
    end
  end


  def last_record_index
    # sometimes SNAC reports more records than actually are returned.
    # use length of records array instead of relying on @records_per_page

    [@start_index + @records.length - 1, @total_results].min
  end


  def total_records
    # sometimes SNAC reports more records than actually are returned.
    # attempt to detect this when on the last page of results, and
    # adjust the total accordingly.

    return @total_results unless at_end?

    last_record_index
  end


  def at_start?
    @start_index < 2
  end


  def at_end?
    @records.length < @records_per_page or last_record_index == @total_results
  end


  def to_json
    ASUtils.to_json(:records => @records,
                    :first_record_index => first_record_index,
                    :last_record_index => last_record_index,
                    :at_start => at_start?,
                    :at_end => at_end?,
                    :page => @page,
                    :query => @query,
                    :hit_count => total_records,
                    :records_per_page => @records_per_page
                    )
  end

end
