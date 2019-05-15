class Colorparser
  BLUE    = "\e[1;34m"
  def initialize
    @fff_ls_colors   = false
    # This hash contains colors for file patterns, updated from LS_COLORS
    @ls_pattern = {} of String => String

    # This hash contains colors for file types, updated from LS_COLORS
    # Default values in absence of LS_COLORS
    # crystal sends Directory, with initcaps, Symlink, CharacterDevice, BlockDevice
    # Pipe, Socket and Unknown https://crystal-lang.org/api/0.28.0/File/Type.html
    @ls_ftype = {
      "Directory" => BLUE,
      "Symlink"   => "\e[01;36m",
      "mi"        => "\e[01;31;7m",
      "or"        => "\e[40;31;01m",
      "ex"        => "\e[01;32m",
    }

    # contains colors for various extensions. Key contains dot (.txt)
    @ls_colors = {} of String => String
    @lsp       = ""  # string containing concatenated patterns
  end

  def get_ls_colors
    # Parse the LS_COLORS variable and declare each file type
    # as a separate variable.
    # Format: ':.ext=0;0:*.jpg=0;0;0:*png=0;0;0;0:'
    colorvar = ENV["LS_COLORS"]?
      if colorvar.nil?
        @fff_ls_colors = false
        return
    end
    @fff_ls_colors = true
    ls = colorvar.split(":")
    ls.each do |e|
      next if e == ""
      patt, colr = e.split "="
      colr = "\e[" + colr + "m"
      if e.starts_with? "*."
        # extension. avoid '*' and use the rest as key
        @ls_colors[patt[1..-1]] = colr
        # @@log.debug "COLOR: Writing extension (#{patt})."
      elsif e[0] == '*'
        # file pattern. this would be a glob pattern not regex
        # only for files not directories
        # Convert glob pattern to regex.
        patt = patt.gsub(".", "\.")
        patt = patt.sub("+", "\\\+") # if i put a plus it does not go at all
        patt = patt.gsub("-", "\-")
        patt = patt.tr("?", ".")
        patt = patt.gsub("*", ".*")
        patt = "^#{patt}" if patt[0] != "."
        patt = "#{patt}$" if patt[-1] != "*"
        @ls_pattern[patt] = colr
        # @@log.debug "COLOR: Writing file (#{patt})."
      elsif patt.size == 2
        # file type, needs to be mapped to what crystal will return
        # file, directory di, characterSpecial cd, blockSpecial bd, fifo pi, link ln, socket so, or unknown
        # di = directory
        # fi = file
        # ln = symbolic link
        # pi = fifo file
        # so = socket file
        # bd = block (buffered) special file
        # cd = character (unbuffered) special file
        # or = symbolic link pointing to a non-existent file (orphan)
        # mi = non-existent file pointed to by a symbolic link (visible when you type ls -l)
        # ex = file which is executable (ie. has 'x' set in permissions).
        case patt
        when "di"
          @ls_ftype["Directory"] = colr
        when "cd"
          @ls_ftype["CharacterDevice"] = colr
        when "bd"
          @ls_ftype["BlockDevice"] = colr
        when "pi"
          @ls_ftype["Pipe"] = colr
        when "ln"
          @ls_ftype["Symlink"] = colr
        when "so"
          @ls_ftype["Socket"] = colr
        else
          @ls_ftype[patt] = colr
        end
        # @@log.debug "COLOR: ftype #{patt}"
      end
    end
    @lsp = @ls_pattern.keys.join('|')
  end

  def color_for(file)
    file_ext = File.extname(file)
    format = ""
    suffix = ""

    ftype = ""
    # check otherwise deadlinks crash 'info'
    if File.exists?(file)
      ftype = File.info(file).type.to_s # it was File::Type thus not matching
    end
    # Directory.
    if File.directory?(file)
      color2 = ENV["FFF_COL1"]? || "2"
      color = @ls_ftype["Directory"]? || "\e[1;3#{color2}m"
      format = color
      suffix = "/"

    elsif ftype == "BlockDevice"
      # Block special file.
      color = @ls_ftype[ftype]? || "\e[40;33;01m"
      format = color

    elsif ftype == "CharacterDevice"
      # Character special file.
      color = @ls_ftype[ftype]? || "\e[40;33;01m"
      # format = "\e[#{color}m"
      format = color

    elsif File.executable?(file)
      # Executable file.
      color = @ls_ftype["ex"]? || "\e[01;32m"
      # format = "\e[#{color}m"
      format = color

    elsif File.symlink?(file) && !File.exists?(file)
      # Symbolic Link (broken).
      color = @ls_ftype["mi"]? || "\e[01;31;7m"
      # format = "\e[#{color}m"
      format = color

    elsif File.symlink?(file)
      # Symbolic Link.
      color = @ls_ftype["Symlink"]? || "\e[01;36m"
      # format = "\e[#{color}m"
      format = color

      # Fifo file.
    elsif ftype == "Pipe"
      color = @ls_ftype[ftype]? || "\e[40;33m"
      # format = "\e[#{color}m"
      format = color

    elsif ftype == "Socket"
      # Socket file.
      color = @ls_ftype[ftype]? || "\e[01;35m"
      # format = "\e[#{color}m"
      format = color

    elsif @fff_ls_colors && !@ls_pattern.empty? && file.match(/#{@lsp}/)
      # found a file pattern
      @ls_pattern.each do |k, v|
        if /#{k}/.match(file)
          # @@log.debug "#{file} matched #{k}. color is #{v[1..-2]}"
          format = v
          # @@log.debug "color for pattern:#{file} is #{format.sub(";",":")}"
          break
        end
      end
    elsif @fff_ls_colors && !@ls_colors.empty? && file_ext != "" && @ls_colors[file_ext]?
      # found a color for that file extension
      format = @ls_colors[file_ext]
      # @@log.debug "color for extn: #{file_ext} is #{format.sub(";",":")}"
    else
      # case of File or fi
      color = @ls_ftype[ftype]? || "\e[37m"
      # format = "\e[#{color}m"
      format = color

    end
    # { format: format, suffix: suffix }
    { format, suffix }
  end

end
