require 'open-uri'
require 'thread'

require_relative './baixa_arquivo'


# url_base = 'http://www.camara.gov.br/proposicoesWeb/prop_imp;jsessionid=.node2?tp=completa&idProposicao='
# @url_base = 'http://www.camara.gov.br/proposicoesWeb/'
@url_base = 'http://www.camara.gov.br/proposicoesWeb/prop_mostrarintegra?codteor='

# http://imagem.camara.gov.br/Imagem/d/pdf/DCD02DEZ1999.pdf#page=536
# http://www.camara.gov.br/proposicoesWeb/prop_mostrarintegra;jsessionid=.node2?codteor=99554
# http://www.camara.gov.br/proposicoesWeb/prop_mostrarintegra;jsessionid=.node2?codteor=99555 =>
#     http://imagem.camara.gov.br/dc_20.asp?selCodColecaoCsv=D&Datain=02/12/1999&txpagina=2508&altura=650&largura=800

HTML_PATH  = '/Volumes/ssd/camara/pls'

@queue = Queue.new
# 581181 - 12665

# 1100495 - 0
# 571510

1100495.downto(0) do |pl_id| 
	@queue.push pl_id
end

@mutex = Mutex.new 
@counter = 0

def counter
	@mutex.synchronize do
		@counter += 1
	end
	@counter
end


# def extract_urls(pl_id)
# 	filename = HTML_PATH + "/#{pl_id % 500}/#{pl_id}.html"
# 	if File.exists?(filename)
# 		html = open(filename).read
# 		html.scan /<a[^>]*href="([^"]*)"[^<]*inteiro\s*teor/im
# 	else
# 		puts "ERROR: PL #{pl_id} DOESN'T EXIST"
# 		[]
# 	end
# end


def pull_files(thread_id)
	while pl_id = @queue.pop

		#urls = extract_urls(pl_id).flatten

		# urls.each do |url|
			# url.gsub!(/;jsessionid=[^\?]*/, '')
			url  = @url_base + pl_id.to_s
			tried = 0
			filename = file_name(url, pl_id) + '.pdf'

			puts "COUNTER: #{counter.to_s.rjust(7, ' ')} #{thread_id.to_s.rjust(2, ' ')}  #{pl_id.to_s.rjust(6, ' ')} #{Time.now} #{filename} #{url}" if counter % 1000 == 0

			next if File.exists?(filename)

			begin
				puts "#{counter.to_s.rjust(7, ' ')} #{thread_id.to_s.rjust(2, ' ')}  #{pl_id.to_s.rjust(6, ' ')} #{Time.now} #{filename} #{url}"
				arquivo = baixa_arquivo(url, filename, 0, "#{thread_id.to_s.rjust(2, ' ')}")
				unless arquivo
					@queue.push pl_id
					next
				end

				save_file(arquivo, filename)

			rescue
				# tried += 1
				msg = "#{thread_id.to_s.rjust(2, ' ')} #{$!}"
				File.open('error.log', 'w') do |f| f.write "#{Time.now} #{msg}\n" end
				puts msg
				sleep 0.5
			    @queue.push pl_id
			end
		# end
	end
end



threads = []
1.upto(20) do |i|
	threads << Thread.new {
		pull_files(i)
	}
end
threads.map(&:join)

# pull_files(1)
