require 'fileutils'

# TextSearchのIndex作成のBaseクラス
class TextSearchBase

  DOCKER_VIRTUOSO = "docker exec -i togogenome_updater_virtuoso"
  ISQL = "/opt/virtuoso-opensource/bin/isql 1111 dba dba"
  def initialize()
    @isql_cmd = "#{ISQL}" + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @isql_tmp_dir = "/data/text_search/current/isql_tmp"
    FileUtils.mkdir_p(@isql_tmp_dir)
  end

  # 実行するSQLの実行シェルコマンドを出力。
  # VERBOSE=OFFでクエリ結果行だけを取得するようコマンドオプションで実行する
  # #!/bin/sh
  # /opt/virtuoso-opensource/bin/isql 1111 dba dba VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout < xxxxx.sql
  def isql_write(file, sql_file_path)
    file.puts "#!/bin/sh"
    file.puts ""
    file.puts "#{@isql_cmd} < #{sql_file_path} ;"
  end

  # isql経由でクエリ発行し、その結果をテキストで返す。
  # 実行はDocker経由
  # docker exec -i togogenome_updater_virtuoso sh < /data/text_search/current/prepare/isql_command.sh > /data/text_search/current/prepare/isql_command.result
  def isql_query(sparql, output_path = nil)
    query_text = "set result_timeout = 18000000;\nSPARQL #{sparql} ;"
    File.open("#{@isql_tmp_dir}/query.sql", "w") do |file|
      file.write(query_text)
    end
    shell_file = "#{@isql_tmp_dir}/isql_command.sh"
    File.open(shell_file, "w") {|file|
      isql_write(file, "#{@isql_tmp_dir}/query.sql")
    }

    if output_path # 出力ファイルの指定有り
      system(%Q[#{DOCKER_VIRTUOSO} sh < #{shell_file} > #{output_path}])
    else # 出力ファイルの指定無し
      output_file = "#{@isql_tmp_dir}/isql_command.result"
      system(%Q[#{DOCKER_VIRTUOSO} sh < #{shell_file} > #{output_file}])
      result = File.read(output_file)
      result
    end
  end

  # isql経由でttlのロードコマンドを発行する
  # 実行はDocker経由
  # docker exec -i togogenome_updater_virtuoso sh < /data/text_search/current/prepare/isql_command.sh
  def load_ttl(path, graph)
    File.open("#{@isql_tmp_dir}/load.sql", "w") do |file|
      file.puts "log_enable(2, 1);"
      file.puts "DB.DBA.TTLP_MT(file_to_string_output('#{path}'), '', '#{graph}', 81);"
      file.puts "checkpoint;"
    end
    
    shell_file = "#{@isql_tmp_dir}/load_command.sh"
    File.open(shell_file, "w") {|file|
      isql_write(file, "#{@isql_tmp_dir}/load.sql")
    }
    system(%Q[#{DOCKER_VIRTUOSO} sh < #{shell_file}])
  end

  def to_utf(str)
    str.force_encoding('UTF-8')
  end
  
  # get columns setting of query
  def get_query_columns(stanza_name,query_name, metadata)
    query_column_info = {}
    metadata["stanzas"].map do |stanza|
      if stanza_name == stanza["stanza_name"]
        stanza["queries"].each do |query|
          if query_name == query["query_name"]
            query_column_info = query["columns"]
          end
        end
      end
    end
    query_column_info
  end
  
  # returns column names of stanza
  def get_stanza_column_names (stanza_name, metadata)
    columns = []
    metadata["stanzas"].map do |stanza|
      if stanza_name == stanza["stanza_name"]
        stanza["queries"].each do |query|
          query["columns"].each do |column|
            columns.push(column["column_name"])
          end
        end
      end
    end
    columns.uniq
  end
  
  # returns context hash for jsonld
  def get_context_hash(stanza_name, column_names)
    base_url = "http://togogenome.org/#{stanza_name}"
  
    hash = {}
    column_names.each do |column_name|
      hash[column_name] = "#{base_url}/#{column_name}"
    end
    hash
  end

  # index ファイルを出力
  def output_file(output_solr_file, output_file, stanza_name, columns, result_hash)
    solr_index_file = File.open("#{output_solr_file}", 'w')
    File.open("#{output_file}", 'w') do |file|
      file.puts '{'
      file.puts '"@context" :'
      file.puts JSON.pretty_generate(get_context_hash(stanza_name, columns))
      file.puts ','
      file.puts '"@graph" :'
      file.puts '['
      solr_index_file.puts '['
      comma = ','
      cnt = 0
      result_hash.each do |key, value|
        if cnt == result_hash.size - 1
          comma = ''
        end
  
        file.puts JSON.pretty_generate(value) + comma
        solr_index_file.puts JSON.pretty_generate(value) + comma
        cnt += 1
      end
      file.puts ']'
      solr_index_file.puts ']'
      file.puts '}'
    end
    solr_index_file.close()
  end
end