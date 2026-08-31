function copy --description "Copy standard input to the terminal clipboard through OSC 52"
  printf '\e]52;c;'
  base64 --wrap=0
  printf '\a'
end
