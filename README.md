# SNAC ArchivesSpace Plugin

```
UPDATE: This beta plugin has been updated for the new Agent model.
        It uses a custom converter to parse SNAC JSON.
```

This is a *beta* version of a working SNAC ArchivesSpace plugin.  It allows an ArchivesSpace user to search SNAC for an identity, then choose and import that identity as an Agent in ArchivesSpace.

__Importing from SNAC__

SNAC constellations can be imported using the import plugin (ArchivesSpace -> Plug-ins -> SNAC Import), or an Import Data Background Job (ArchivesSpace -> Create -> Background Job -> Import Data -> SNAC Constellation JSON/IDs).

The plugin search functionality in ArchivesSpace shows the SNAC biogHist entry and preferred nameEntry heading.  When importing, it uses the current Agent model, reading and storing the preferred nameEntry heading, and creating a link to the SNAC constellation within the Agent's Record ID section.

__Exporting to SNAC__

Agents display a new button in the agent toolbar, between the 'Download ...' and 'Merge' buttons.  If there is an existing SNAC record identifier, this button is labeled 'View in SNAC' and will take you to the SNAC page for that agent.  Otherwise, it will be labeled 'Export to SNAC', and will create a new background job to export the agent to SNAC, storing a link to the SNAC constellation within the Agent's Record ID section.


### Installation

Clone this repository and copy the `snac` directory into the `plugins` directory of ArchivesSpace.  Then, add `snac` to your list of plugins in the ArchivesSpace config file located at `config/config.rb`.  As an example:
```
AppConfig[:plugins] = ['local',  'lcnaf', 'snac']
```

To use a specific SNAC environment, set it as follows (valid values are 'alpha', 'dev', 'prod'):
```
AppConfig[:snac_environment] = 'dev'
```

Exporting to SNAC requires a SNAC API key.  Currently this needs to be set in the config file, and is shared by any user who is able to see and click the 'Export to SNAC' button.  This will eventually be moved to the front end, so that each user has to supply their own API key.

```
AppConfig[:snac_api_key] = 'secret_api_key'
```
*NOTE:* this key must be valid for the SNAC environment specified above. 
