require 'mysql2'
require 'ontologies_linked_data'
require 'progressbar'
require 'zlib'

module NCBO::Resolver
  module Population
    class Classes
      LIMIT = 100_000
      KEY_STORAGE = "old:classes:keys"
      TSV_PATH = File.expand_path("../../../id_mappings_classes.tsv", __FILE__)

      COUNT_CONCEPTS_QUERY = <<-EOS
        SELECT count(*) as concepts from obs_concept
      EOS

      CONCEPT_QUERY = <<-EOS
        SELECT local_concept_id as id, full_id as uri
        FROM obs_concept
        LIMIT #{LIMIT} OFFSET %offset%
      EOS

      def initialize(options = {})
        obs_host = options[:obs_host]
        obs_username = options[:obs_username]
        obs_password = options[:obs_password]
        redis_host = options[:redis_host]
        redis_port = options[:redis_port]
        @obs_client = Mysql2::Client.new(host: obs_host, username: obs_username, password: obs_password, database: "obs_hibernate")
        @redis = Redis.new(host: redis_host, port: redis_port)
      end

      def to_csv
        # Iterate over the concept records and output to file
        offset = 0
        count = @obs_client.query(COUNT_CONCEPTS_QUERY)
        iterations = (count.first["concepts"] / LIMIT) + 1
        path = TSV_PATH
        file = File.new(path, "w+")
        iterations.times do
          puts "Starting at record #{offset}"
          concepts = @obs_client.query(CONCEPT_QUERY.sub("%offset%", offset.to_s))
          offset += LIMIT
          concepts.each do |concept|
            uri = concept["uri"]
            id = concept["id"]
            ont_id_boundry = id.index("/")
            ont_id = id[0..ont_id_boundry - 1].to_i
            short_id = id[(ont_id_boundry + 1)..-1]
            acronym = id_mapper(ont_id)
            file.write("#{acronym}\t#{short_id}\t#{uri}\n")
          end
        end
        file.close
      end
      
      def populate(options = {})
        chunk_size = options[:chunk_size] || 10_000 # in lines
        num_threads = options[:num_threads] || 4
        
        tsv_path = TSV_PATH
        unless File.file?(tsv_path)
          raise Exception, "id_mappings_classes.tsv does not exist, please run NCBO::Resolver::Population::Classes#to_csv"
        end
        
        line_count = %x{wc -l #{tsv_path}}.split.first.to_i
        puts "Starting @redis storage for #{line_count} classes"

        start = Time.now
        line_chunks = read_file(tsv_path, line_count)
        
        # Parse out data from file
        data = parse_file(num_threads, chunk_size, line_chunks)

        # Free up some memory?
        line_chunks = nil

        # Store to redis
        store_to_redis(num_threads, chunk_size, data)
        
        puts "Took #{Time.now - start}s to store #{count} class mappings"
      end
      
      def delete_keys
        # Delete old keys
        keys = @redis.smembers(KEY_STORAGE)
        puts "Deleting #{keys.length} class mapping entries"
        keys.each_slice(500_000) {|chunk| @redis.del chunk}
        @redis.del KEY_STORAGE
      end

      private
      
      def read_file(tsv_path, line_count)
        line_chunks = []
        File.foreach(tsv_path).each_slice((line_count.to_f / num_threads.to_f).ceil) do |chunk|
          line_chunks << chunk.dup
        end
        line_chunks
      end
      
      def parse_file(num_threads, chunk_size, line_chunks)
        threads = []
        data = []
        parse_data = Time.now
        line_splitter = Regexp.new(/(.*)\t(.*)\t(.*)/)
        num_threads.times do |i|
          threads << Thread.new do
            chunk = line_chunks.pop
            chunk.each_slice(chunk_size) do |lines|
              lines.each do |line|
                acronym, short_id, uri = line.scan(line_splitter).first
                hashed_uri = Zlib::crc32(uri)
                short_id_key = "old:#{acronym}:#{short_id}"

                data << [acronym, short_id, uri, hashed_uri, short_id_key]
              end
            end
          end
        end
        # Wait for completion
        threads.each {|t| t.join}
        puts "Parsing took #{Time.now - parse_data}s"
        data
      end
      
      def store_to_redis(num_threads, chunk_size, data)
        threads = []
        count = 0
        store_redis = Time.now
        num_threads.times do |i|
          threads << Thread.new do
            data.each_slice(chunk_size) do |lines|
              @redis.pipelined do
                lines.each do |line|
                  acronym, short_id, uri, hashed_uri, short_id_key = line

                  # Short id to URI mapping
                  @redis.set short_id_key, uri

                  # We could hit collisions with crc32, so we bucket the hashes
                  # then we can iterate over them when doing lookup by URI
                  @redis.lpush hashed_uri, short_id_key

                  # Store keys in a set for delete
                  @redis.sadd KEY_STORAGE, short_id_key
                  @redis.sadd KEY_STORAGE, hashed_uri

                  count += 1
                end
              end
            end
          end
        end
        # Wait for completion
        threads.each {|t| t.join}
        puts "Storing took #{Time.now - store_redis}s"
      end

      def id_mapper(ont_id)
        acronym = @redis.get "old:acronym_from_virtual:#{ont_id}"
        unless acronym
          virtual = @redis.get "old:virtual_from_version:#{ont_id}"
          acronym = @redis.get "old:acronym_from_virtual:#{virtual}"
        end
        acronym
      end

    end
  end
end
