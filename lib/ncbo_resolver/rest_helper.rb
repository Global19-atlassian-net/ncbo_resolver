require 'cgi'
require 'uri'
require 'ostruct'
require 'json'
require 'open-uri'
require 'recursive-open-struct'
require 'progressbar'
require 'net/http'
require 'redis'

module NCBO::Resolver
  class RestHelper
    def initialize(options = {})
      redis_host = options[:redis_host] || "localhost"
      redis_port = options[:redis_port] || 6379
      @api_key = options[:api_key]
      raise Exception, "Provide api key: NCBO::Resolver::RestHelper.new(api_key: 'your_key')" unless @api_key
      @rest_url = options[:rest_url] || "http://rest.bioontology.org/bioportal"
      @redis = Redis.new(host: redis_host, port: redis_port)
      @cache = {}
    end

    def get_json(path)
      if @cache[path]
        json = @cache[path]
      else
        apikey = path.include?("?") ? "&apikey=#{@api_key}" : "?apikey=#{@api_key}"
        begin
          json = open("#{@rest_url}#{path}#{apikey}", { "Accept" => "application/json" }).read
        rescue OpenURI::HTTPError => http_error
          raise http_error
        rescue Exception => e
          binding.pry if $DEBUG
          raise e
        end
        json = JSON.parse(json, :symbolize_names => true)
        @cache[path] = json
      end
      json
    end

    def get_json_as_object(json)
      if json.kind_of?(Array)
        return json.map {|e| RecursiveOpenStruct.new(e)}
      elsif json.kind_of?(Hash)
        return RecursiveOpenStruct.new(json)
      end
      json
    end

    def user(user_id)
      json = get_json("/users/#{user_id}")
      get_json_as_object(json[:success][:data][0][:userBean])
    end

    def category(cat_id)
      self.categories.each {|cat| return cat if cat.id.to_i == cat_id.to_i}
    end

    def group(group_id)
      self.groups.each {|grp| return grp if grp.id.to_i == group_id.to_i}
    end

    def ontologies
      get_json_as_object(get_json("/ontologies")[:success][:data][0][:list][0][:ontologyBean])
    end

    def views
      get_json_as_object(get_json("/views")[:success][:data][0][:list][0][:ontologyBean])
    end

    def provisional_classes
      json = get_json("/provisional?pagesize=1000")
      results = json[:success][:data][0][:page][:contents][:classBeanResultList][:classBean]
      get_json_as_object(results)
    end

    def ontology_views(virtual_id)
      json = get_json("/views/versions/#{virtual_id}")
      list = json[:success][:data][0][:list][0]
      final_list = []

      if (!list.empty?)
        list.each do |view_version_list|
          view_version_list[1].each do |version|
            next if version == ""
            version_list = version[:ontologyBean]

            if version_list.kind_of?(Array)
              version_list.each do |v|
                final_list << v
              end
            else
              final_list << version_list
            end
          end
        end
      end

      return get_json_as_object(final_list)
    end

    def ontology(version_id)
      get_json_as_object(get_json("/ontologies/#{version_id}")[:success][:data][0][:list][0][:ontologyBean])
    end

    def ontology_versions(virtual_id)
      get_json_as_object(get_json("/ontologies/versions/#{virtual_id}")[:success][:data][0][:list][0][:ontologyBean])
    end

    def ontology_metrics(version_id)
      get_json_as_object(get_json("/ontologies/metrics/#{version_id}")[:success][:data][0][:ontologyMetricsBean])
    end

    def latest_ontology(virtual_id)
      get_json_as_object(get_json("/virtual/ontology/#{virtual_id}")[:success][:data][0][:ontologyBean])
    end

    def latest_ontology?(version_id)
      ont = ontology(version_id)
      latest = latest_ontology(ont.ontologyId)
      ont.id.to_i == latest.id.to_i
    end

    def roots(version_id)
      relations = get_json_as_object(get_json("/concepts/#{version_id}/root")[:success][:data][0][:classBean][:relations][0][:entry])
      relations.each do |rel|
        return rel.list[0][:classBean] if rel.string.eql?("SubClass")
      end
    end

    def ontology_notes(virtual_id)
      json = get_json("/virtual/notes/#{virtual_id}?threaded=true&archived=true")
      json = json[:success][:data][0][:list][0].empty? ? [] : json[:success][:data][0][:list][0][:noteBean]
      get_json_as_object(json)
    end

    def categories
      get_json_as_object(get_json("/categories")[:success][:data][0][:list][0][:categoryBean])
    end

    def groups
      get_json_as_object(get_json("/groups")[:success][:data][0][:list][0][:groupBean])
    end

    def concept(ontology_id, concept_id)
      json = get_json("/concepts/#{ontology_id}?conceptid=#{CGI.escape(concept_id)}")
      get_json_as_object(json[:success][:data][0][:classBean])
    end

    def ontology_file(ontology_id)
      file, filename = get_file("#{@rest_url}/ontologies/download/#{ontology_id}?apikey=#{@api_key}")

      matches = filename.match(/(.*?)_v.+?(?:\.([^.]*)$|$)/)
      filename = "#{matches[1]}.#{matches[2]}" unless matches.nil?

      return file, filename
    end

    def get_file(uri, limit = 10)
      raise ArgumentError, 'HTTP redirect too deep' if limit == 0

      uri = URI(uri) unless uri.kind_of?(URI)

      if uri.kind_of?(URI::FTP)
        file, filename = get_file_ftp(uri)
      else
        file = Tempfile.new('ont-rest-file')
        file_size = 0
        filename = nil
        http_session = Net::HTTP.new(uri.host, uri.port) rescue binding.pry
        http_session.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http_session.use_ssl = (uri.scheme == 'https')
        http_session.start do |http|
          http.read_timeout = 1800
          http.request_get(uri.request_uri, {"Accept-Encoding" => "gzip"}) do |res|
            if res.kind_of?(Net::HTTPRedirection)
              new_loc = res['location']
              if new_loc.match(/^(http:\/\/|https:\/\/)/)
                uri = new_loc
              else
                uri.path = new_loc
              end
              return get_file(uri, limit - 1)
            end

            raise Net::HTTPBadResponse.new("#{uri.request_uri}: #{res.code}") if res.code.to_i >= 400

            file_size = res.read_header["content-length"].to_i
            begin
              filename = res.read_header["content-disposition"].match(/filename=\"(.*)\"/)[1] if filename.nil?
            rescue Exception => e
              filename = LinkedData::Utils::Triples.last_iri_fragment(uri.request_uri) if filename.nil?
            end
            bar = ProgressBar.new(filename, file_size)
            bar.file_transfer_mode
            res.read_body do |segment|
              bar.inc(segment.size)
              file.write(segment)
            end

            if res.header['Content-Encoding'].eql?('gzip')
              uncompressed_file = Tempfile.new("uncompressed-ont-rest-file")
              file.rewind
              sio = StringIO.new(file.read)
              gz = Zlib::GzipReader.new(sio)
              uncompressed_file.write(gz.read())
              file.close
              file = uncompressed_file
            end
          end
        end
        file.close
      end

      return file, filename
    end

    def get_file_ftp(url)
      url = URI.parse(url) unless url.kind_of?(URI)
      ftp = Net::FTP.new(url.host, url.user, url.password)
      ftp.passive = true
      ftp.login
      filename = LinkedData::Utils::Triples.last_iri_fragment(url.path)
      tmp = Tempfile.new(filename)
      file_size = ftp.size(url.path)
      bar = ProgressBar.new(filename, file_size)
      bar.file_transfer_mode
      ftp.getbinaryfile(url.path) do |chunk|
        bar.inc(chunk.size)
        tmp << chunk
      end
      tmp.close
      return tmp, filename
    end

    def safe_acronym(acr)
      CGI.escape(acr.to_s.gsub(" ", "_"))
    end

    def new_iri(iri)
      return nil if iri.nil?
      RDF::IRI.new(iri)
    end

    def lookup_property_uri(ontology_id, property_id)
      property_id = property_id.to_s
      return nil if property_id.nil? || property_id.eql?("")
      return property_id if property_id.start_with?("http://") || property_id.start_with?("https://")
      begin
        concept(ontology_id, property_id).fullId
      rescue OpenURI::HTTPError => http_error
        return nil if http_error.message.eql?("404 Not Found")
      end
    end

    ##
    # Using the combination of the short_id (EX: "TM122581") and version_id (EX: "42389"),
    # this will do a Redis lookup and give you the full URI. The short_id is based on
    # what is produced by the `shorten_uri` method and should match Resource Index localConceptId output.
    # In fact, doing localConceptId.split("/") should give you the parameters for this method.
    # Population of redis data available here:
    # https://github.com/ncbo/ncbo_migration/blob/master/id_mappings_classes.rb
    def uri_from_short_id(version_id, short_id)
      acronym = self.acronym_from_version_id(version_id)
      uri = @redis.get("old_to_new:uri_from_short_id:#{acronym}:#{short_id}")

      if uri.nil? && short_id.include?(':')
        try_again_id = short_id.split(':').last
        uri = @redis.get("old_to_new:uri_from_short_id:#{acronym}:#{try_again_id}")
      end
      uri
    end

    ##
    # Given a virtual id, return the acronym (uses a Redis lookup)
    # Population of redis data available here:
    # https://github.com/ncbo/ncbo_migration/blob/master/id_mappings_ontology.rb
    # @param virtual_id [Integer] the ontology version ID
    def acronym_from_virtual_id(virtual_id)
      @redis.get("old_to_new:acronym_from_virtual:#{virtual_id}")
    end

    ##
    # Given a version id, return the acronym (uses a Redis lookup)
    # Population of redis data available here:
    # https://github.com/ncbo/ncbo_migration/blob/master/id_mappings_ontology.rb
    # @param version_id [Integer] the ontology version ID
    def acronym_from_version_id(version_id)
      virtual = @redis.get("old_to_new:virtual_from_version:#{version_id}")
      self.acronym_from_virtual_id(virtual)
    end

    def uri?(string)
      uri = URI.parse(string)
      %w( http https ).include?(uri.scheme)
    rescue URI::BadURIError
      false
    rescue URI::InvalidURIError
      false
    end
  end
end