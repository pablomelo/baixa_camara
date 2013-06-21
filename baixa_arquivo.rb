# require_relative './open_uri_redirect'
require 'open-uri'
require "FileUtils"
require 'tempfile'
require 'zlib'
require 'thread'

FILES_PATH = '/Volumes/camara/v2_pls_files'

@dmutext = Mutex.new
@in_progress = {}

def baixa_arquivo(url, filename, tentativas = 0, thread = 0)

	cache_name = cache_name(url)

	if File.exists?(cache_name)
		cached_file = File.read(cache_name)
		if File.exists?(cached_file)
			puts "level: #{tentativas} CACHE HIT exists cache: #{cache_name} > #{url} > #{filename}"
			return File.open(cached_file) 
		end
	end


	is_downloading = downloading(cache_name, "(#{thread}) #{filename}")
	if is_downloading
		puts "IN ANOTHER PROCESS: cache_name: #{cache_name} in (#{thread}) #{filename} & #{is_downloading}"
		return
	end


	file_size          = 0
	last_progress      = 0
	original_file_size = 0

	arquivo = open(url,
		"User-Agent" => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:15.0) Gecko/20120427 Firefox/16.0a1", 
		"Referer" => url,
		:read_timeout => 30,
		:content_length_proc => lambda {|size| file_size = size; original_file_size = size},
		:progress_proc => lambda {|progress| last_progress, file_size = show_progress(progress, file_size.to_i, original_file_size.to_i, last_progress, url, thread)}
		)

	if file_size.to_s.to_i < 30_000 and arquivo.content_type == 'text/html'
		# puts "will read #{last_progress} #{url}"
		arquivo = arquivo.read
		arquivo =~ /<meta.*?refresh.*?URL=([^" '#>]*)/i		
		if $1 and tentativas < 10
			# puts "redir #{url} to #{$1}"
			arquivo = baixa_arquivo($1, filename, tentativas + 1, thread)
		end
	end


	if file_size.to_s.to_i > 1_000_000
		puts "SAVING CACHE: #{cache_name} > #{url} > #{filename}"
		`mkdir -p #{File.dirname(cache_name)}`
		File.open(cache_name,'w') {|f| f.write filename}
	end

	downloaded(cache_name)

	arquivo
end


def downloading(key, cache_name)
	@dmutext.synchronize do
		is_downloading = @in_progress[key]
		return is_downloading if is_downloading
		@in_progress[key] = cache_name
		return false
	end
end


def downloaded(key)
	@dmutext.synchronize do
		@in_progress.delete(key)
		return true
	end
end


# def unless_cached?(url, filename)
# 	return if File.exists?(filename)

# 	cache_name = cache_name(url)

# 	if File.exists?(cache_name)
# 		puts "CACHE HIT: #{cache_name} > #{url} > #{filename}"
# 		cache_location = File.read(cache_name)
# 		FileUtils.cp cache_location, filename
# 	else
# 		arquivo = yield
# 		save_file(arquivo, filename)

# 		`mkdir -p #{File.dirname(cache_name)}`
# 		File.open(cache_name,'w') {|f| f.write filename}
# 	end
# end


def cache_name(url)
	file_name(url, Zlib::crc32(url), FILES_PATH + '/cache', '.cache')
end


def file_name(url, pl_id, path = FILES_PATH, ext = '')
	path = "#{path}/#{pl_id % 500}/"
	# filename = path + url.match(/codteor=([^&]*)/i).to_a.last + '-' + url.match(/filename=([^&]*)/i).to_a[1].gsub(/[^\w]+/,"-") + '.pdf'
	url =~ /codteor=([^&]*)/i
	filename = ($1 || url).to_s.strip.gsub(/[^\w]+/,'-')
	path + filename + ext
end	


def show_progress(progress, file_size, original_file_size, last_progress, url, thread)
#	puts "progress: #{progress} file_size: #{file_size}"
	file_size = original_file_size > 0 ? original_file_size : progress

	return [last_progress, file_size] if  progress.to_i == 0 or (original_file_size > 0 and original_file_size < 1_000_000) or original_file_size == 0

	to_download = progress.to_f / file_size.to_f * 100.00

	if (to_download.to_i % 10 == 0) and last_progress != to_download.to_i and to_download < 100
		last_progress = to_download.to_i
		puts "#{thread.to_s.rjust(2, ' ')} #{File.basename(url)} #{to_download.to_i}% baixado progress:#{progress} file_size:#{file_size}"
	end
	[last_progress, file_size]
end	


def save_file(arquivo, filename)
	`mkdir -p #{File.dirname(filename)}`
	# ext      = arquivo.respond_to?(:content_type) ? arquivo.content_type.split('/').last : nil
	# filename = filename + '.' + ext if ext

	if arquivo.class == Tempfile
		FileUtils.move arquivo.path, filename
	elsif arquivo.class == File
		puts "CACHE HIT: linking #{arquivo.path} to #{filename}"
		File.unlink filename if File.exists?(filename)
		FileUtils.ln_s arquivo.path, filename
	elsif arquivo.respond_to?(:read)
		content = arquivo.read
		# filename = filename + '.html' if content.strip[0,100].include?('html')
		File.open(filename, 'w') do |f|
			f.write content
		end
	else
		# ext = '.pdf'
		# ext = '.html' if arquivo.strip[0,100].downcase.include?('html')
		File.open(filename, 'w') do |f|
			f.write arquivo
		end
	end
end
