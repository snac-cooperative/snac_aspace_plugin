class SnacRecordHelper
  include JSONModel

  def initialize(uri)
    parsed = JSONModel.parse_reference(uri)

    @id = parsed[:id]
    @type = parsed[:type]
    @model = Kernel.const_get(@type.camelize)
  end

  def load
    JSONModel(@type.to_sym).from_hash(@model.to_jsonmodel(@id).to_hash)
  end

  def save(json)
    @model.any_repo[@id].update_from_json(json)
  end

end
