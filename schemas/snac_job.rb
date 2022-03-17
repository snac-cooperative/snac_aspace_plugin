snac_envs = [ "production", "development" ]

{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "properties" => {

      "snac_environment" => {
        "type" => "string",
        "ifmissing" => "error",
        "enum" => snac_envs
      },

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
      },

    }
  }
}
