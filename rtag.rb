#!/usr/bin/env ruby

require 'httpclient'
require 'id3lib'

module RTag

  ##################################################################
  ##  Directory Tagger
  ##################################################################
  class Mp3Dir
    def initialize directorio
      @Files = []
      @MP3Files = []
      dir = Dir.new directorio
      for archivo in dir.each.sort
        if /[a-z0-9]*?\s*[\.\-]?\s*(.+?).mp3$/i.match archivo
          @Files.push $1
          @MP3Files.push archivo
        end
      end
    end

    #--------------------------------------------------------------
    def matches? disco
      tracks   = disco.getTracks

      unless tracks.count >= @Files.count # El disco puede ser taggeado completamente
        puts "*Error* Algunos files no pueden ser taggeados Tracks: " + @Files.count.to_s + " | AMZ: " + tracks.count.to_s

        ##  Show track vs amazon names to check where is the difference
        if tracks.count == @Files.count
          for i in (0..tracks.count)
            puts "#{i} Mp3: #{@tracks[i].getName}"
          end
        end

        return false
      end

      substringCortosCounter = 1
      for i in (0..@Files.count-1)
        mp3   = @Files[i].to_s.downcase
        track = tracks[i].getName.downcase

        mp3.gsub! /\s*album\s*version\s*/i, ''
        mp3.gsub! /\s*lp\s*version\s*/i, ''
        mp3.gsub! /\s+\(.+?\)/, ''
        mp3.gsub! /\s+\[.+?\]/, ''
        mp3.gsub! /[^a-z]/, ''
        mp3.gsub! /the/,''

        trackName = track.gsub /\s+\(.+?\)/, ''
        trackName.gsub! /\s*lp\s*version\s*/i, ''
        trackName.gsub! /\s*album version\s*/i, ''
        trackName.gsub! /\s+\[.+?\]/, ''
        trackName.gsub! /[^a-z]/, ''
        trackName.gsub! /the/,''

        unless mp3 == trackName
          puts "*Warning* MP3=>'" + mp3 + "' != AMZ=>'" + trackName + "'"
          mp3_withoutVocals = mp3.gsub /[aeiou]/, ''
          trackName_withoutVocals = trackName.gsub /[aeiou]/, ''

          if mp3_withoutVocals == trackName_withoutVocals
            puts "Warning resuelto eliminando vocales"
            return true
          end

          # Substring Largo
          if mp3[0..6] == trackName[0..6]
            puts "*Warning* Resuelto usando substrings!"
            return true
          end

          # Subtring Corto
          if mp3[0..2] == trackName[0..2]

            if substringCortosCounter == 3
              puts "**ERROR** Demasiados substrings cortos fueron necesarios"
              return false
            end

            puts "*Warning* Resuelto usando substrings cortos (Hago la vista gorda #{substringCortosCounter} vez/veces) :-) "
            substringCortosCounter += 1
            return true
          end
          return false
        end
      end
      return true
    end

    ##  Return the files found in the mp3 directory
    ## ---------------------------------------------------------------------
    def getMP3
      return @MP3Files || []
    end

  end

  ##################################################################
  ##  String Sanitizer
  ##################################################################  
  class Sanitize
    def self.this string
      string.gsub! /&amp;/, '&'               # Just &
      string.gsub! /&quot;/, '"'              # Just "
			string.gsub! /&ouml;/, 'o'							# Thanks Bjork for your beautiful " sign above the o
      string.gsub! /^\s*/, ''                 # Heading spaces
      string.gsub! /\s*$/, ''                 # Trailing spaces
      string.gsub! /&#39;/, "'"               # The '
      string.encode! "ISO-8859-1"             # Encode filenames in utf8 for standard reasons
    end

    def self.this! string
      string = Sanitize.this string
    end

    def self.titleize string
      return string.gsub(/(\w+)/) {|s| s.capitalize}
    end
  end

  ##################################################################
  ##  Track Container
  ##################################################################
  class Track
    def initialize numero, nombre
      nombre.gsub! /\?/,''                    # Question marks are not allowed on most systems
      nombre.gsub! '*','#'                    # Wildcard is forbidden in Windows systems, so it is chaned by the harmless #
      nombre.gsub! '"', "'"                   # " is not supported in Windows systems either, sorry ;-)
      nombre.gsub! /:/,''                     # Colon is not shown correctly on my Mac, sorry :-)
      nombre.gsub! /\(.*?version.*?\)/i,''    # I don't like comments on the songs :-)
      nombre.gsub! /\(.*?remaster.*?\)/i,''   # I don't like comments on the songs :-)
      Sanitize.this! nombre
      @Nombre = Sanitize.titleize nombre
      @Numero = numero
    end

    def setNo newNo
      @Numero = newNo
    end
    
    def getNo
      return @Numero
    end
    
    def getName
      return @Nombre
    end
  end
  
  
  
  ##################################################################
  ##  Disc Container
  ##################################################################
  class Disc
    def initialize
      resetTracks!
      @mp3Url = ''
      @storedMp3Url = false

      ##  This is to add some extra information to the disc
      if File.exist? 'info.txt'
        puts "info.txt found, we'll add the extra info to your disc"
        File.open('info.txt','r').each_line do |linea|
          if /year:\s*([0-9]+)/.match linea
            @customYear = $1
          end
          if /album:\s*(.+)$/i.match linea
            @customAlbum = $1
          end
        end
      end

    end

    def hasMp3Url?
      return @hasMp3Url
    end

    def setMp3Url newUrl
      @hasMp3Url = true
      @mp3Url = newUrl
    end

    def getMp3Url
      return @mp3Url
    end

    def resetTracks!
      @Tracks = []
    end

    def setUrl newUrl
      @Url = newUrl
    end
    
    def getUrl
      return @Url
    end
    
    def setArtist newArtist
      @Artist = Sanitize.this newArtist
    end
    
    def getArtist
      return @Artist
    end
    
    def setTitle newTitle
      @Title = newTitle
      if @customAlbum
        puts "[!!] Custom title found!, adding to the title"
        @Title = @Title + ' ' + @customAlbum
      end
      Sanitize.this! @Title
    end
    
    def getTitle
      return @Title || ''
    end
    
    def setReleaseYear newYear
      if newYear.nil? or @Year.nil?
        @ReleaseYear = newYear
      else
        @ReleaseYear = newYear.to_i < @Year.to_i ? newYear : @Year
      end
    end
    
    def getReleaseYear
      return @ReleaseYear || @Year
    end
    
    def setYear newYear
      if @customYear
        @Year = @customYear
        puts "[!!] Year was set in the info.txt file"
      else
        @Year = newYear
      end
    end
    
    def getYear
      if @ReleaseYear.nil?
        return @Year
      else
        return @ReleaseYear
      end
    end
    
    def setTracks newTracks
      @Tracks = newTracks
    end
    
    def getTracks
      return @Tracks
    end

    def addTrack numero, nombre
      @Tracks.push Track.new( numero, nombre )
    end

    def [](position)
      return @Tracks[position+1]
    end

    def getTrack numero
      return @Tracks[numero]
    end

    def setImageUrl url
      @ImageURL = url
    end

    def getImageUrl
      return @ImageURL || ''
    end
  end
  
  

  ##################################################################
  ##  WebService
  ##################################################################
  class WebService
    
    def initialize mp3dir
      @mp3Dir    = mp3dir
      @webClient = HTTPClient.new :agent_name => "Mozilla/5.0 (Macintosh; I; Intel Mac OS X 11_7_9; de-LI; rv:1.9b4) Gecko/2012010317 Firefox/10.0a4"
    end
    
    def string2url string
      return string.gsub /\s/, '+'
    end
    
    def search
      puts "search MUST be redefined"
      exit 1
    end
    
    def getWebContent url
      response =  @webClient.get url, :follow_redirect => true
      return response.content
    end
  end
  

  ##################################################################
  ##  Wikipedia Class
  ##################################################################
	class WikipediaWS < WebService
		def initialize discName
			super
			title = discName.gsub /\s/,'_'
			puts "Querying wikipedia..."
			url  = "http://en.wikipedia.org/wiki/" + title
			response = @webClient.get url, :follow_redirect => true
			@releaseYear = 0
			for linea in response.content.split /\n/
				if /<td class="published">.+?([0-9]+)\s*</.match linea
					@releaseYear = $1
				end
			end
		end

		def getReleaseYear
			return @releaseYear || 0
		end
	end

  
  
  ##################################################################
  ##  Amazon Class
  ##################################################################
  class AmazonWS < WebService
    def search query, searchUntilPage=1,includeTrackInfo=true
      if query.empty?
        return Disc.new
      end
      if searchUntilPage <= 0
        return Disc.new
      end
      
      puts "Searching Amazon.com..."
      query = string2url query

      amazonURL = "http://www.amazon.com/s/ref=nb_sb_noss_2?url=search-alias%3Daps&field-keywords=" + query
      content   = getWebContent amazonURL
      disc      = getDiscFromWebSearch content, searchUntilPage, includeTrackInfo

      if disc.getTitle.empty?
        puts "Searching Amazon.de..."
        amazonURL = "http://www.amazon.de/s/ref=nb_sb_noss_2?url=search-alias%3Daps&field-keywords=" + query
        content   = getWebContent amazonURL
        disc      = getDiscFromWebSearch content, searchUntilPage, includeTrackInfo
      end

			wiki = WikipediaWS.new disc.getTitle
			if wiki.getReleaseYear.to_i > 0
				disc.setReleaseYear wiki.getReleaseYear
			end

      return disc
    end
    
    
    #---------------------------------------------------------------
    def trim string
      retorno = string
      retorno.gsub! /^\s*/,''
      retorno.gsub! /\s*$/,''
      return retorno
    end
    
    
    #---------------------------------------------------------------
    def getDiscFromWebSearch htmlFromAmazonSearch, searchUntilPage, includeTrackInfo
      discos   = []
      nextURL  = ''
      
      if searchUntilPage <= 0
        return Disco.new
      end

      for linea in htmlFromAmazonSearch.split /\n/
        
        url = titulo = artista = ""

        ##  Amazon.com
        ## ----------------------------------------
        if /<div class="productTitle">\s*<a href="(.*?)">\s*(.*?)\s*<\/a>\s*<span class="ptBrand">by\s*.*?>?(.+?)</i.match linea
          url     = trim $1
          titulo  = trim $2
          artista = trim $3          
					artista.gsub! /<.+>/,''
        end

        if /<div class="productTitle">\s*<a href="(.*?)">\s*(.*?)\s*<\/a>\s*<span class="ptBrand">by\s*<a href=".*?">(.*?)<\/a><\/span>(.+)/i.match linea
          url     = trim $1
          titulo  = trim $2
          artista = trim $3          
        end

        ##  Amazon.de
        ## ----------------------------------------
        if /<div class="productTitle">\s*<a href="(.*?)">\s*(.*?)\s*<\/a>\s*<span class="ptBrand">von\s*(.+?)</i.match linea
          url     = trim $1
          titulo  = trim $2
          artista = trim $3          
        end

        if /<div class="productTitle">\s*<a href="(.*?)">\s*(.*?)\s*<\/a>\s*<span class="ptBrand">von\s*<a href=".*?">(.*?)<\/a><\/span>(.+)/i.match linea
          url     = trim $1
          titulo  = trim $2
          artista = trim $3          
        end

        if not titulo.empty? and not url.empty? and not artista.empty?
          disco = Disc.new
          if /([0-9]+)\)/.match $4
            disco.setYear $1
          end
          
          disco.setUrl    url
          disco.setTitle  titulo
          disco.setArtist artista
          
          if includeTrackInfo
            getMissingInfoFromDisc disco
          end
          
          if @mp3Dir.matches? disco
            return disco
          else

            if disco.hasMp3Url?
              puts "Trying to get missing info from MP3"
              disco.setUrl disco.getMp3Url
              getMissingInfoFromDisc disco
              if @mp3Dir.matches? disco
                return disco
              end
            end

          end
        end
        
        if searchUntilPage > 0 and /<span class="pagnNext">\s*<a href="(.+?)"/.match linea
          nextURL = $1
        end
      end
      if nextURL.empty?
        return Disc.new
      end
      
      return search( nextURL, searchUntilPage - 1,includeTrackInfo )
    end
    
    
    # ------------------------------------------------------------------------
    def getMissingInfoFromDisc disco
      puts "URL: " + disco.getUrl
      html = getWebContent disco.getUrl

      if File.exist? 'folder.jpg'
        puts "folder.jpg found, this image will be used!"
      end

      for linea in html.split /\n/
        if /<a href="(.+?)">See all ([0-9]+) tracks on this disc<\/a>/.match linea
          puts "Need to get all " + $2.to_s + " tracks!"
          disco.resetTracks!
          disco.setUrl $1
          return getMissingInfoFromDisc disco
        end

        ##  Disc image
        ## -------------------------------------------------------------------
        @ImagePriority = 10

        if /<a href="(.+?)">MP3 Music,\s*[0-9]+\s*Songs,\s*[0-9]+<\/a>/i.match linea
          disco.setMp3Url $1
        end

        if /colorImages = \{"initial":\[\{"large":"(.+?)"/.match linea
          puts "Large image, found!"
          disco.setImageUrl $1
          img = getWebContent disco.getImageUrl
          unless File.exist? 'folder.jpg'    # Let the user put its own folder.jpg
            folderjpg = File.open "folder.jpg","w"
            folderjpg.write img
            folderjpg.close
          end
          @ImagePriority = 0
        end

        if @ImagePriority > 1 and /"hiRes":"(.+?)"/.match linea
          puts "Hi Res image, found!"
          disco.setImageUrl $1
          img = getWebContent disco.getImageUrl
          unless File.exist? 'folder.jpg'    # Let the user put its own folder.jpg
            folderjpg = File.open "folder.jpg","w"
            folderjpg.write img
            folderjpg.close
          end
          @ImagePriority = 1
        end

        if @ImagePriority > 2 and /"original_image", "(.+?)"/.match linea
          puts "Original image Found!"
          disco.setImageUrl $1
          img = getWebContent disco.getImageUrl
          unless File.exist? 'folder.jpg'    # Let the user put its own folder.jpg
            folderjpg = File.open "folder.jpg", "w"
            folderjpg.write img
            folderjpg.close
          end
          @ImagePriority = 2
        end

        if @ImagePriority > 3 and /"cust_image_[0-9]+", "(.+?)"/.match linea
          puts "Customer Image Found!"
          @ImagePriority = 3
          disco.setImageUrl $1
#          img = getWebContent disco.getImageUrl
#          folderjpg = File.open "folder.jpg", "w"
#          folderjpg.write img
#          folderjpg.close
        end
        

        ##  Track Type 1
        ## -------------------------------------------------------------------
        trackType = 0
        for trLine in linea.split '<tr>'
          if /<td class="titleCol">.*?\s*([0-9]+)\. <a href="[^"]+">([^<]+)<\/a>/.match trLine
            disco.addTrack $1,$2
            trackType = 1
          end
        end

        if trackType == 1
          trackType = 0
          next
        end

        ##  Track Type 2
        ## -------------------------------------------------------------------
        if /^\s*([0-9]+)\.\s*([^_<]+)\s*$/.match linea
          disco.addTrack $1,$2

        ##  Track Type 3
        ## -------------------------------------------------------------------
        elsif /<td class="songTitle">&nbsp; ([0-9]+). <.+?>(.+?)<\/a><\/td>/.match linea
          disco.addTrack $1, $2

        ##  Track Type 4
        ## -------------------------------------------------------------------
        elsif /<td class="songTitle">([0-9]+)\. <.+?>(.+?)<\/a>/.match linea
          disco.addTrack $1, $2

        ##  Track Type 5
        ## -------------------------------------------------------------------
        elsif !/Read more about shipping and returns/i.match linea and
							/([0-9]+). <a href=".+?">(.+?)<\/a>/.match linea
          disco.addTrack $1, $2
        end

        ##  Original release date
        ## -------------------------------------------------------------------
        if /original release date:.+?([0-9]{4,}).*?/i.match linea
          disco.setReleaseYear $1
        end
        
        if /\([a-z]+ [0-9]+, ([0-9]+)\)/i.match linea
          disco.setYear $1
        end
      end

      sleep 1 # Just 1 second delay, this is to hide a little bit the scraping
    end
  end
  
  class RTag
    ##  Perform pre-searches trying to match disc / mp3Directory
    ## ---------------------------------------------------------------------
    def initialize patron, album_title, release_year
      @directorio = Dir.pwd
      patronAlt  = @directorio.split /\//
      patronAlt  = patronAlt[patronAlt.size-1]
      patron     = patron || patronAlt

      @mp3Dir     = Mp3Dir.new @directorio
      @aws        = AmazonWS.new @mp3Dir
      @discFound  = @aws.search patron

      @album_title_extra = album_title
      @release_year      = release_year
    end

    ##  Work on the directory, tag every mp3 and download the cover
    ## ---------------------------------------------------------------------
    def worked?
      if @discFound.getTitle.empty?
        puts "Disco no encontrado"
        return false
      end

      for i in (0..@mp3Dir.getMP3.count-1)
        trackNumber = i+1
        trackNumber = trackNumber < 10 ? '0' + trackNumber.to_s : trackNumber
        mp3File = @directorio + '/' + @mp3Dir.getMP3[i]
        track   = @discFound.getTracks[i]

        system "eyeD3 --remove-all \"#{mp3File}\""

        tag = ID3Lib::Tag.new mp3File

        tag.title = track.getName
        tag.performer = @discFound.getArtist
        tag.year      = @release_year.empty? ? @discFound.getYear : @release_year
        tag.track     = i+1
        tag.composer  = @discFound.getArtist
        tag.album     = @discFound.getTitle + (@album_title_extra.empty? ? '' : @album_title_extra)
        tag.comment   = '1.1.1'

        cover = {
          :id          => :APIC,
          :mimetype    => 'image/jpeg',
          :picturetype => 3,
          :description => 'Disc Cover',
          :textenc     => 0,
          :data        => File.read('folder.jpg')
        }

        tag << cover
        tag.update!

        name = track.getName
        name.gsub! /\//, ''
        
        name.sub! '*','#'
        name.sub! '?',''

        targetFile = @directorio + "/" + trackNumber.to_s + ". " + name + ".mp3"

        File.rename mp3File, targetFile
      end
      File.rename 'folder.jpg', @directorio + '/folder.jpg'
      return true
    end
  end
end # End of module RTag

year = ''
title = ''
busqueda = ' '
i = 0
while i < ARGV.size

  if /-y/i.match ARGV[i]
    i += 1
    year = ARGV[i]
    i += 1
    next
  end

  if /-t/i.match ARGV[i]
    i += 1
    title = title + " " + ARGV[i]
    i += 1
    next
  end

  busqueda += ARGV[i] + " "
  i += 1
end

tag = RTag::RTag.new busqueda, title, year

if tag.worked?
  puts "Disc has been correctly tagged!"
else
  puts"**NO TAG FOUND**  :-("
end
