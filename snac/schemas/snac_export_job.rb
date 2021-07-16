{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",

    "properties" => {

      "uris" => {
        "type" => "array",
        "ifmissing" => "error",
        "minItems" => 1,
        "items" => {
          "type" => "string",
          "ifmissing" => "error"
        }
      },

      "include_linked_records" => {
        "type" => "boolean",
        "required" => "false",
        "default" => "false"
      },

      "include_linked_agents" => {
        "type" => "boolean",
        "required" => "false",
        "default" => "false"
      }

    }
  }
}
