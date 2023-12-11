#!/usr/bin/env ruby

require 'fileutils'
require 'systemu'
require 'json'

# UniProt の tax_id を指定した RDF ダウンロードAPI が使用できない場合に(過去にデータ不完全、スピード低下などの不具合あり)
# 全ての UniProtKB RDF ファイルをダウンロードして プロテインの entry ごとに区切り各 taxonomy ファイルに分けて出力する。
# プロテインの区切りが不明瞭で一部やや不要なトリプルが混じるので、極力使用せずAPIの復帰を待ち、長期のAPI停止の場合にだけ使用する。
class UniProtTaxonomySplitter

  @@head = <<HEAD
<?xml version='1.0' encoding='UTF-8'?>
<rdf:RDF xml:base="http://purl.uniprot.org/uniprot/" xmlns="http://purl.uniprot.org/core/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:skos="http://www.w3.org/2004/02/skos/core#" xmlns:bibo="http://purl.org/ontology/bibo/" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:void="http://rdfs.org/ns/void#" xmlns:sd="http://www.w3.org/ns/sparql-service-description#" xmlns:faldo="http://biohackathon.org/resource/faldo#">
<owl:Ontology rdf:about="http://purl.uniprot.org/uniprot/">
<owl:imports rdf:resource="http://purl.uniprot.org/core/"/>
</owl:Ontology>
HEAD

  @@tail = <<TAIL
</rdf:RDF>
TAIL

  @@rs = /<rdf:Description rdf:about="(?<!http)(?!.*#).+">/
  @@tx = '<organism rdf:resource="http://purl.uniprot.org/taxonomy/'
  @@type_protein = /<rdf:type rdf:resource=\"http:\/\/purl\.uniprot\.org\/core\/Protein\"\/>/

  @@created_dirs = {}

  def initialize(uniprot_rdf_dir, output_dir, tax_json_file)
    @input_dir = uniprot_rdf_dir
    @output_dir = output_dir
    @taxids = nil

    FileUtils.makedirs(@output_dir)
    @error_file = File.open("#{@output_dir}/error.txt", "w+")

    if File.exist?(tax_json_file)
      json = JSON.parse(File.read(tax_json_file))
      @taxids = {}
      json["list_taxid"].sort.uniq.each {|x| @taxids[x.to_i] = true}
    end

    split_entries
    add_tails
  end

  def taxid2file(taxid)
    taxdir = (taxid / 1000) * 1000
    dirpath = "#{@output_dir}/#{taxdir}"
    filepath = "#{dirpath}/#{taxid}.rdf"
    unless @@created_dirs[dirpath]
      FileUtils.makedirs(dirpath)
      @@created_dirs[dirpath] = true
    end
    unless File.exists?(filepath)
      File.open(filepath, "w+") do |file|
        file.puts @@head
      end
    end
    return filepath
  end

  def output_entry(rdf_entry, count)
    begin
      rdf_entry.slice!("\n</rdf:RDF>") # exclude footer
      taxid = rdf_entry[/#{@@tx}(\d+)/, 1].to_i
      if @taxids.nil? || @taxids[taxid] || taxid == 0 # taxidの指定をしていないか、指定していれば対象taxidであれば。taxidが取得できない0も出力
        taxid_file = taxid2file(taxid)
        #$stderr.puts "#{count}: #{taxid_file}"

        File.open(taxid_file, "a+") do |output_file|
          output_file.puts rdf_entry
        end
      end
    rescue => err
      @error_file.puts "Failed: #{Time.now} (#{err})"
      @error_file.puts block.inspect
    end
  end

  # type up:Protein から記述されているProtein IDのリストを取得
  def entry_hash(file)
    header_flag = true
    current_entry = ""
    current_block = []
    entry_id_hash = {}
    prev_block = []
    File.foreach(file).slice_before(@@type_protein).each do |block|
      unless prev_block == []
        entry_id_hash[entry_id(prev_block)] = 0
      end
      prev_block = block
    end
    entry_id_hash
  end


  # type up:Protein 記述位置から遡って、Protein IDを返す
  # <rdf:Description rdf:about="P63101"> <= ここから"P63101"を取得
  # <rdf:type rdf:resource="http://purl.uniprot.org/core/Protein"/>
  def entry_id(prev_block)
    id = nil
    prev_block.reverse_each {|line| 
      if line.start_with?('<rdf:Description rdf:about="') && (!line.include?("#")) && (!line.include?("http"))
        return line.split('"')[1]
      end
    }
    id
  end

  def split_entries
    count = 0
    Dir::glob("#{@input_dir}/*.rdf").each do |file|
      puts "#{Time.now} [Start] #{file}"
      entry_id_hash = entry_hash(file)
      header_flag = true
      first_entry = false
      current_entry = ""
      current_block = []
      File.foreach(file).slice_before(@@rs).each do |block|
        if header_flag == true #最初の<Ontology等の不要なタグは除去
          ontology_header = true
          block.each do |line|
            current_block.push(line) if ontology_header == false
            ontology_header = false if line.start_with?("</owl:Ontology>")
          end
          first_entry = true
          header_flag = false
        else # exclude header
          if current_entry != block.first # protein_idが変わった
            if first_entry == true
              current_block.concat(block)
              current_entry = block.first
              first_entry = false
              next 
            end
            prev_entry_id = current_entry.split('"')[1]
            new_entry_id = block.first.split('"')[1]
            unless entry_id_hash[new_entry_id].nil? # 対象としたProtein IDに切り替わった場合
              count += 1
              # ここで current_blockからちょっと前に遡って新しいblockに足す行と、current_blockから削除する行を計算する
              adjust_range = adjust_range(current_block, prev_entry_id, new_entry_id)

              # 新しいentry_id側のblockに足す行を取得
              add_block = []
              if adjust_range[:add_to_new_block] > 0
                add_block = current_block[(adjust_range[:add_to_new_block] * -1)..-1]
              end

              adjust_range[:delete_from_prev_block_line_no].times do |i|
                current_block.pop
              end
              output_entry(current_block.join, count)

              current_entry = block.first
              current_block = add_block
              current_block.concat(block)
              
            else # 稀に対象ではない別のProtein IDが記述されているので、その場合は気にせずにRDFに加える
              current_block.concat(block)
            end
          else # protein_idが変わっていなければentryの行に足す
            current_block.concat(block)
            current_entry = block.first
          end
        end
      end  # File.foreach(file).slice_before(rs) 
      count += 1
      output_entry(current_block.join, count)
      puts "#{Time.now} [End] #{file}"
    end  # Dir::glob.each(file)
  end  # def split_entries

  def adjust_range(line_data, prev_entry_id, new_entry_id)
    # 最後に出現する古いProtein IDの記述位置を探す
    last_prev_line_no = 0 
    line_data.each_with_index.reverse_each {|line, idx| 
      if line.start_with?("<rdf:Description") && line.include?(prev_entry_id)
        last_prev_line_no = idx
        break
      end
    }
    # そのタグが閉じた次の行からが、新しいblockに追加する行になる
    add_to_new_block_line_idx = 0
    line_data[last_prev_line_no..-1].each_with_index do |line, idx|
      if line.start_with?("</rdf:Description")
        add_to_new_block_line_idx = last_prev_line_no + idx
        break
      end
    end
    add_line_no =  line_data.size - ( add_to_new_block_line_idx + 1) # 追加の行数
   
    # 新しいProtein IDが出現した行以降は、blockから削除する
    cut_line_no = 0
    line_data.each_with_index.reverse_each {|line, idx| 
      if line.start_with?("<rdf:Description") && line.include?(new_entry_id)
        cut_line_no = line_data.size - idx
        break
      end
    }
    {add_to_new_block: add_line_no, delete_from_prev_block_line_no: cut_line_no, prev_entry_id: prev_entry_id, new_entry_id: new_entry_id}
  end

  def add_tails
    puts "Adding tails"
    @@created_dirs.sort_by{|k,v| k[/\d+/].to_i}.each do |dir, value|
      #$stderr.puts "Fixing files in #{dir} ..."
      Dir.glob("#{dir}/*").sort.each do |path|
        File.open(path, "a+") do |file|
          file.puts @@tail
        end
      end
    end
  end

end  # class UniProtTaxonomySplitter

uniprot_rdf_dir = ARGV.shift
output_dir = ARGV.shift
tax_json_file = ARGV.shift

UniProtTaxonomySplitter.new(uniprot_rdf_dir, output_dir, tax_json_file)
