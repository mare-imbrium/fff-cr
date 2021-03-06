# ----------------------------------------------------------------------------- #
#         File: fff.cr
#  Description: port of fff from bash
#             : freakin fast filer/file manager.
#       Author: j kepler  http://github.com/mare-imbrium/canis/
#         Date: 2019-05-05
#      License: MIT
#  Last update: 2019-05-27 12:08
# ----------------------------------------------------------------------------- #
# port of fff (bash)
## TODO:
# - 2019-05-15 - screen should have WINCH with a block

require "logger"
require "file_utils"
require "./keyhandler"
require "./screen"
require "./colorparser"
require "./directory"
require "./selection"

module Fff
  VERSION = "0.3.0"
  REVERSE = "\e[7m"

  class Filer

    @@log = Logger.new(io: File.new(File.expand_path("~/tmp/fff.log"), "w"))
    @@log.level = Logger::DEBUG
    @@log.info "========== fff    started ================= ----------"


    def initialize
      @max_items       = 0
      @screen          = Screen.new
      # @marked_dir = Dir.current
      @max_items       = @screen.max_items
      @cp              = Colorparser.new
      @sel             = Selection.new
      @list            = [] of String
      @cur_list        = [] of String
      @scroll          = 0
      @list_total      = 0
      @mark_dir        = ""
      @opener          = "open"
      @file_program    = ""   # uses external programs for move and copy and link
      @operation       = ""
      @file_flags      = "bIL"
      @file_pre        = ""
      @file_post       = ""
      @mark_pre        = nil
      @mark_post       = nil
      @fff_trash_command   = nil
      @fff_trash       = ""
      @previous_index  = 0
      @find_previous   = false
      @match_hidden    = false
      @oldpwd          = ""
      @y               = 0
      @long_listing    = true
      @empty           = false

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
        @fff_trash_command = ENV["FFF_TRASH_CMD"]? || "rmtrash"
        # puts "keys: #{ENV.keys.join("\n")}"
        # we will be moving to some dir, not using trash
      when "haiku"
        # XXX UNTESTED
        @opener = "open"
        # set trash command and dir
        @@log.debug "Haiku"
        @fff_trash_command = ENV["FFF_TRASH_CMD"]? || "trash"
      else
        # XXX UNTESTED
        @@log.debug "Else shouldn't linux be taken care of ??"
        @@log.debug ostype
      end
    end



    # NOTE: we can scrap setup_options

    # Some options require some setup.
    # This function is called once on open to parse
    # select options so the operation isn't repeated
    # multiple times in the code.
    def setup_options
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

    # Get a file's mime_type.
    def get_mime_type(file)
      flags = @file_flags || "biL"
      mime_type=`file "-#{flags}" #{file}`
      mime_type
    end

    # Status_line to print when files are marked for operation.
    def status_line(filename=nil)

      # in fff, file_program was an array with the command and params
      #  which was displayed with '*' and executed with '@' naturally.
      mark_ui = "[#{@sel.size}] selected (#{@file_program}) [p] ->"

      # Escape the directory string.
      # Remove all non-printable characters.
      # @pwd_escaped = "${PWD//[^[:print:]]/^[}"
      pwd_escaped = Dir.current.gsub(/[^[:print:]]/, "?")

      ui = @sel.size == 0 ? "" : mark_ui

      fname = filename || pwd_escaped

      color = ENV["FFF_COL2"]? || "1"

      # FIXME shows 1/1 if empty
      text = @empty ? "#{ui} #{fname}" : "(#{@scroll+1}/#{@list_total+1}) #{ui} #{fname}"
      @screen.status_line(color, text)
    end

    # read the current directory and populate `@list`
    def read_dir
      @list = Directory.read_dir @match_hidden

      # @list.push "empty" if @list.empty?
      @empty = @list.empty?

      # calculate some internal variables
      @list_total = @list.size - 1
      @list_total = 0 if @list_total < 0

      # use as backup if no search results
      @cur_list = @list

      # Find the position of the child directory in the
      # parent directory list. TODO outside
      index = @list.index(@oldpwd)
      if index
        @previous_index = index + 1
      end
    end


    # Format the list item and print it.
    # Index is the offset in the @list array
    def print_line(index)
      file = @list[index]?
        # If the dir item doesn't exist, end here.
        return unless file

      format, suffix = @cp.color_for(file)

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
      # mf = @marked_files[index]? || "null"
      if @sel.marked? file
        @mark_pre ||= ""
        @mark_post ||= "*"
        suffix = @mark_post
        color = ENV["FFF_COL3"]? || "1"
        format = "\e[3#{color}m#{@mark_pre}"
      end

      # Escape the directory string.
      # Remove all non-printable characters.
      file_name = File.basename(file)
      if @long_listing
        details = Directory.format_long_list(file_name, format)
        # str = "%s %8s %s" % details
        # TODO: 2019-05-27 - color size and date based on value
        file_name = file_name.gsub(/[^[:print:]]/, "?")
        printf("\r%s%s\e[m\r", \
               "#{@file_pre}", \
               "#{details}#{suffix}#{@file_post}")
      else
        file_name = file_name.gsub(/[^[:print:]]/, "?")
        printf("\r%s%s\e[m\r", \
               "#{@file_pre}#{format}", \
               "#{file_name}#{suffix}#{@file_post}")
      end
    end


    # Print the max directory items that fit in the scroll area.
    def draw_dir

      if @empty
        printf("\r#{REVERSE}%s\e[m\r", "empty")
        return
      end

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

      # Reset cursor position.
      @screen.reset_cursor_position
      i = scroll_start
      while i < scroll_end
        print("\n") if i > scroll_start
        print_line(i)
        i += 1
      end


      # Move the cursor to its new position if it changed.
      printf("\e[%sH", scroll_new_pos)
      @y = scroll_new_pos
    end

    # Redraw the current window.
    # If 'true' is passed, re-fetch the directory list.
    def redraw(full = false)
      if full
        read_dir
        @scroll = 0
      end

      @screen.clear_screen
      draw_dir
      status_line
    end

    # Clear marked files.
    def marked_files_clear
      @sel.clear
    end

    # mark a file for delete/move/copy.
    # index is index in list array
    # operation is delete, copy, move
    def mark(index, operation)
      # Mark file for operation.
      # If an item is marked in a second directory,
      # clear the marked files.

      # Don't allow the user to mark the empty directory list item.
      return if @empty

      if index == -1 # -1 means "all"
        marked_files_clear
        if @sel.size != @list.size
          @sel.mark @list
        end

        redraw
      else
        file = @list[index]
        @sel.toggle(file)

        # Clear line before changing it.
        @screen.clear_line
        print_line index
      end
      @operation = operation

      # Find the program to use.
      @file_program = case operation
                      when /[yY]/
                        "copy "
                      when /[mM]/
                        "move "
                      when /[sS]/
                        "ln -s"
                        # These are 'fff' functions.
                      when /[dD]/
                        :trash
                      when /[bB]/
                        "bulk_rename"
                      else
                        ""
                      end
      @@log.debug "fileprogram is: #{@file_program}, #{@sel.size}"

      status_line
    end


    def trash(files)
      tf = @screen.confirm "trash [#{@sel.size}] items? [y/n]: "

      return unless tf

      if @fff_trash_command
        # from conflicting with commands named "trash".
        # command "$FFF_TRASH_CMD" "${@:1:$#-1}"
        # last is dot so we reject it
        @@log.debug "trash: #{@fff_trash_command} :: #{files}"
        file_as_string = files.join(" ")
        # TODO need to Shellwords this
        system("#{@fff_trash_command} #{file_as_string}")

      else
        # this is for haiku UNTESTED
        if @fff_trash != "" && File.directory?(@fff_trash)
          begin
            FileUtils.mv files[0..-2], @fff_trash
          rescue e: Exception
            @@log.debug " MOVE FAILED #{@fff_trash}"
            cmd_line "Move failed."
          end

          # Go back to where we were.
          # cd "$OLDPWD" ||:
        end
      end
    end

    # open a file or directory.
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
          @screen.clear_screen
          @screen.reset_terminal
          # "${VISUAL:-${EDITOR:-vi}}" "$1"
          # ed = ENV["VISUAL"]? || ENV["EDITOR"]? || "vi"
          ed = ENV["MANPAGER"]? || ENV["PAGER"]? || "less"
          system("#{ed} #{file}")
          @screen.setup_terminal
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


    # process pressed key
    def handle_key(key)
      # @@log.debug "inside handle_key with #{key}"
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
            # print "\e[L"
            @screen.insert_line_above
          else
            @screen.move_cursor_up
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

      when "SPACE"
        t = @scroll + @max_items
        if @scroll == @list_total
          @scroll = 0
          redraw
        elsif t <= @list_total
          @scroll += @max_items
          redraw
        else
          @scroll = @list_total
          redraw
        end
        # Show hidden files.
      when "."
        @match_hidden = !@match_hidden
        redraw true

        # Search.
      when "/"
        incsearch

        # If the search came up empty, redraw the current dir.
        if @list.empty?
          cmd_line "No results."
          @list = @cur_list
          @list_total = @list.size - 1
          redraw
          @search = false
        else
          @search = true
        end

        # the non-inc search
      when "?"
        reply = cmd_line "/" #, "search"

        @list = Dir.glob(pwd + "/*#{reply}*")
        @list_total = @list.size - 1
        @scroll = 0
        redraw
        @screen.post_cmd_line


        # If the search came up empty, redraw the current dir.
        if @list.empty?
          cmd_line "No results."
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

        # Do the file operation. PASTE paste
      when "p"
        if @sel.size > 0
          # check write access in this dir TODO

          # clear_screen
          # @screen.reset_terminal

          system("stty echo")
          # what abuot escaping the files Shellwords ??? TODO FIXME
          @@log.debug "PASTE: #{@file_program}: #{@sel.marked_files}"
          files = @sel.marked_files
          case @operation
          when /[yY]/
            FileUtils.cp(files, ".")
          when /[mM]/
            FileUtils.mv(files, ".")
          when /[sS]/
            FileUtils.ln_s(files, ".")
            # These are 'fff' functions.
          when /[dD]/
            trash files
          when /[bB]/
            "bulk_rename" # NOT IMPLEMENTED
          else
            ""
          end
          system("stty -echo")

          marked_files_clear

          @screen.setup_terminal
          redraw true
        end # if

      when "c"
        # Clear all marked files.
        if @sel.size > 0
          marked_files_clear
          redraw
        end

        # TODO many other keys, do after this program runs
      when "q"
        # TODO save file
        exit

        # these are bookmarks for directories. Go to bookmark
      when /[1-9]/
        fave = ENV["FFF_FAV#{key}"]?
          open fave if fave

        # goto previous dir
      when "-"
        open @oldpwd if @oldpwd

        # goto home dir
      when "~"
        open ENV["HOME"] if ENV["HOME"]?

          # Ask which dir to go to
      when ":"
        dir = cmd_line "Goto dir:"
        return unless dir
        dir = File.expand_path(dir)
        open dir if File.directory?(dir)

        # create a file
        when "f"
          file = cmd_line "File to create: "
          # check if exists and writable
          return unless file
          return if File.exists? file
          # return unless File.writable? file
          @@log.debug "creating file: #{file}"
          FileUtils.touch file
          redraw true

          # create a dir
        when "n"
          dir = cmd_line "Mkdir: "
          return unless dir
          return if File.exists? dir
          @@log.debug "creating dir: #{dir}"
          FileUtils.mkdir_p dir
          redraw true


          # rename a file
        when "r"
          old = @list[@scroll]
          return unless old
          return unless File.exists? old

          newname = cmd_line "Rename #{@list[@scroll]}: "

          return unless newname
          return if newname == ""
          return unless File.writable? newname

          File.rename old, newname
          redraw true

          # edit a file
        when "e"
          file = @list[@scroll]
          return unless file
          return unless File.exists? file

          ed = ENV["VISUAL"]? || ENV["EDITOR"]? || "vi"
          system("#{ed} #{file}")
          @screen.setup_terminal
          redraw
        when "v"
          @long_listing = !@long_listing
          redraw
        end
    end


    # Incremental search (as you type)
    def incsearch
      buff = ""
      pwd = Dir.current

      @screen.save_cursor_position
      @screen.move_to_bottom
      @screen.unhide_cursor


      loop do
        printf "\r\e[K/#{buff}"
        ch = KeyHandler.get_char
        break if ch == "ESCAPE"
        return unless ch
        if ch == "ENTER"
          # if only one result and it's a directory, then enter should open it.
          if @list_total == 0 && File.directory?(@list[0])

            @screen.hide_cursor
            open @list.first

            @search_end_early = true
            return
          end

          # come out of search and let user navigate
          break
        end
        if ch == "BACKSPACE"
          buff = buff[0..-2]

          # only append alphanum characters and dot
        elsif ch.size == 1 && ch =~ /[A-Za-z0-9\.]/
          buff += ch
        else
          # ignore other keys including arrow etc
          next
        end

        entries = Dir.glob(pwd + "/*#{buff}*") #, match_hidden: false)
        @list = entries
        @list_total = @list.size - 1
        @scroll = 0
        redraw

        # '\e[%sH':  Move cursor back to cmd-line.
        # '\e[?25h': Unhide the cursor.
        # printf "\e[%sH\e[?25h", @lines
        @screen.move_to_bottom
        @screen.unhide_cursor
      end

      # '\e[2K':   Clear the entire cmd_line on finish.
      # '\e[?25l': Hide the cursor.
      # '\e8':     Restore cursor position.
      printf "\e[2K\e[?25l\e8"
    end

    def cmd_line(prompt)
      @screen.cmd_line prompt
    end

    def main(argv)
      Signal::INT.trap do
        @screen.reset_terminal
        exit
      end

      at_exit{ @screen.reset_terminal }

      # Trap the window resize signal (handle window resize events).
      # trap 'get_term_size; redraw' WINCH
      Signal::WINCH.trap do
        @screen.get_term_size
        @max_items = @screen.max_items
        redraw
      end


      # get_ls_colors
      @cp.get_ls_colors
      get_os
      # @screen.get_term_size
      # get_w3m_path
      setup_options
      @screen.setup_terminal
      redraw true

      # Vintage infinite loop.
      loop do
        reply = KeyHandler.get_char
        handle_key(reply) if reply

        # Exit if there is no longer a terminal attached.
        # [[ -t 1 ]] || exit 1
        # NOT SURE:
        # exit(1) unless STDOUT.isatty
      end
    end
  end # class
end # module

include Fff
f = Filer.new
f.main(ARGV)
