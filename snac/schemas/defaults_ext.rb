{
  "snac_api_key" => {
    "type" => "string",
    "required" => false
  },

  "snac_environment" => {
    "type" => "string",
    "required" => "false",
    "enum" => ["unspecified", "production", "development"],
    "default" => "production"
  },
}
