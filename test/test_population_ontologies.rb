require_relative 'test_case'

class TestPopulationOntologies < TestCase
  
  def self.before_suite
    NCBO::Resolver.configure
    rest_options = {
      api_key: "4ea81d74-8960-4525-810b-fa1baab576ff",
      rest_url: "http://rest.bioontology.org/bioportal"
    }
    rest_helper = NCBO::Resolver::RestHelper.new(rest_options)
    @@ont_populator = NCBO::Resolver::Population::Ontologies.new(key_storage: "tst:ont:keys", rest_helper: rest_helper)
    @@ont_populator.populate
  end
  
  def self.after_suite
    @@ont_populator.delete_keys
  end
  
  def test_ontology_population
    versions = [50373, 50694, 47178]
    virtuals = [1032, 1070, 1101]
    acronyms = ["NCIT", "GO", "ICD9CM"]
    (0..2).each do |i|
      assert_equal acronyms[i], NCBO::Resolver::Ontologies.acronym_from_id(versions[i])
      assert_equal acronyms[i], NCBO::Resolver::Ontologies.acronym_from_id(virtuals[i])
      assert_equal acronyms[i], NCBO::Resolver::Ontologies.acronym_from_virtual_id(virtuals[i])
      assert_equal acronyms[i], NCBO::Resolver::Ontologies.acronym_from_version_id(versions[i])
      assert_equal virtuals[i], NCBO::Resolver::Ontologies.virtual_id_from_version_id(versions[i])
      assert_equal virtuals[i], NCBO::Resolver::Ontologies.virtual_id_from_acronym(acronyms[i])
    end
  end
end