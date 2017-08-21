#!/usr/bin/env ruby

require 'json'
require 'fileutils'

class WGET_REFSEQ

  def initialize(refseq_json, output_dir)
    @refseq_list = open("#{refseq_json}") do |io|
      JSON.load(io)
    end
    @output_dir = output_dir
  end

  def wget_all
    #continue until the data can't be get(nothing to wget or failed all of tried).
    success_cnt = 0
    begin
      success_cnt = wget_togows()
      puts "success_cnt: #{success_cnt}"
    end while success_cnt > 0
  end

  def wget_togows()
    cnt = 0 # number of success
    @refseq_list.each do |entry|
      tax_id = entry['tax_id']
      prj_id = entry['bioproject_id']
      FileUtils.mkdir_p("#{@output_dir}/#{tax_id}/#{prj_id}")
  
      Dir.chdir("#{@output_dir}/#{tax_id}/#{prj_id}") {
        seq_id = entry['refseq_id']
        if !(File.exist?("#{seq_id}")) then #ignore already exist
          puts "try wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id} ..."
          system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}") unless $DEBUG
          if (File.exist?("#{seq_id}")) then # wget success
            puts "succeed wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
            cnt += 1
          else
            puts "failed wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
          end
        end
      }
    end
    cnt
  end
end

if ARGV.size < 1 
 puts "./wget_refseq.v2.rb <refseq_list_json> [retry]"
 exit(1)
end

output_dir = "refseq/current/refseq.gb"
wget_refseq = WGET_REFSEQ.new(ARGV[0], output_dir)#, ARGV[1])
wget_refseq.wget_all()

