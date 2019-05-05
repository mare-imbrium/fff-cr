# ----------------------------------------------------------------------------- #
#         File: fff.cr
#  Description: port of fff from bash
#             : freakin fast filer/file manager.
#       Author: j kepler  http://github.com/mare-imbrium/canis/
#         Date: 2019-05-05
#      License: MIT
#  Last update: 2019-05-05 16:54
# ----------------------------------------------------------------------------- #
# port of fff (bash)
module Fff
  VERSION = "0.1.0"

  class Filer
    def initialize
      @lines = 0
      @max_items = 0
    end

    def get_os
      # ostype = ENV["OSTYPE"]?  # comes nil
      ostype = `uname`
      case ostype
      when /Darwin/
        puts "darwin"
        @opener = "open"
        @file_flags = "bIL"
        puts "ED: #{ENV["EDITOR"]?}"
        puts "PAGER: #{ENV["PAGER"]?}"
        # puts "keys: #{ENV.keys.join("\n")}"
        # we will be moving to some dir, not using trash
      when "haiku"
        @opener = "open"
        # set trash command and dir
        # what the hell is this anyway
        puts "Haiku"
      else
        puts "Else shouldn't linux be taken care of ??"
        puts ostype
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
      printf("\e[?1049h\e[?7l\e[?25l\e[2J\e[1;%sr", @max_items)

      # Hide echoing of user input
      system("stty -echo")
    end

    def reset_terminal
      # Reset the terminal to a useable state (undo all changes).
      # '\e[?7h':   Re-enable line wrapping.
      # '\e[?25h':  Unhide the cursor.
      # '\e[2J':    Clear the terminal.
      # '\e[;r':    Set the scroll region to its default value.
      #             Also sets cursor to (0,0).
      # '\e[?1049l: Restore main screen buffer.
      printf("\e[?7h\e[?25h\e[2J\e[;r\e[?1049l")

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

      printf("\e[%sH\e[9999C\e[1J%b\e[1;%sr", \
             @lines-2, ENV["TMUX"]? && "\e[2J" , @max_items)
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
    match = var.match("\(.*\)%f\(.*\)")
    @file_pre = match.first
    @file_post = match.last
  end

  # Format for marked files.
  var = ENV["FFF_MARK_FORMAT"]?
  if var
    match = var.match("\(.*\)%f\(.*\)")
    @mark_pre = match.first
    @mark_post = match.last
  end

end

def get_term_size
  # Get terminal size ('stty' is POSIX and always available).
  # This can't be done reliably across all bash versions in pure bash.
  @lines, @columns = `stty size`.split(" ")

    # Max list items that fit in the scroll area.
    @max_items = @lines - 3
end

def get_ls_colors
    # Parse the LS_COLORS variable and declare each file type
    # as a separate variable.
    # Format: ':.ext=0;0:*.jpg=0;0;0:*png=0;0;0;0:'
    unless ENV["LS_COLORS"]?
      @fff_ls_colors = 0
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
  mark_ui = "[#{@marked_files}.size] selected (#{@file_program}) [p] ->"

  # Escape the directory string.
  # Remove all non-printable characters.
  # @pwd_escaped = "${PWD//[^[:print:]]/^[}"
  pwd_escaped = Dir.current.gsub(/[^[:print:]]/, "?")

  ui = @marked_files.empty? ? "" : mark_ui

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
           "#{@lines-1}", \
           color, \
           @columns, "", \
           "(#{@scroll+1}/#{@list_total+1})", \
           ui, \
           fname, \
           @lines.to_s
end
  end # class
end # module

include Fff
f = Filer.new
f.get_os
