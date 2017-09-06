#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'systemu'

class WGET_REFSEQ

  def initialize(refseq_json, output_dir, previous_dir=nil)
    @refseq_list = open("#{refseq_json}") do |io|
      JSON.load(io)
    end
    @output_dir = output_dir
    @previous_dir = previous_dir
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
          if @previous_dir != nil && File.exist?("#{@previous_dir}/#{tax_id}/#{prj_id}/#{seq_id}") then
            puts "link previous file #{seq_id} ..."
            system("ln #{@previous_dir}/#{tax_id}/#{prj_id}/#{seq_id} ./") unless $DEBUG
            cnt += 1
          else
            puts "try wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id} ..."
            system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}") unless $DEBUG
            if (File.exist?("#{seq_id}")) then # wget success
              error_line_num = %Q[grep "DOCTYPE html" #{seq_id} | wc -l] # if wget finished with 500, will appear line "<!DOCTYPE html PUBLIC"
              status, stdout, stderr = systemu error_line_num
              if stdout.to_i > 0 # wget error in the middle
                puts "failed (in the middle) wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
                # file remove and clear cache, then this file will be retried.
                FileUtils.rm("#{@output_dir}/#{tax_id}/#{prj_id}/#{seq_id}")
                system("curl \"http://togows.dbcls.jp/entry/nucleotide/#{seq_id}?clear\"")
              else
                puts "succeed wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
                cnt += 1
              end
            else # maybe wget timeout
              puts "failed wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
            end
          end
        end
      }
    end
    cnt
  end
end

unless ARGV.size == 2
 puts "./wget_refseq.rb <refseq_list_json> <output_dir>"
 exit(1)
end

wget_refseq = WGET_REFSEQ.new(ARGV[0], ARGV[1])
wget_refseq.wget_all()
