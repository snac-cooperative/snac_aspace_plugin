snac_envs = [ "production", "development" ]

snac_env_prefs = {}
snac_envs.each do |env|
  snac_env_prefs["snac_#{env}_api_key"] = {
    "type" => "string",
    "required" => false
  }
end

{
  "snac_environment" => {
    "type" => "string",
    "required" => "false",
    "enum" => snac_envs,
    "default" => snac_envs.first
  },
}.merge(snac_env_prefs)
