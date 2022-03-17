{
  :schema => {
    "$schema" => "http://www.archivesspace.org/archivesspace.json",
    "version" => 1,
    "type" => "object",
    "parent" => "snac_job",
    "properties" => {

      "snac_source" => {
        "type" => "string",
        "ifmissing" => "error"
      },

    }
  }
}
