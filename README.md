# SNAC ArchivesSpace Plugin

This is a *beta* version of a working SNAC ArchivesSpace plugin, compatible with ArchivesSpace 3.0 (earlier versions may work but are untested).
It allows an ArchivesSpace user to search SNAC for an identity, then choose and import that identity as an Agent in ArchivesSpace.
It also allows an ArchivesSpace user to export Agents and Resources to SNAC from within their respective display pages, or create links to existing SNAC records.

## Installation

Clone this repository under the ArchivesSpace `plugins` directory.
Then, add `snac_aspace_plugin` to your list of plugins in the ArchivesSpace config file located at `config/config.rb`.
As an example:

```
AppConfig[:plugins] << 'snac_aspace_plugin'
```

## Configuration

SNAC settings can be specified like other ArchivesSpace preferences at the Global, Repository, and/or User levels.
Simply browse to the desired Preferences page and set your preferences in the SNAC Settings section, just below General Settings.

### SNAC Environment

This setting controls which instance of SNAC you wish to work with (default is Production):

* [Production](https://snaccooperative.org/)
* [Development](https://snac-dev.iath.virginia.edu/)

### SNAC API Key

This is only required if you want to export Agents or Resources to SNAC.
Enter your SNAC API key here, making sure it's valid for the SNAC Environment specified above.

**NOTE:** this setting is intended to be used at the User level only, in order to associate SNAC changes with specific users.

## Importing from SNAC

SNAC identities can be imported using the SNAC Import plugin, or via an Import Data Background Job.
Each scenario is detailed below.

Importing is done using the current Agent model, reading and storing the preferred nameEntry heading, and creating links to the SNAC identity within the Agent's Record ID section.

**NOTE:** importing from SNAC, whatever the method, requires an ArchivesSpace user to have the following permissions:
`update_agent_record`,
`import_records`

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

The JSON input data specifying the record(s) to import must contain either a single instance of or an array of objects in the following format:

```
  {
    "type": "constellation",
    "id": "12345678",
    "json": { SNAC Constellation JSON, either from API or exported from identity page }
  }
```

Notes:
* the only currently supported `type` is "constellation"
* only one of `id` or `json` is required; `id` is preferred if both are supplied
* for objects specified by `id`, the currently configured SNAC Environment in User Preferences will be used for reading constellation data
* to specify the SNAC Environment manually, wrap your data like so (this is how the SNAC Import does it):


```
  {
    "snac_environment": "development", # or "production"
    "records": ... your JSON input data above
  }
```

## Exporting to/Linking with SNAC

Agents, Resources, and Repositories expose a new `SNAC` dropdown in their respective display page toolbars, just before the `Merge` dropdown.

If there is an existing SNAC record identifier, this dropdown will contain navigation panes labeled
`View in SNAC` (which will contain a link that takes you to the SNAC page for that record), and
`Unlink with SNAC` (which will allow you to remove the link to SNAC).

Otherwise, it will contain navigation panes labeled
`Export to SNAC` (which will allow you to create a new background job to export the record to SNAC), and
`Link with SNAC` (which will allow you to create a link within this record to an existing SNAC record).

Agents are linked to SNAC via links to the SNAC identity within the Agent's Record ID section.
Resources are linked to SNAC via links to the SNAC resource within the Resource's External Documents section.

### Agent Export Options
* `Include published linked resources` --
Selecting this option will export any published Resource records that link to this agent,
and generate resource relations for them within the newly-created SNAC identity.
If any of the linked Resources have already been exported to SNAC,
the existing SNAC resource will be used (i.e. duplicate SNAC resources are not created).

### Resource Export Options
* `Include published linked agents` --
Selecting this option will export any published Agent records that are linked by this Resource,
and generate a single resource relation to this Resource within the newly-created SNAC identities.
If any of the linked Agents have already been exported to SNAC, they will be updated to
include resource relations with the newly-created SNAC resource.

### Repository Export Options
Repositories in ArchivesSpace have an Agent representation (see above for options).
Repositories can be exported manually, but will also be exported automatically whenever a Resource
is exported, so that the Resource can be associatied with a holding repository in SNAC.

**NOTE:** exporting, linking, and unlinking requires an ArchivesSpace user to have the following permissions:
`update_agent_record`,
`update_resource_record`,
`create_job`
