# SNAC ArchivesSpace Plugin

This is a *beta* version of a working SNAC ArchivesSpace plugin, compatible with ArchivesSpace 3.0 (earlier versions may work but are untested).  It allows an ArchivesSpace user to search SNAC for an identity, then choose and import that identity as an Agent in ArchivesSpace.  It also allows an ArchivesSpace user to export an Agent to SNAC from within the Agent display page.

### Importing from SNAC

SNAC constellations can be imported using the import plugin (ArchivesSpace -> Plug-ins -> SNAC Import), or an Import Data Background Job (ArchivesSpace -> Create -> Background Job -> Import Data -> SNAC Constellation JSON/IDs).

The plugin search functionality in ArchivesSpace shows the SNAC biogHist entry, ARK, and preferred nameEntry heading.  When importing, it uses the current Agent model, reading and storing the preferred nameEntry heading, and creating a link to the SNAC constellation within the Agent's Record ID section.

### Exporting to SNAC

Agents display a new button in the Agent toolbar, between the `Download ...` and `Merge` buttons.  If there is an existing SNAC record identifier, this button is labeled `View in SNAC` and will take you to the SNAC page for that Agent.  Otherwise, it will be labeled `Export to SNAC`, and will create a new background job to export the Agent to SNAC, storing a link to the SNAC constellation within the Agent's Record ID section.

### Installation

Clone this repository and copy the `snac` directory into the `plugins` directory of ArchivesSpace.  Then, add `snac` to your list of plugins in the ArchivesSpace config file located at `config/config.rb`.  As an example:
```
AppConfig[:plugins] = ['local',  'lcnaf', 'snac']
```

To use a specific SNAC environment, set it as follows.  Vvalid values are `alpha`, `dev`, and `prod`.  If unset or invalid, a default environment will be used (currently `dev`).
```
AppConfig[:snac_environment] = 'dev'
```

Exporting to SNAC requires a SNAC API key.  Currently this needs to be set in the config file, and is unfortunately shared by any user who is able to see and click the `Export to SNAC` button within an Agent record.  The goal is to eventually move this to the front end, so that each user would be responsible for supplying their own API key.

You can set the global SNAC API key as follows:
```
AppConfig[:snac_api_key] = 'secret_api_key'
```
*NOTE:* this key must be valid for the SNAC environment specified above. 
