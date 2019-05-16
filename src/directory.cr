class Directory

  # TODO: list_total, cur_list, previous_index do in caller.
  # Read a directory to an array and sort it directories first.
  def self.read_dir(match_hidden = false)
    dirs = [] of String
    files = [] of String

    pwd = Dir.current

    # If '$PWD' is '/', unset it to avoid '//'.
    pwd = "" if pwd == "/"

    entries = Dir.glob(pwd + "/*") #, match_hidden: false)
    # WHY does fff use full filenames in listing?
    # because when we move a file, we need full name

    unless match_hidden
      entries = entries.reject{|f| File.basename(f).starts_with?('.')}
    end
    entries = entries.sort

    entries.each do |item|
      if File.directory?(item)
        dirs.push item

      else
        files.push item
      end
    end
    list = dirs + files

    list
  end

  def format_long_list(file_name)
    stat = if File.exists?(file_name)
             File.info(file_name)
           else
             File.info(file_name, follow_symlinks: false)
           end
    "%s %8d %s" % [stat.modification_time.to_local.to_s("%Y:%m:%d %H:%M") , stat.size, file_name]
  end
end
