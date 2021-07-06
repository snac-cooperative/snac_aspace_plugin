# SNAC ArchivesSpace Plugin

This is a *beta* version of a working SNAC ArchivesSpace plugin, compatible with ArchivesSpace 3.0 (earlier versions may work but are untested).
It allows an ArchivesSpace user to search SNAC for an identity, then choose and import that identity as an Agent in ArchivesSpace.
It also allows an ArchivesSpace user to export an Agent to SNAC from within the Agent display page.

## Installation

Clone this repository and copy the `snac` directory into the `plugins` directory of ArchivesSpace.  Then, add `snac` to your list of plugins in the ArchivesSpace config file located at `config/config.rb`.  As an example:
```
AppConfig[:plugins] = ['local',  'lcnaf', 'snac']
```

## Configuration

SNAC settings can be specified like other ArchivesSpace preferences at the Global, Repository, and/or User levels.  Simply browse to the desired Preferences page and set your preferences in the SNAC Settings section, just below General Settings.

### SNAC Environment

This setting controls which instance of SNAC you wish to work with (default is Production):

* [Production](https://snaccooperative.org/)
* [Development](https://snac-dev.iath.virginia.edu/)

### SNAC API Key

This is only required if you want to export Agents to SNAC.  Enter your SNAC API key here, making sure it's valid for the SNAC Environment specified above.

## Importing from SNAC

SNAC identities can be imported using the SNAC Import plugin, or via an Import Data Background Job.  Each scenario is detailed below.

Importing is done using the current Agent model, reading and storing the preferred nameEntry heading, and creating a link to the SNAC identity within the Agent's Record ID section.

**NOTE:** importing from SNAC, whatever the method, requires an ArchivesSpace user to have `update_agent_record` and `import_records` permissions.

### Importing from SNAC (using the SNAC Import plugin)

Browse to the SNAC Import page (ArchivesSpace -> Plug-ins -> SNAC Import), enter a name entry, and click Search.

The results will display the preferred nameEntry heading.
Clicking `Show Record` will also display the SNAC ID, ARK, and biogHist entry for that identity.

Click `Select` next to a name entry to add it to the list of identities to import.
**NOTE:** You can perform additional name entry searches in order to add other identities before importing.

Once ready, click `Import` to initate the process of importing the selected SNAC identities into ArchivesSpace, via a background job.
If the background job is created successfully, you will be redirected to its page to see its progress.

### Importing from SNAC (via an Import Data Background Job)

Browse to the Import Data Background Job (ArchivesSpace -> Create -> Background Job -> Import Data -> SNAC JSON).

The JSON input file must contain either a single instance of or an array of objects in the following format:

```json
  {
    "type": "constellation",
    "id": "12345678",
    "json": "stringified SNAC constellation JSON"
  }
```

Notes:
* the only currently supported `type` is "constellation"
* only one of `id` or `json` is required; `id` is preferred if both are supplied

## Exporting to SNAC

Agents display a new button in the Agent toolbar, between the `Download ...` and `Merge` buttons.  If there is an existing SNAC record identifier, this button is labeled `View in SNAC` and will take you to the SNAC page for that Agent.  Otherwise, it will be labeled `Export to SNAC`, and will create a new background job to export the Agent to SNAC, storing a link to the SNAC constellation within the Agent's Record ID section.

**NOTE:** exporting to SNAC requires an ArchivesSpace user to have `update_agent_record` and `create_job` permissions.
