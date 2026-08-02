function et --description 'Open file(s) in Emacs in the current terminal (TTY frame)'
    # -t terminal frame, -a "" start a daemon if one isn't running yet.
    emacsclient -t -a "" $argv
end
