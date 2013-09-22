require "ncbo_resolver/version"
require "ncbo_resolver/rest_helper"
require "ncbo_resolver/population/classes"
require "ncbo_resolver/population/ontologies"

require 'zlib'

module NCBO::Resolver
  def self.configure(options = {})
    redis_host = options[:redis_host] || "localhost"
    redis_port = options[:redis_port] || 6379
    @@redis = Redis.new(host: redis_host, port: redis_port)
    puts "(RS) >> Using Resolver Redis instance at "+
      "#{redis_host}:#{redis_port}"
    true
  end
  
  def self.redis
    @@redis
  end

  class Classes
    def self.uri_from_short_id(acronym, short_id)
      NCBO::Resolver.redis.get "old:#{acronym}:#{short_id}"
    end
    
    def self.short_id_from_uri(acronym, uri)
      candidates = NCBO::Resolver.redis.lrange Zlib::crc32(uri), 0, -1
      short_id = nil
      candidates.each do |key|
        found_uri = NCBO::Resolver.redis.get(key)
        short_id = key.split("old:#{acronym}:").last if found_uri.eql?(uri)
      end
      short_id
    end
  end
  
  class Ontologies
    def self.acronym_from_id(id)
      acronym = self.acronym_from_virtual_id(id)
      acronym = self.acronym_from_version_id(id) unless acronym
      acronym
    end

    def self.acronym_from_virtual_id(virtual_id)
      NCBO::Resolver.redis.get "old:acronym_from_virtual:#{virtual_id}"
    end
    
    def self.acronym_from_version_id(version_id)
      virtual = virtual_id_from_version_id(version_id)
      acronym_from_virtual_id(virtual)
    end

    def self.virtual_id_from_version_id(version_id)
      id = NCBO::Resolver.redis.get "old:virtual_from_version:#{version_id}"
      id.nil? ? nil : id.to_i
    end
    
    def self.virtual_id_from_acronym(acronym)
      id = NCBO::Resolver.redis.get "old:virtual_from_acronym:#{acronym}"
      id.nil? ? nil : id.to_i
    end
  end
end
