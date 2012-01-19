#!/bin/bash

# NA_TODO_EXT Must be set to something to limit text searches
NA_TODO_EXT="txt"
NA_NEXT_TAG="@na"
NA_DONE_TAG="@done"
NA_MAX_DEPTH=4
NA_AUTO_LIST_FOR_DIR=1 # or 0 to disable
NA_AUTO_LIST_IS_RECURSIVE=0

function na() {

  local DKGRAY="\033[1;30m"
  local GREEN="\033[0;32m"
  local DEFAULT="\033[0;39m"
  if [[ $# -eq 0 ]]; then
    # Do an ls to see if there are any matching files
    CHKFILES=$(ls -C1 *.$NA_TODO_EXT 2> /dev/null | wc -l)
    if [ $CHKFILES -ne 0 ]; then
      echo -en $GREEN
      grep -h "$NA_NEXT_TAG" *.$NA_TODO_EXT | grep -v "$NA_DONE_TAG" | awk '{gsub(/(^[ \t]+| '"$NA_NEXT_TAG"')/, "")};1'
      echo "`pwd`" >> ~/.tdlist
      sort -u ~/.tdlist -o ~/.tdlist
      echo -en $DEFAULT
    fi
    return
  else
    if [[ $NA_AUTO_LIST_IS_RECURSIVE -eq 1 ]]; then
      na_prompt_command="na -r"
    else
      na_prompt_command="na"
    fi
    local fnd recurse add
    while [ "$1" ]; do case "$1" in
    --prompt) [[ $(history 1|sed -e "s/^[ ]*[0-9]*[ ]*//") =~ ^((cd|z|j|g|f|pushd|popd|exit)([ ]|$)) ]] && $na_prompt_command; return;;
    -*) local opt=${1:1}; while [ "$opt" ]; do case ${opt:0:1} in
      r) local recurse=1;;
      a) local add=1;;
      h) echo "na [-a 'todo text']
na [-r] [query [additional identifiers]]

options:
-r        recurse 3 directories deep and concatenate all $NA_TODO_EXT files
-a [todo] add a todo to todo.$NA_TODO_EXT in the current dir
-h        show a brief help message" >&2; return;;
      *) fnd+="$1 "; break;; # unknown option detected
    esac; opt="${opt:1}"; done;;
    *) fnd+="$1 ";;
    esac; shift; done
  fi

  if [[ $recurse -eq 1 && $fnd == '' ]]; then # if the only argument is -r
    # echo -en $GREEN
    # find . -name "*.$NA_TODO_EXT" -maxdepth 3 -exec cat {} \;| grep -H '@na' | grep -v '@done' | awk '{gsub(/(^[ \t]+| @na)/, "")};1'
    dirlist=$(find . -name "*.$NA_TODO_EXT" -maxdepth $NA_MAX_DEPTH -exec grep -H "$NA_NEXT_TAG" {} \; | grep -v "$NA_DONE_TAG")
    _na_fix_output "$dirlist"
  elif [[ $add -eq 1 ]]; then # if the argument is -a
    if [[ $fnd != '' ]]; then # if there is text to add as a todo item
      task=$fnd
      /usr/bin/ruby <<SCRIPT
      na = true
      input = "\t- " + "$task" + " $NA_NEXT_TAG"

      inbox_found = false
      output = ''

      if File.exists?('todo.$NA_TODO_EXT')
        File.open('todo.$NA_TODO_EXT','r') do |f|
          while (line = f.gets)
            output += line
            if line =~ /inbox:/i
              output += input + "\n"
              inbox_found = true
            end
          end
        end
      end

      unless inbox_found
        output += "Inbox:\n"
        output += input + "\n"
      end

      todofile = File.new('todo.$NA_TODO_EXT','w')
      todofile.puts output
      todofile.close
SCRIPT
   else # no text given
     echo "Usage: na -a \"text to be added to todo.$NA_TODO_EXT inbox\""
     echo "See `na -h` for help"
     return
   fi
  else
    if [[ -d "${fnd%% *}" ]]; then
      cd "${fnd%% *}" >> /dev/null
      target="`pwd`"
      cd - >> /dev/null
      echo "${target%/}" >> ~/.tdlist
      sort -u ~/.tdlist -o ~/.tdlist
    else
      target=$(ruby <<SCRIPTTIME
      if (File.exists?(File.expand_path('~/.tdlist')))
        query = "$fnd"
        input = File.open(File.expand_path('~/.tdlist'),'r').read
        re = query.gsub(/\s+/,' ').split(" ").join('.*?')
        res = input.scan(/.*?#{re}.*?$/i)
        puts res.uniq.sort[0] unless res.nil? || res.empty?
      end
SCRIPTTIME
)
    fi
      if [[ $recurse -eq 1 ]]; then
        echo -e "$DKGRAY[$target+]:"
        dirlist=$(find "$target" -name "*.$NA_TODO_EXT" -maxdepth $NA_MAX_DEPTH -exec grep -H $NA_NEXT_TAG {} \; | grep -v "$NA_DONE_TAG")
        _na_fix_output "$dirlist"
      else
        CHKFILES=$(ls -C1 $target/*.$NA_TODO_EXT 2> /dev/null | wc -l)
        if [ $CHKFILES -ne 0 ]; then
          echo -e "$DKGRAY[$target]:$GREEN" && grep -h "$NA_NEXT_TAG" "$target"/*.$NA_TODO_EXT | grep -v "$NA_DONE_TAG" | awk '{gsub(/(^[ \t]+| '"$NA_NEXT_TAG"')/, "")};1'
        fi
      fi
  fi
  echo -en $DEFAULT
}

_na_fix_output() {
  local DKGRAY="\033[1;30m"
  local GREEN="\033[0;32m"
  local DEFAULT="\033[0;39m"
  /usr/bin/ruby <<SCRIPTTIME
    input = "$1"
    exit if input.nil? || input == ''
    olddirs = []
    if File.exists?(File.expand_path('~/.tdlist'))
      File.open(File.expand_path('~/.tdlist'),'r') do |f|
        while (line = f.gets)
          olddirs.push(line.strip) unless line =~ /^\s*$/
        end
      end
    end
    input.split("\n").each {|line|
      parts = line.scan(/([\.\/].*?\/)([^\/]+:)(.*)$/)
      exit if parts[0].nil?
      parts = parts[0]
      dirname,filename,task = parts[0],parts[1],parts[2]
      dirparts = dirname.scan(/((\.)|(\/[^\/]+)*\/(.*))\/$/)[0]
      base = dirparts[3].nil? ? '' : dirparts[3] + "->"
      extre = "\.$NA_TODO_EXT"
      puts "$DKGRAY#{base}#{filename.gsub(/#{extre}:$/,'')} $GREEN#{task.gsub(/^[ \t]+/,'').gsub(/ $NA_NEXT_TAG/,'')}"
      olddirs.push(File.expand_path(dirname).gsub(/\/+$/,'').strip)
    }
    print "$DEFAULT"
    tdfile = File.new(File.expand_path('~/.tdlist'),'w')
    tdfile.puts olddirs.uniq.sort.join("\n")
    tdfile.close
SCRIPTTIME
}

if [[ $NA_AUTO_LIST_FOR_DIR -eq 1 ]]; then
  echo $PROMPT_COMMAND | grep -v -q "na --prompt" && PROMPT_COMMAND='eval "na --prompt";'"$PROMPT_COMMAND"
fi
