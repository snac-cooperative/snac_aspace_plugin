class SnacRecordHelper
  include JSONModel

  def initialize(uri)
    parsed = JSONModel.parse_reference(uri)

    @id = parsed[:id]
    @type = parsed[:type]
    @model = Kernel.const_get(@type.camelize)

    @json = {}
    @jsonmodel = {}
  end

  def load
    @json = @model.to_jsonmodel(@id).to_hash
    @jsonmodel = JSONModel(@type.to_sym).from_hash(@json)

    @jsonmodel
  end

  def save(json)
    @model.any_repo[@id].update_from_json(json)
  end

  def title
    @json['title']
  end

end
