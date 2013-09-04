require 'mysql2'
require 'ontologies_linked_data'
require 'progressbar'
require 'zlib'

module NCBO::Resolver
  module Population
    class Ontologies
      KEY_STORAGE = "old:onts:keys"

      def initialize(options = {})
        @rest_helper = options[:rest_helper]
        raise Exception, "Provide a rest helper instance using NCBO::Resolver::Population::Ontologies.new(rest_helper: obj)" unless @rest_helper.is_a?(NCBO::Resolver::RestHelper)
        redis_host = options[:redis_host] || "localhost"
        redis_port = options[:redis_port] || 6379
        @redis = Redis.new(host: redis_host, port: redis_port)
      end

      def populate(options = {})
        onts_and_views = @rest_helper.ontologies + @rest_helper.views
        puts "Creating id mappings for #{onts_and_views.length} ontologies and views"

        pbar = ProgressBar.new("Mapping", onts_and_views.length)
        redis.pipelined do
          onts_and_views.each do |o|
            acronym = @rest_helper.safe_acronym(o.abbreviation)

            # Virtual id from acronym
            redis.set "old:acronym_from_virtual:#{o.ontologyId}", acronym
            redis.sadd KEY_STORAGE, "old:acronym_from_virtual:#{o.ontologyId}"
    
            # Acronym from virtual id
            redis.set "old:virtual_from_acronym:#{acronym}", o.ontologyId
            redis.sadd KEY_STORAGE, "old:virtual_from_acronym:#{acronym}"
    
            # This call works for views and ontologies (gets all versions from related virtual id)
            versions = @rest_helper.ontology_versions(o.ontologyId)
            versions.each do |ov|
              # Version to virtual mapping
              redis.set "old:virtual_from_version:#{ov.id}", o.ontologyId
              redis.sadd KEY_STORAGE, "old:virtual_from_version:#{ov.id}"
            end
    
            pbar.inc
          end
        end
      end
      
      def delete_keys
        puts "Deleting old redis keys"
        keys = @redis.smembers(KEY_STORAGE)
        puts "Deleting #{keys.length} ontology mapping entries"
        keys.each_slice(500_000) {|chunk| @redis.del chunk}
        @redis.del KEY_STORAGE
      end

    end
  end
end
