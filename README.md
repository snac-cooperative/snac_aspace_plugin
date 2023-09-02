# SNAC ArchivesSpace Plugin

This is a *beta* version of a working SNAC ArchivesSpace plugin, compatible with ArchivesSpace 3.0 or later.
It allows an ArchivesSpace user to search SNAC for an identity, then choose and import that identity as an Agent in ArchivesSpace.
It also allows an ArchivesSpace user to perform various functions on Agents and Resources from within their respective display pages,
such as exporting to or linking with SNAC, pushing/pulling certain changes to/from SNAC, and synchronizing linked agent/resource relationships.

## Installation

Extract a release .zip file (or clone this repository) into the ArchivesSpace `plugins` directory.
This will create a new directory named `snac_aspace_plugin`.
Add this to your list of plugins in the ArchivesSpace config file located at `config/config.rb`, e.g.:

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

### Production/Development API Key

These are only required if you want to use functionality that modifies SNAC (`Export`, `Sync`, or `Push`).
Enter your SNAC API key(s) in the appropriate boxes here.

**NOTE:**
This setting is intended to be used at the User level only, in order to associate SNAC changes with specific users.
In other words, do not set an API key as a global option for all users to share.  Each user should manage their own keys.

## Importing from SNAC

SNAC identities can be imported using the SNAC Agent Import plugin, or via an Import Data Background Job.
Each scenario is detailed below.

Importing is done using the current Agent model, reading and storing the preferred nameEntry heading, and creating links to the SNAC identity within the Agent's Record ID section.

### Importing from SNAC (using the SNAC Agent Import plugin)

Browse to the SNAC Agent Import page (ArchivesSpace -> gear menu -> Plug-ins -> SNAC Agent Import), enter a name entry, and click Search.

The results will display the preferred nameEntry heading.
Clicking `Show Record` will also display the SNAC ID, ARK, and an embedded SNAC snippet page for that identity.

Click `Select` next to a name entry to add it to the list of identities to import.

**NOTE:**
You can perform additional name entry searches in order to add other identities before importing.

Once ready, click `Import` to initate the process of importing the selected SNAC identities into ArchivesSpace, via a background job.
If the background job is created successfully, you will be redirected to its page to see its progress.

### Importing from SNAC (via an Import Data Background Job)

This is a more advanced method of importing SNAC identities intended for those who want to perform this operation in bulk.
Browse to the Import Data Background Job (ArchivesSpace -> Create -> Background Job -> Import Data), and select "SNAC JSON" as the Import Type.

The JSON input data specifying the record(s) to import must contain either a single instance of, or an array of, objects in the following format:

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
* to specify the SNAC Environment manually, wrap your data like so (this is how the SNAC Agent Import does it):

```
  {
    "snac_environment": "development", # or "production"
    "records": ... your JSON input data above
  }
```

## Working with Records

Agents, Resources, and Repositories expose a new `SNAC` dropdown in their respective display page toolbars, just before the `Merge` dropdown.
This dropdown will expose different actions depending on whether the ArchivesSpace record is currently linked to a SNAC record.
Actions that could potentially make changes have a `Dry Run` option allowing you to see what would would happen, without actually making any changes.

### Records not yet linked to SNAC

For these records, the dropdown will contain navigation panes labeled:

* `Link` --
Create a link in ArchivesSpace between this record and an existing record in SNAC.
* `Export` --
Export this record as a new record in SNAC, and create a link between them in ArchivesSpace.
Optionally export any published linked agents/resources as well.
See the Agent/Resource/Repository "Export/Sync Options" sections below for details.

**NOTE:**
Agents are linked to SNAC via links to the SNAC identity within the Agent's Record ID section.
Resources are linked to SNAC via links to the SNAC resource within the Resource's External Documents section.

### Records already linked to SNAC

For these records, the dropdown will contain navigation panes labeled:

* `View` --
Navigate to the SNAC page for this record.
* `Sync` --
Synchronize this record's published linked agents/resources with SNAC.
This is functionally an `Export` that includes published linked agents/resources.
See the Agent/Resource/Repository "Export/Sync Options" sections below for details.
* `Push` --
Compare certain fields between this record and the corresponding SNAC record, and pushes any differences to SNAC.
Optionally push any published linked agents/resources as well.
* `Pull` (Agents only) --
Compare certain fields between this record and the corresponding SNAC record, and pulls any differences from SNAC.
* `Unlink` --
Remove any links to SNAC within this record.
Optionally unlink any published linked agents/resources as well.

#### Agent Export/Sync Options

* `Include published linked resources` --
Selecting this option will export any published Resource records that link to this agent,
and generate resource relations for them within the newly-created SNAC identity.
If any of the linked Resources have already been exported to SNAC,
the existing SNAC resource will be used (i.e. duplicate SNAC resources are not created).

#### Resource Export/Sync Options

* `Include published linked agents` --
Selecting this option will export any published Agent records that are linked by this Resource,
and generate a single resource relation to this Resource within the newly-created SNAC identities.
If any of the linked Agents have already been exported to SNAC, they will be updated to
include resource relations with the newly-created SNAC resource.

#### Repository Export/Sync Options

Repositories in ArchivesSpace have an Agent representation (see the "Agent Export/Sync Options" section above).
Repositories can be exported manually, but will also be exported automatically whenever a Resource
is exported, so that the Resource can be associatied with a holding repository in SNAC.

## ArchivesSpace Permission Requirements

Below are the permissions an ArchivesSpace user must have to perform each action listed above:

* SNAC Agent Import (regardless of method) --
`create_job`,
`update_agent_record`,
`import_records`
* Export, Link, Unlink, Sync, Pull --
`create_job`,
`update_agent_record`,
`update_resource_record`
* Push --
`create_job`
