class Directory
  @@now = Time.now

  CLEAR      = "\e[0m"
  # Set the terminal's foreground ANSI color to black.
  BLACK      = "\e[30m"
  # Set the terminal's foreground ANSI color to red.
  RED        = "\e[31m"
  # Set the terminal's foreground ANSI color to green.
  GREEN      = "\e[32m"
  # Set the terminal's foreground ANSI color to yellow.
  YELLOW     = "\e[33m"
  # Set the terminal's foreground ANSI color to blue.
  BLUE       = "\e[34m"
  # Set the terminal's foreground ANSI color to magenta.
  MAGENTA    = "\e[35m"
  # Set the terminal's foreground ANSI color to cyan.
  CYAN       = "\e[36m"
  # Set the terminal's foreground ANSI color to white.
  WHITE      = "\e[37m"

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

  # return array containing time, size and filename.
  # Earlier string was returned, but array allows coloring of each item.
  def self.format_long_list(file_name, format)
    stat = if File.exists?(file_name)
             File.info(file_name)
           else
             File.info(file_name, follow_symlinks: false)
           end
    time = stat.modification_time
    span = @@now - time
    color = if span.total_minutes <= 60
              YELLOW
            elsif span.total_hours <= 24
              GREEN
            elsif span.total_days <= 7
              CYAN
            elsif span.total_days <= 365
              MAGENTA
            elsif span.total_days <= 3650
              BLUE
            else
              BLACK
            end
    size = stat.size
    szcolor = if size < 1024
                BLUE
              elsif size < 1_024_000
                GREEN
              elsif size < 10_024_000
                CYAN
              elsif size < 100_024_000
                MAGENTA
              elsif size < 1_024_000_000
                WHITE
              else
                YELLOW
              end
    "#{color}%s #{szcolor}%8s #{format}%s" % [stat.modification_time.to_local.to_s("%Y/%m/%d %H:%M") , stat.size.humanize, file_name]
  end
end
