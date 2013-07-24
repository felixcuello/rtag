#!/home/felix/.rvm/rubies/ruby-1.9.3-p194/bin/ruby

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
        if /[0-9]+\s*[\.\-]?\s*(.+?).mp3$/i.match archivo
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
  ##  Track Container
  ##################################################################
  class Track
    def initialize numero, nombre
      nombre.gsub! /\?/,''                    # Question marks are not allowed on most systems
      nombre.gsub! /:/,''                     # Colon is not shown correctly on my Mac, sorry :-)
      nombre.gsub! /&amp;/,'&'                # Just &
      nombre.gsub! /&quot;/,'"'               # Just "
      nombre.gsub! /\(.*?version.*?\)/i,''    # I don't like comments on the songs :-)
      nombre.gsub! /\(.*?remaster.*?\)/i,''   # I don't like comments on the songs :-)
      nombre.gsub! /\s*$/,''                  # Trailing spaces
      @Nombre = nombre
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
      newArtist.gsub! /&amp;/, '&'
      @Artist = newArtist
    end
    
    def getArtist
      return @Artist
    end
    
    def setTitle newTitle
      @Title = newTitle
    end
    
    def getTitle
      return @Title || ''
    end
    
    def setReleaseYear newYear
      if newYear.nil? or @Year.nil?
        @ReleaseYear = newYear
      else
        @ReleaseYear = newYear < @Year ? newYear : @Year
      end
    end
    
    def getReleaseYear
      return @ReleaseYear || @Year
    end
    
    def setYear newYear
      @Year = newYear
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
      
      puts "Searching [#{searchUntilPage} pages to go]..."
      query = string2url query
      amazonURL = "http://www.amazon.com/s/ref=nb_sb_noss_2?url=search-alias%3Daps&field-keywords=" + query

      content   = getWebContent amazonURL
      
      return getDiscFromWebSearch content, searchUntilPage, includeTrackInfo
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

        if /<div class="productTitle">\s*<a href="(.*?)">\s*(.*?)\s*<\/a>\s*<span class="ptBrand">by\s*(.+?)</i.match linea
          url     = trim $1
          titulo  = trim $2
          artista = trim $3          
        end

        if /<div class="productTitle">\s*<a href="(.*?)">\s*(.*?)\s*<\/a>\s*<span class="ptBrand">by\s*<a href=".*?">(.*?)<\/a><\/span>(.+)/i.match linea
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
          folderjpg = File.open "folder.jpg","w"
          folderjpg.write img
          folderjpg.close
          @ImagePriority = 0
        end

        if @ImagePriority > 1 and /"hiRes":"(.+?)"/.match linea
          puts "Hi Res image, found!"
          disco.setImageUrl $1
          img = getWebContent disco.getImageUrl
          folderjpg = File.open "folder.jpg","w"
          folderjpg.write img
          folderjpg.close
          @ImagePriority = 1
        end

        if @ImagePriority > 2 and /"original_image", "(.+?)"/.match linea
          puts "Original image Found!"
          disco.setImageUrl $1
          img = getWebContent disco.getImageUrl
          folderjpg = File.open "folder.jpg", "w"
          folderjpg.write img
          folderjpg.close
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
        elsif /([0-9]+). <a href=".+?">(.+?)<\/a>/.match linea
          disco.addTrack $1, $2
        end

        ##  Original release date
        ## -------------------------------------------------------------------
        if /original release date:.+?([0-9]{4,}).*?/i.match linea
          disco.setReleaseYear $1
        end        
      end

      sleep 1 # Just 1 second delay, this is to hide a little bit the scrapping
    end
  end
  
  class RTag
    ##  Perform pre-searches trying to match disc / mp3Directory
    ## ---------------------------------------------------------------------
    def initialize directorio, patron
      if not patron
        partes = directorio.split '/'
        patron = partes[partes.count-2] + " " + partes[partes.count-1]
        patron.gsub! /\(.*?\)/, ''
        patron.downcase!
      end
      puts "Dir  : " + directorio
      puts "Pat  : " + patron

      @directorio = directorio
      @mp3Dir     = Mp3Dir.new @directorio
      @aws        = AmazonWS.new @mp3Dir
      @discFound  = @aws.search patron
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
        tag.year      = @discFound.getYear
        tag.track     = i+1
        tag.composer  = @discFound.getArtist
        tag.album     = @discFound.getTitle
        tag.comment   = 'rtag v0.7'

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
        targetFile = @directorio + "/" + trackNumber.to_s + ". " + name + ".mp3"

        File.rename mp3File, targetFile
      end
      File.rename 'folder.jpg', @directorio + '/folder.jpg'
      return true
    end
  end
end # End of module RTag

tag = RTag::RTag.new ARGV[0],ARGV[1]
print "Done!" if tag.worked?


exit 0

tagger = DirectoryTagger.new
files = tagger.TagWithDisc ARGV[1], "pepe"
for mp3 in files
  puts mp3
end

