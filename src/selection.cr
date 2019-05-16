class Selection
  getter marked_files = [] of String
  def initialize
    # @marked_files = [] of String
    @marked_dir   = ""
  end
  def size
    @marked_files.size
  end
  def clear
    @marked_files.clear
    @marked_dir = Dir.current
  end
  def marked?(file)
    @marked_files.includes?(file)
  end
  def mark(file)
    clear if @marked_dir != Dir.current

    @marked_files.push(file)
    @marked_dir = Dir.current
  end
  def mark(files : Array(String))
    clear if @marked_dir != Dir.current

    @marked_files.concat(files)
  end
  def toggle(file)
    if marked? file
      unmark file
    else
      mark(file)
    end
  end
  def unmark(file)
    @marked_files.delete(file)
  end

end
