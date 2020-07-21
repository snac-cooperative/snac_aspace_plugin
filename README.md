# SNAC ArchivesSpace Plugin

```
UPDATE: This beta plugin has been updated for the new Agent model.
        It uses the built-in EAC-CPF parser to parse SNAC EAC-CPF XML.
```

This is a *beta* version of a working SNAC ArchivesSpace plugin.  It allows an ArchivesSpace user to search SNAC for an identity, then choose and import that identity as an Agent in ArchivesSpace.

Search functionality in ArchivesSpace shows the SNAC biogHist entry and preferred nameEntry heading.  When importing, it uses the current Agent model, reading and storing the SNAC ARK ID and the preferred nameEntry heading.

### Installation

Clone this repository and copy the `snac` directory into the `plugins` directory of ArchivesSpace.  Then, add `snac` to your list of plugins in the ArchivesSpace config file located at `config/config.rb`.  As an example:
```
AppConfig[:plugins] = ['local',  'lcnaf', 'snac']
```

### Additional Notes

This plugin was derived as a proof of concept from the LCNAF plugin provided with ArchivesSpace.  As such, it converts the SNAC API results into MARC XML to import into ArchivesSpace.  This plugin should therefore be used as an example and in testing, but should not be used in a production instance of ArchivesSpace at this time.
