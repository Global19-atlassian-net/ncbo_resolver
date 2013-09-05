require_relative 'test_case'

class TestPopulationClasses < TestCase
  
  def self.before_suite
    rest_options = {
      api_key: "4ea81d74-8960-4525-810b-fa1baab576ff",
      rest_url: "http://rest.bioontology.org/bioportal"
    }
    rest_helper = NCBO::Resolver::RestHelper.new(rest_options)
    @@populator = NCBO::Resolver::Population::Classes.new(key_storage: "tst:cls:keys")
    @@ont_populator = NCBO::Resolver::Population::Ontologies.new(key_storage: "tst:ont:keys", rest_helper: rest_helper)
    @@ont_populator.populate
  end
  
  def self.after_suite
    @@populator.delete_keys
    @@ont_populator.delete_keys
  end
  
  def test_to_csv
    concepts = [
      {"uri" => "http://example.org/ontology/someURI1",  "id" => "1104/someURI1"},
      {"uri" => "http://example.org/ontology/someURI2",  "id" => "1104/someURI2"},
      {"uri" => "http://example.org/ontology/someURI3",  "id" => "1104/someURI3"},
      {"uri" => "http://example.org/ontology/someURI4",  "id" => "1104/someURI4"},
      {"uri" => "http://example.org/ontology/someURI5",  "id" => "1104/someURI5"},
      {"uri" => "http://example.org/ontology/someURI6",  "id" => "1104/someURI6"},
      {"uri" => "http://example.org/ontology/someURI7",  "id" => "1104/someURI7"},
      {"uri" => "http://example.org/ontology/someURI8",  "id" => "1104/someURI8"},
      {"uri" => "http://example.org/ontology/someURI9",  "id" => "1104/someURI9"},
      {"uri" => "http://example.org/ontology/someURI10", "id" => "1104/someURI10"},
      {"uri" => "http://example.org/ontology/someURI11", "id" => "1104/someURI11"},
      {"uri" => "http://example.org/ontology/someURI12", "id" => "1104/someURI12"},
      {"uri" => "http://example.org/ontology/someURI13", "id" => "1104/someURI13"},
      {"uri" => "http://example.org/ontology/someURI14", "id" => "1104/someURI14"},
      {"uri" => "http://example.org/ontology/someURI15", "id" => "1104/someURI15"}
    ]
    file = @@populator.to_csv(count = [{"concepts" => 15}], concepts = concepts)
    assert File.read(file).scan(/\n/).count == concepts.length
    file = File.new(file.path)
    file.each_with_index do |line, index|
      index = index + 1
      assert_equal "BRO\tsomeURI#{index}\thttp://example.org/ontology/someURI#{index}\n", line
    end
  end
  
  def test_redis_storage
    @@populator.populate
    NCBO::Resolver.configure
    (1..15).each do |i|
      assert_equal "http://example.org/ontology/someURI#{i}", NCBO::Resolver::Classes.uri_from_short_id("BRO", "someURI#{i}")
      assert_equal "someURI#{i}", NCBO::Resolver::Classes.short_id_from_uri("BRO", "http://example.org/ontology/someURI#{i}")
    end
  end
end