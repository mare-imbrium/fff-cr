# Handles keystrokes from terminal returning a String representation
#
# = Usage
# key = KeyHandler.get_char
#
class KeyHandler
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

  def self.get_char : String
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
end # class
