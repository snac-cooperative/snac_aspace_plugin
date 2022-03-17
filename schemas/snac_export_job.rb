{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "parent" => "snac_job",
    "properties" => {

      "include_linked_resources" => {
        "type" => "boolean",
        "required" => "false",
        "default" => "false"
      },

      "include_linked_agents" => {
        "type" => "boolean",
        "required" => "false",
        "default" => "false"
      },

    }
  }
}
