# ----------------------------------------------------------------------------- #
#         File: fff.cr
#  Description: port of fff from bash
#             : freakin fast filer/file manager.
#       Author: j kepler  http://github.com/mare-imbrium/canis/
#         Date: 2019-05-05
#      License: MIT
#  Last update: 2019-05-07 16:27
# ----------------------------------------------------------------------------- #
# port of fff (bash)
require "readline"
require "logger"

module Fff
  VERSION = "0.1.0"
  BLUE      = "\e[1;34m"

  class Filer
    @@kh = {} of String => String
    @@kh["\eOP"] = "F1"
    @@kh["\e[A"] = "UP"
    @@kh["\e[5~"] = "PGUP"
    @@kh["\e"] = "ESCAPE"
    KEY_PGDN = "\e[6~"
    KEY_PGUP = "\e[5~"
    # # I needed to replace the O with a [ for this to work
    #  in Vim Home comes as ^[OH whereas on the command line it is correct as ^[[H
    KEY_HOME = "\e[H"
    KEY_END  = "\e[F"
    KEY_F1   = "\eOP"
    KEY_UP   = "\e[A"
    KEY_DOWN = "\e[B"

    @@kh[KEY_PGDN] = "PgDn"
    @@kh[KEY_PGUP] = "PgUp"
    @@kh[KEY_HOME] = "Home"
    @@kh[KEY_END] = "End"
    @@kh[KEY_F1] = "F1"
    @@kh[KEY_UP] = "UP"
    @@kh[KEY_DOWN] = "DOWN"
    KEY_LEFT  = "\e[D"
    KEY_RIGHT = "\e[C"
    @@kh["\eOQ"] = "F2"
    @@kh["\eOR"] = "F3"
    @@kh["\eOS"] = "F4"
    @@kh[KEY_LEFT] = "LEFT"
    @@kh[KEY_RIGHT] = "RIGHT"
    KEY_F5 = "\e[15~"
    KEY_F6 = "\e[17~"
    KEY_F7 = "\e[18~"
    KEY_F8 = "\e[19~"
    KEY_F9 = "\e[20~"
    KEY_F10 = "\e[21~"
    KEY_S_F1 = "\e[1;2P"
    @@kh[KEY_F5] = "F5"
    @@kh[KEY_F6] = "F6"
    @@kh[KEY_F7] = "F7"
    @@kh[KEY_F8] = "F8"
    @@kh[KEY_F9] = "F9"
    @@kh[KEY_F10] = "F10"
    # testing out shift+Function. these are the codes my kb generates
    @@kh[KEY_S_F1] = "S-F1"
    # @@kh["\e[1;2Q"] = "S-F2"


    @@log = Logger.new(io: File.new(File.expand_path("log.txt"), "w"))
    @@log.level = Logger::DEBUG
    @@log.info "========== fff    started ================= ----------"
    # # --------------------------------------------- ##
    def initialize
      @lines           = 0
      @columns         = 0
      @max_items       = 0
      @list            = [] of String
      @cur_list        = [] of String
      @scroll          = 0
      @list_total      = 0
      @marked_files    = [] of (String|Nil)
      @mark_dir        = ""
      @opener          = "open"
      @file_program    = ""
      @file_flags      = "bIL"
      @file_pre        = ""
      @file_post       = ""
      @mark_pre        = ""
      @mark_post       = ""
      @fff_ls_colors   = false
      @previous_index  = 0
      @find_previous   = false
      @y               = 0
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
    end

    def get_os
      # ostype = ENV["OSTYPE"]?  # comes nil
      ostype = `uname`
      case ostype
      when /Darwin/
        @@log.debug "darwin"
        @opener     = "open"
        @file_flags = "bIL"
        @@log.debug "ED: #{ENV["EDITOR"]?}"
        @@log.debug "PAGER: #{ENV["PAGER"]?}"
        # puts "keys: #{ENV.keys.join("\n")}"
        # we will be moving to some dir, not using trash
      when "haiku"
        @opener = "open"
        # set trash command and dir
        # what the hell is this anyway
        @@log.debug "Haiku"
      else
        @@log.debug "Else shouldn't linux be taken care of ??"
        @@log.debug ostype
      end
    end
    def setup_terminal
      # Setup the terminal for the TUI.
      # '\e[?1049h': Use alternative screen buffer.
      # '\e[?7l':    Disable line wrapping.
      # '\e[?25l':   Hide the cursor.
      # '\e[2J':     Clear the screen.
      # '\e[1;Nr':   Limit scrolling to scrolling area.
      #              Also sets cursor to (0,0).
      # printf("\e[?1049h\e[?7l\e[?25l\e[2J\e[1;%sr", @max_items)
      printf("\e[?1049h\e[?7l\e[?25l\e[2J\e[1;%sr", @max_items)
      # Hide echoing of user input
      system("stty -echo")
    end

    def reset_terminal
      @@log.debug " called reset terminal "
      # Reset the terminal to a useable state (undo all changes).
      # '\e[?7h':   Re-enable line wrapping.
      # '\e[?25h':  Unhide the cursor.
      # '\e[2J':    Clear the terminal.
      # '\e[;r':    Set the scroll region to its default value.
      #             Also sets cursor to (0,0).
      # '\e[?1049l: Restore main screen buffer.
      print("\e[?7h\e[?25h\e[2J\e[;r\e[?1049l")

      # Show user input.
      system("stty echo")
    end

    def clear_screen
      # Only clear the scrolling window (dir item list).
      # '\e[%sH':    Move cursor to bottom of scroll area.
      # '\e[9999C':  Move cursor to right edge of the terminal.
      # '\e[1J':     Clear screen to top left corner (from cursor up).
      # '\e[2J':     Clear screen fully (if using tmux) (fixes clear issues).
      # '\e[1;%sr':  Clearing the screen resets the scroll region(?). Re-set it.
      #              Also sets cursor to (0,0).
      ## if TMUX has a value then use clear
      ## if TMUX is blank, then return blank

      # printf("\e[%sH\e[9999C\e[1J%b\e[1;%sr", \
             # @lines-2, ENV["TMUX"]? && "\e[2J" , @max_items)


      printf("\e[%sH\e[9999C\e[1J\e[1;%sr",
        @lines-2,
        @max_items      ) # was grows
    end


    def setup_options
      # Some options require some setup.
      # This function is called once on open to parse
      # select options so the operation isn't repeated
      # multiple times in the code.

      # check if this variable contains %f which represents file.
      # anything prior to %f is pre and anything after is post.

      # Format for normal files.
      var = ENV["FFF_FILE_FORMAT"]?
        if var
          match = var.match(/\(.*\)%f\(.*\)/)
          if match
            @file_pre = match[0]? || ""
            @file_post = match[1]? || ""
          end
      end

      # Format for marked files.
      var = ENV["FFF_MARK_FORMAT"]?
        if var
          match = var.match(/\(.*\)%f\(.*\)/)
          if match
            @mark_pre = match[0]? || ""
            @mark_post = match[0]? || ""
          end
      end

    end

    def get_term_size
      # Get terminal size ('stty' is POSIX and always available).
      # This can't be done reliably across all bash versions in pure bash.
      l, c = `stty size`.split(" ") #.map{ |e| e.to_i }
      @lines = l.to_i
      @columns = c.to_i

      # Max list items that fit in the scroll area.
      @max_items = @lines - 3
    end

    def get_ls_colors
      # Parse the LS_COLORS variable and declare each file type
      # as a separate variable.
      # Format: ':.ext=0;0:*.jpg=0;0;0:*png=0;0;0;0:'
      unless ENV["LS_COLORS"]?
          @fff_ls_colors = false
        return
      end

      # Turn $LS_COLORS into an array.

      # TODO not totally clear what is happening with all the variablaes and arrays

    end

    def get_mime_type(file)
      # Get a file's mime_type.
      flags = @file_flags || "biL"
      mime_type=`file "-#{flags}" #{file}`
    end

    def status_line(filename=nil)
      # Status_line to print when files are marked for operation.

      # in fff, file_program was an array with the command and params
      #  which was displayed with '*' and executed with '@' naturally.
      mark_ui = "[#{@marked_files}.compact.size] selected (#{@file_program}) [p] ->"

      # Escape the directory string.
      # Remove all non-printable characters.
      # @pwd_escaped = "${PWD//[^[:print:]]/^[}"
      pwd_escaped = Dir.current.gsub(/[^[:print:]]/, "?")

      ui = @marked_files.compact.size == 0 ? "" : mark_ui

      fname = filename || pwd_escaped

      color = ENV["FFF_COL2"]? || "1"

      # '\e7':       Save cursor position.
      #              This is more widely supported than '\e[s'.
      # '\e[%sH':    Move cursor to bottom of the terminal.
      # '\e[30;41m': Set foreground and background colors.
      # '%*s':       Insert enough spaces to fill the screen width.
      #              This sets the background color to the whole line
      #              and fixes issues in 'screen' where '\e[K' doesn't work.
      # '\r':        Move cursor back to column 0 (was at EOL due to above).
      # '\e[m':      Reset text formatting.
      # '\e[H\e[K':  Clear line below status_line.
      # '\e8':       Restore cursor position.
      #              This is more widely supported than '\e[u'.
      printf "\e7\e[%sH\e[30;4%sm%*s\r%s %s%s\e[m\e[%sH\e[K\e8", \
        @lines-1, \
        color, \
        @columns, " ", \
        "(#{@scroll+1}/#{@list_total+1})", \
        ui, \
        fname, \
        @lines
    end

    def read_dir
      # Read a directory to an array and sort it directories first.
      dirs = [] of String
      files = [] of String
      item_index = 0

      pwd = Dir.current
      #oldpwd = ENV["OLDPWD"] # WRONG

      # If '$PWD' is '/', unset it to avoid '//'.
      pwd = "" if pwd == "/"

      entries = Dir.glob(pwd + "/*")
      entries.each do |item|
        if File.directory?(item)
          dirs.push item
          item_index += 1

          # Find the position of the child directory in the
          # parent directory list.
          @previous_index = item_index if item == @oldpwd

        else
          files.push item
        end
      end
      @list = dirs + files

      # Indicate that the directory is empty.
      # @list ||= ["empty"]
      @list.push "empty" if @list && @list.empty?

      @list_total = @list.size - 1
      # @@log.debug "read_dir: #{@list_total}, prev: #{@previous_index}"
      # @@log.debug "read_dir: #{pwd},:: #{@oldpwd}"
      # @@log.debug "read_dir: #{@list}"
      marked_files_clear


      # Save the original dir in a second list as a backup.
      @cur_list = @list
    end

    def print_line(index)
      # Format the list item and print it.
      file = @list[index]?
        # If the dir item doesn't exist, end here.
        return unless file

      file_name = File.basename(file)
      file_ext = File.extname(file_name)
      format = ""
      suffix = ""

      ftype = File.info(file).type.to_s # it was File::Type thus not matching
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
        format = "\e[#{color}m"
        format = color

      elsif File.executable?(file)
        # Executable file.
        color = @ls_ftype["ex"]? || "\e[01;32m"
        format = "\e[#{color}m"
        format = color

      elsif File.symlink?(file) && !File.exists?(file)
        # Symbolic Link (broken).
        color = @ls_ftype["mi"]? || "\e[01;31;7m"
        format = "\e[#{color}m"
        format = color

      elsif File.symlink?(file)
        # Symbolic Link.
        color = @ls_ftype["Symlink"]? || "\e[01;36m"
        format = "\e[#{color}m"
        format = color

        # Fifo file.
      elsif ftype == "Pipe"
        color = @ls_ftype[ftype]? || "\e[40;33m"
        format = "\e[#{color}m"
        format = color

      elsif ftype == "Socket"
        # Socket file.
        color = @ls_ftype[ftype]? || "\e[01;35m"
        format = "\e[#{color}m"
        format = color

        # NEED to decipher exactly what is happening here in fff
        # LS_COLORS and pattern stuff and how BASH_REMATCH is filled
      else
        # case of File or fi
        color = @ls_ftype[ftype]? || "\e[37m"
        format = "\e[#{color}m"
        format = color

      end
      # If the list item is under the cursor.
      if index == @scroll

        color2 = ENV["FFF_COL4"]? || "6"
        color = "1;3#{color2};7"
        format = "\e[#{color}m"
      end

      # If the list item is marked for operation.
      # NOTE: fff uses 'null' for list[$1] which cannot be blank
      # since fff returns earlier if blank.

      # if marked_files is empty we should not check
      mf = @marked_files[index]? || "null"
      if mf == file
        @mark_pre ||= ""
        @mark_post ||= "*"
        suffix = @mark_post
        color = ENV["FFF_COL3"]? || "1"
        format = "\e[3#{color}m#{@mark_pre}"
      end

      # Escape the directory string.
      # Remove all non-printable characters.
      file_name = file_name.gsub(/[^[:print:]]/, "?")

      printf("\r%s%s\e[m\r", \
             "#{@file_pre}#{format}", \
             "#{file_name}#{suffix}#{@file_post}")
      # printf("\r%s\r", file_name)
    end

    def draw_dir
      # Print the max directory items that fit in the scroll area.
      scroll_start = @scroll
      scroll_new_pos = 0
      scroll_end = 0

      # When going up the directory tree, place the cursor on the position
      # of the previous directory.
      if @find_previous
        scroll_start    = @previous_index - 1
        @scroll         = scroll_start

        # Clear the directory history. We're here now.
        @find_previous = false
      end

      # If current dir is near the top of the list, keep scroll position.
      if @list_total < @max_items || @scroll < @max_items/2
        scroll_start = 0
        scroll_end = @max_items
        scroll_new_pos = @scroll + 1
        # If curent dir is near the end of the list, keep scroll position.
      elsif @list_total - @scroll < @max_items/2
        scroll_start    = @list_total - @max_items + 1
        scroll_new_pos  = @max_items - (@list_total - @scroll)
        scroll_end      = @list_total + 1
        # If current diris somewhere in the middle, center scroll position.
      else
        scroll_start    =  @scroll       -  @max_items/2
        scroll_end      =  scroll_start  +  @max_items
        scroll_new_pos  =  @max_items/2  +  1
      end
      @@log.debug "scroll_start: #{scroll_start}"
      @@log.debug "scroll_end:   #{scroll_end}"


        # Reset cursor position.
        printf "\e[H"
        i = scroll_start
        while i < scroll_end
          print("\n") if i > scroll_start
          # @@log.debug " calling print_line with #{i}"
          print_line(i)
          # @@log.debug " after   print_line with #{i}"
          i += 1
        end


        # Move the cursor to its new position if it changed.
        # If the variable 'scroll_new_pos' is empty, the cursor
        # is moved to line '0'.
        printf("\e[%sH", scroll_new_pos)
        @y = scroll_new_pos
    end

    def redraw(full = false)
      @@log.debug "inside redraw with #{full}"
      # Redraw the current window.
      # If 'full' is passed, re-fetch the directory list.
      if full
        # @@log.debug "inside redraw before read_dir"
        read_dir
        # @@log.debug "inside redraw after  read_dir"
        @scroll = 0
      end

      # @@log.debug "inside redraw before clear_screen: #{@lines}, #{@max_items}"
      clear_screen
        # @@log.debug "inside redraw after  clear_screen"
      draw_dir
        # @@log.debug "inside redraw after  draw_dir"
      status_line
        # @@log.debug "inside redraw after  status_line"
    end

    def marked_files_clear
      @marked_files.clear
      @list_total.times { @marked_files.push nil }
    end

    def mark(index, operation)
      # Mark file for operation.
      # If an item is marked in a second directory,
      # clear the marked files.
      # NOTE: `fff` puts values in any index of the array but Crystal will given an OOBE
      # so we cannot mimick that logic here. I have inserted nils in the array
      if Dir.current != @mark_dir
        marked_files_clear
      end

      # Don't allow the user to mark the empty directory list item.
      return if @list[0] == "empty" && !@list[1]?

        if index == -1
          if @marked_files.compact.size != @list.size
            # @marked_files = @list.as(Array(String|Nil))
            @marked_files.clear
            @marked_files.concat @list
            @mark_dir     = Dir.current
          else
            marked_files_clear
          end

          redraw
      else
        if @marked_files[index] == @list[index]
          @marked_files[@scroll] = nil
        else
          @marked_files[index] = @list[index]
          @mark_dir = Dir.current
        end

        # Clear line before changing it.
        print "\e[K"
        print_line index
      end

      # Find the program to use.
      case operation
      when /yY/
        @file_program = "cp -iR"
      when /mM/
        @file_program = "mv -i"
      when /sS/
        @file_program = "ln -s"

        # These are 'fff' functions.
      when /dD/
        @file_program = "trash"
      when /bB/
        @file_program = "bulk_rename"
      end

      status_line
    end

    def get_char : String
      STDIN.raw do |io|
        buffer = Bytes.new(4)
        bytes_read = io.read(buffer)
        return "ERR" if bytes_read == 0
        input = String.new(buffer[0, bytes_read])

        key = @@kh[input]?
          return key if key

        cn = buffer[0]
        return "ENTER" if cn == 10 || cn == 13
        return "BACKSPACE" if cn == 127
        return "C-SPACE" if cn == 0
        return "SPACE" if cn == 32
        # next does not seem to work, you need to bind C-i
        return "TAB" if cn == 8

        if cn >= 0 && cn < 27
          x = cn + 96
          return "C-#{x.chr}"
        end
        if cn == 27
          if bytes_read == 2
            return "M-#{buffer[1].chr}"
          end
        end
        return input
      end
    end

    def open(file="/")
      if File.directory?(file)
        @search = false
        @search_end_early = false
        @oldpwd = Dir.current
        Dir.cd file
        redraw true
      elsif File.file?(file)
        mime_type = get_mime_type file
        if mime_type.includes?("text") \
            || mime_type.includes?("x-empty")\
            || mime_type.includes?("json")
          clear_screen
          reset_terminal
          # "${VISUAL:-${EDITOR:-vi}}" "$1"
          # ed = ENV["VISUAL"]? || ENV["EDITOR"]? || "vi"
          ed = ENV["MANPAGER"]? || ENV["PAGER"]? || "less"
          @@log.debug "ED: #{ed} #{file}"
          system("#{ed} #{file}")
          setup_terminal
          redraw
        else
                # 'nohup':  Make the process immune to hangups.
                # '&':      Send it to the background.
                # 'disown': Detach it from the shell.
                # nohup "${FFF_OPENER:-${opener:-xdg-open}}" "$1" &>/dev/null &
                # disown
                op = @opener || "xdg-open"
                @@log.debug "OPEN: #{op} FILE: #{file}"
                # `#{op} #{file}`
        end
      end
    end # open

    def cmd_line(str1, str2=nil)
      @cmd_reply = ""

    # '\e7':     Save cursor position.
    # '\e[?25h': Unhide the cursor.
    # '\e[%sH':  Move cursor to bottom (cmd_line).
      print("\e7\e[%sH\e[?25h", @lines)

    end

    def handle_key(key)
      @@log.debug "inside handle_key with #{key}"
      pwd = Dir.current

      case key
      when "RIGHT", "l", "ENTER", "RETURN"
        # Open list item.
        open @list[@scroll]
      when "LEFT", "h", "BACKSPACE"
        # If a search was done, clear the results and open the current dir.
        if @search && @search_end_early != true
          open pwd
          # If '$PWD' is '/', do nothing.
        elsif pwd && pwd != "/"
          @find_previous = true
          dir =  File.expand_path("..")
          @@log.debug " LEFT opening #{dir}"
          @oldpwd = pwd
          open dir
        end
      when "DOWN", "j"
        if @scroll < @list_total
          @scroll += 1
          @y += 1 if @y < @max_items

          print_line @scroll - 1
          puts
          print_line @scroll
          status_line
        end
      when "UP", "k"
            # '\e[1L': Insert a line above the cursor.
            # '\e[A':  Move cursor up a line.
            if (@scroll > 0)
              @scroll -= 1

              print_line @scroll + 1

              if @y < 2
                print "\e[L"
              else
                print "\e[A"
                @y -= 1
              end

              print_line @scroll
              status_line
            end
      when "g"
        # Go to top.
        if @scroll != 0
          @scroll = 0
          redraw
        end

        # Go to bottom.
      when "G"
        if @scroll != @list_total
          @scroll = @list_total
          redraw

        end
        # Show hidden files.
      when "."
        # TODO what to do here
        @match_hidden = true
        redraw true
        # Search.
      when "/"
        cmd_line "/", "search"

        # If the search came up empty, redraw the current dir.
        if @list.empty?
          @list = @cur_list
          @list_total = @list.size - 1
          redraw
          @search = false
        else
          @search = true
        end

        # spawn a shell TODO

        # Mark files for operation.
      when "y", "m", "d", "s", "b"
        mark @scroll, key

      when "Y", "M", "D", "S", "B"
        mark -1, key

        # Do the file operation.
      when "p"
        if @marked_files.compact.size > 0
          # check write access in this dir TODO

          clear_screen
          reset_terminal

          system("stty echo")
          `#{@file_program} #{@marked_files.compact} .`
          system("stty -echo")

          marked_files_clear

          setup_terminal
          redraw true
        end # if

      when "c"
        # Clear all marked files.
        if @marked_files.compact.size > 0
          marked_files_clear
          redraw
        end

        # TODO many other keys, do after this program runs
      when "q"
        # TODO save file
        exit
      end
    end

    def main(argv)
      Signal::INT.trap do
        reset_terminal
        exit
      end
      at_exit{ reset_terminal }
      get_os
      get_term_size
      # get_w3m_path
      setup_options
      setup_terminal
      @@log.info "before redraw"
      redraw true
      @@log.info "after  redraw"

      # Vintage infinite loop.
      loop do
        reply = get_char
        @@log.debug "char: #{reply}"
        handle_key(reply) if reply
        # read "${read_flags[@]}" -srn 1 && key "$REPLY"

        # Exit if there is no longer a terminal attached.
        # [[ -t 1 ]] || exit 1
      end
    end
  end # class
end # module

include Fff
f = Filer.new
f.main(ARGV)
