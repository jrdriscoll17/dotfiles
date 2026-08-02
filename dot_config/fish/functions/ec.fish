function ec --description 'Open file(s) in a new Emacs GUI frame via the daemon'
    # -c new graphical frame, -n don't block the shell,
    # -a "" start a daemon if one isn't running yet.
    emacsclient -c -n -a "" $argv
end
