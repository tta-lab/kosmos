#!/run/current-system/sw/bin/fish

set --local project_bin /home/neil/go/bin/project

if not test -x "$project_bin"
    echo "Organon project CLI is not installed: $project_bin" >&2
    exit 1
end

set --local selection (
    $project_bin list --json |
        /run/current-system/sw/bin/jq --raw-output '.[] | [.alias, .name, .path] | @tsv' |
        /run/current-system/sw/bin/fzf \
            --delimiter='\t' \
            --with-nth=1,2,3 \
            --prompt='New space> ' \
            --height=100%
)

if test $status -ne 0 -o -z "$selection"
    exit 0
end

set --local fields (string split (printf '\t') -- $selection)
set --local project_alias $fields[1]
set --local project_path $fields[3]

if test -z "$project_alias" -o -z "$project_path" -o not -d "$project_path"
    echo "Invalid Organon project selection" >&2
    exit 1
end

/run/current-system/sw/bin/herdr workspace create \
    --cwd "$project_path" \
    --label "$project_alias" \
    --focus
