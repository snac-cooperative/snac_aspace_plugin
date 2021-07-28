{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "properties" => {

      "action" => {
        "type" => "string",
        "ifmissing" => "error",
        "enum" => ['export', 'link', 'unlink']
      },

      "uris" => {
        "type" => "array",
        "ifmissing" => "error",
        "minItems" => 1,
        "items" => {
          "type" => "string",
          "ifmissing" => "error"
        }
      }

    }
  }
}
