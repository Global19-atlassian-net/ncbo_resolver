require_relative 'test_case'

class TestPopulationRestHelper < TestCase
  
  def self.before_suite
    NCBO::Resolver.configure
    rest_options = {
      api_key: "4ea81d74-8960-4525-810b-fa1baab576ff",
      rest_url: "http://rest.bioontology.org/bioportal"
    }
    @@rest_helper = NCBO::Resolver::RestHelper.new(rest_options)
  end
  
  def test_ontologies
    ontologies = @@rest_helper.ontologies
    acronyms = ontologies.map {|o| o.abbreviation}
    assert acronyms.include?("NCIT")
    assert acronyms.include?("GO")
    assert acronyms.include?("BRO")
    assert acronyms.include?("ICD9CM")
    assert acronyms.include?("SNOMEDCT")
    
    ncit = ontologies.select {|o| o.abbreviation.eql?("NCIT")}.first
    versions = @@rest_helper.ontology_versions(ncit.ontologyId)
    assert versions.length >= 19
    ncit_version_ids = Set.new([40377, 39478, 13578, 40644, 42331, 42838, 42693, 45400, 46317, 47513, 47638, 50148, 50262, 50147, 50028, 50373, 50105, 50536, 50586])
    assert_equal ncit_version_ids, Set.new(versions.map {|v| v.id})
  end
end