module NCBO::Resolver
  module Population
    class Ontologies
      KEY_STORAGE = "old:onts:keys"

      def initialize(options = {})
        require 'mysql2'
        require 'progressbar'
        require 'zlib'
        require 'ontologies_linked_data'
        @rest_helper = options[:rest_helper]
        raise Exception, "Provide a rest helper instance using NCBO::Resolver::Population::Ontologies.new(rest_helper: obj)" unless @rest_helper.is_a?(NCBO::Resolver::RestHelper)
        redis_host = options[:redis_host] || "localhost"
        redis_port = options[:redis_port] || 6379
        @key_storage = options[:key_storage] || KEY_STORAGE
        @key_prefix = options[:key_prefix] || ""
        @redis = Redis.new(host: redis_host, port: redis_port)
      end

      def populate(options = {})
        delete_keys()

        onts_and_views = @rest_helper.ontologies + @rest_helper.views
        puts "Creating id mappings for #{onts_and_views.length} ontologies and views"

        pbar = ProgressBar.new("Mapping", onts_and_views.length)
        @redis.pipelined do
          onts_and_views.each do |o|
            acronym = @rest_helper.safe_acronym(o.abbreviation)
            
            # Virtual id from acronym
            @redis.set "#{@key_prefix}old:acronym_from_virtual:#{o.ontologyId}", acronym
            @redis.sadd @key_storage, "#{@key_prefix}old:acronym_from_virtual:#{o.ontologyId}"
    
            # Acronym from virtual id
            @redis.set "#{@key_prefix}old:virtual_from_acronym:#{acronym}", o.ontologyId
            @redis.sadd @key_storage, "#{@key_prefix}old:virtual_from_acronym:#{acronym}"
    
            # This call works for views and ontologies (gets all versions from related virtual id)
            versions = @rest_helper.ontology_versions(o.ontologyId)
            versions = versions.is_a?(Array) ? versions : [versions]
            versions.each do |ov|
              # Version to virtual mapping
              @redis.set "#{@key_prefix}old:virtual_from_version:#{ov.id}", o.ontologyId
              @redis.sadd @key_storage, "#{@key_prefix}old:virtual_from_version:#{ov.id}"
            end
    
            pbar.inc
          end
        end
      end
      
      def delete_keys
        keys = @redis.smembers(@key_storage)
        puts "Deleting #{keys.length} ontology mapping entries"
        keys.each_slice(500_000) {|chunk| @redis.del chunk}
        @redis.del @key_storage
      end

    end
  end
end
