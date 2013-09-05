# NCBO::Resolver

This is a small library that can facilitate the transition between legacy NCBO systems and newer versions. It primarily looks up ids from NCBO v3 web services and databases and stores it into redis for easy, fast translation. The library also provides convenience methods for common id transformation tasks.

## Installation

Add this line to your application's Gemfile:

    gem 'ncbo_resolver'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ncbo_resolver

## Usage

### Population

You can populate lookup information for both classes and ontologies.

#### Classes

Classes id lookup provides methods for translating class or term 'short ids' (commonly used in the legacy system) into their corresponding URIs. The reverse lookup is also possible.

```ruby
require 'ncbo_resolver'
options = {
  obs_host: "your_host",
  obs_username: "your_username",
  obs_password: "your_password",
  redis_host: "your_redis_host",
  redis_port: "your_redis_port"
}
cls_populator = NCBO::Resolver::Population::Classes.new(options)
cls_populator.to_csv # This generates a CSV file with class short id to URI mappings
cls_populator.populate # This will store information from the CSV file into redis

NCBO::Resolver.configure(options)
uri = NCBO::Resolver::Classes.uri_from_short_id("BRO", "BRO:Resource")
short_id = NCBO::Resolver::Classes.short_id_from_uri("BRO", "http://bioontology.org/ontologies/BiomedicalResourceOntology.owl#Resource")
```

#### Ontologies

Ontology id lookup allows you to transform 'virtual' and 'version' ids from NCBO's legacy system into acronyms, which are used in the new system.

```ruby
rest_options = {
  api_key: "your_apikey",
  rest_url: "http://rest.bioontology.org/bioportal"
}
rest_helper = NCBO::Resolver::RestHelper.new(rest_options)
ont_populator = NCBO::Resolver::Population::Ontologies.new(rest_helper: rest_helper)
ont_populator.populate

NCBO::Resolver::Ontologies.acronym_from_id(1104) # virtual id
NCBO::Resolver::Ontologies.acronym_from_id(50373) # version id
NCBO::Resolver::Ontologies.acronym_from_virtual_id(1070)
NCBO::Resolver::Ontologies.acronym_from_version_id(50694)
NCBO::Resolver::Ontologies.virtual_id_from_version_id(47178)
NCBO::Resolver::Ontologies.virtual_id_from_acronym("ICD9CM")
```

#### REST Helper

The REST Helper provides methods for easily accessing data on the legacy NCBO ontologies REST service.

```ruby
rest_options = {
  api_key: "your_apikey",
  rest_url: "http://rest.bioontology.org/bioportal"
}
rest_helper = NCBO::Resolver::RestHelper.new(rest_options)
ontologies = rest_helper.ontologies
views = rest_helper.views
```


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
