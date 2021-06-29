{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",

    "properties" => {

      "agent_id" => {
        "type" => "integer",
        "ifmissing" => "error"
      },
      "agent_type" => {
        "type" => "string",
        "ifmissing" => "error"
      }

    }
  }
}
