snac_envs = [ "production", "development" ]
snac_job_actions = ['export', 'push', 'pull', 'link', 'unlink']

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
        "enum" => snac_job_actions
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

      "dry_run" => {
        "type" => "boolean",
        "required" => "false",
        "default" => "false"
      },

    }
  }
}
