#!/usr/bin/env ruby
#encoding: UTF-8

require 'digest'
require 'progressbar'
require 'colored'

module DanLZW
  class Codec
    @@IDX_BITS = 16
    @@CLEAR = 256
    def self.compress (stream)
      result = []
      dict, hash = build_dict

      pbar = ProgressBar.new("Compress", stream.size)
      w = nil
      idx = 0
      stream.each_byte do |byte|
        k = byte.chr
        wk = "#{w}#{k}"
        if hash[wk].nil? == false
          w = wk
        else
          hash[wk] = dict.length # speed-up trick
          dict << wk
          result << hash[w]
          w = k

          if dict.length >= (1 << @@IDX_BITS)
            result << k.ord
            dict, hash = build_dict
            result << @@CLEAR
            w = nil
            puts "ring ring at #{idx.to_s.cyan}"
          end
        end
        pbar.inc
        idx += 1
      end
      result << w.ord if w
      pbar.finish

      pack(result)
    end

    def self.decompress (stream)
      result = ''
      dict, hash = build_dict
      array = unpack(stream)

      pbar = ProgressBar.new("Decompress", stream.size)
      result << array[0].chr
      w = array[0].chr
      array[1..-1].each do |byte|
        next if byte == 0
        if w.nil?
          result << byte.chr
          w = byte.chr
          next
        end
        if byte == @@CLEAR
          dict, hash = build_dict
          w = nil
          next
        end
        entry = dict[byte]
        entry ||= w + w[0] # Welch correction
        dict << "#{w}#{entry[0]}"
        result << entry
        w = entry

        pbar.inc
      end
      pbar.finish

      result
    end

    private
    def self.build_dict
      dict = (0..255).to_a.map { |c| c.chr }
      dict[@@CLEAR] = -1
      hash = {}
      dict.each_index { |idx| hash[dict[idx]] = idx }
      return dict, hash
    end

    def self.pack (array)
      fmt = "%0#{@@IDX_BITS}b"
      t = array.map { |n| fmt % n }.join('')
      result = t.scan(/\d{8}/).map { |n| n.to_i(2).chr }.join('')
      result += t[(t.length/8)*8..-1].to_i(2).chr if t.length % 8
      result
    end

    def self.unpack (stream)
      regex = /\d{#{@@IDX_BITS}}/
      t = stream.each_byte.to_a.select.map { |n| '%08b' % n}.join('')
      result = t.scan(regex).map { |n| n.to_i(2) }
      result << t[(t.length/@@IDX_BITS)*@@IDX_BITS..-1].to_i(2) if t.length % @@IDX_BITS
      result
    end
  end
end


if __FILE__ == $0
  def hbar (width=80)
    "#{'=' * width}".blue
  end
  
  fin  = File.open(ARGV[0] || "input.txt", "rb")
  fout = File.open("archive.bin", "wb")
  fstream = fin.read
  
  puts "#{hbar(33)} #{'DanLZW Codec'.cyan} #{hbar(33)}"
  puts "sizeof(fstream): #{fstream.size} bytes"
  
  puts "#{hbar}"
  compressed = DanLZW::Codec.compress(fstream)
  fout.write(compressed); fout.close
  decompressed = DanLZW::Codec.decompress(File.open("archive.bin", "rb").read)
  
  File.open("output.txt", "wb").write(decompressed)

  puts "#{hbar}"
  puts "compressed:   #{'%7d' % compressed.length} bytes"
  puts "decompressed: #{'%7d' % decompressed.length} bytes"
  
  md5_fstream = Digest::MD5.hexdigest(fstream)
  md5_compressed = Digest::MD5.hexdigest(compressed)
  md5_decompressed = Digest::MD5.hexdigest(decompressed)

  puts "#{hbar}"
  puts "md5(fstream):      #{md5_fstream.yellow}"
  if md5_fstream == md5_decompressed
    puts "md5(decompressed): #{md5_decompressed.green} #{'✔'.green}"
  else
    puts "md5(decompressed): #{md5_decompressed.red}"
  end

  (0...fstream.length).each do |index|
    puts "index: #{index}, fstream: #{fstream[index]}, decompressed: #{decompressed[index]}" unless fstream[index] == decompressed[index]
  end
end
