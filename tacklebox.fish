# Tacklebox: https://github.com/justinmayer/tacklebox

###
# Helper functions
###

function __tacklebox_add_plugin
    set -l plugin "$argv[1]"
    set -l plugin_path "plugins/$plugin"

    for repository in $tacklebox_path[-1..1]
        __tacklebox_prepend_path $repository/$plugin_path fish_function_path
    end
end

function __tacklebox_add_module
    set -l module "$argv[1]"
    set -l module_path "modules/$module"

    for repository in $tacklebox_path[-1..1]
        for module_file in $repository/$module_path/*.fish
            source $module_file
        end
    end
end

function __tacklebox_add_completion
    set -l plugin "$argv[1]"
    set -l completion_path "plugins/$plugin/completions"

    for repository in $tacklebox_path[-1..1]
        __tacklebox_prepend_path $repository/$completion_path fish_complete_path
    end
end

function __tacklebox_source_plugin_load_file
    set -l plugin "$argv[1]"
    set -l load_file_path "plugins/$plugin/$plugin.load"

    for repository in $tacklebox_path[-1..1]
        if test -e $repository/$load_file_path
            source $repository/$load_file_path
        end
    end
end

function __tacklebox_load_theme
    set -l theme "$argv[1]"
    set -l theme_path "themes/$theme"

    for repository in $tacklebox_path[-1..1]
        if test -d $repository/$theme_path
            __tacklebox_load_env_files_in_dir $repository/$theme_path
        end
        __tacklebox_prepend_path $repository/$theme_path fish_function_path
    end
end

function __tacklebox_strip_word --no-scope-shadowing --description '__tacklebox_strip_word word varname'
    set -l word "$argv[1]"
    set -l list "$argv[2]"
    if set -l idx (contains -i -- $word $$list)
        set -e -- {$list}[$idx]
    else
        return 1
    end
end

function __tacklebox_prepend_path --no-scope-shadowing --description \
        'Prepend the given path, if it exists, to the specified path list (defaults to PATH)'
    set -l path "$argv[1]"
    set -l list PATH

    if set -q argv[2]
        set list $argv[2]
    end

    if test -d $path
        # If the path is already in the list, remove it first.
        # Prepending puts it in front, where it belongs
        if set -l idx (contains -i -- $path $$list)
            set -e -- {$list}[$idx]
        end
        #set -- $list $path $$list
        set -p  $argv[2] $path

    end
end

function __tacklebox_append_path --no-scope-shadowing --description \
        'Append the given path, if it exists, to the specified path list (defaults to PATH)'
    set -l path "$argv[1]"
    set -l list PATH
    if set -q argv[2]
        set list $argv[2]
    end

    if test -d $path
        # If the path is already in the list, skip it.
        if not contains -- $path $$list
            set -a $argv[2] $path
        end
    end
end

function __tacklebox_load_env_file --no-scope-shadowing --description \
        'Load and export all values in a env file'
    # Loop through lines of .env file
    set -l retVal 0
    if test -r $argv[1]
        while read line;
            # Strip all comments from lines
            string replace -r '#.*' '' $line | read -l line
            # Skip empty lines
            if test -n $line
                if string match -q "*=*" $line
                    set -l split (string split -m 1 = $line)
                    # Using the following does not work as it does not substitute the path
                    # Setting the PATH with read breaks
                    if test $split[1] != PATH
                        # need to expand $split[2] twice so that any vars stored in the file get expanded
                        set -l content ""
                        for arg in (string split " " $split[2])
                            # See if the argument starts with a "$" and remove it at the same time
                            if set -l varname (string replace -rf '^\$' '' -- $arg)
                                set content (echo -n "$content $$varname") # this expands it first to "$PATH", and then expands _that_, to leave the value of $PATH.
                            else
                                set content (echo -n "$content $arg")
                            end
                        end
                        set -l TMP (string trim $content)
                        set -l TMP2 "/usr/bin/echo -e $TMP"
                        set -l TMP3 (string split ' ' $TMP2)
                        set -l TMP4 ($TMP3)
                        printf "%s" $TMP4 | read -gx $split[1]
                    else
                        # Fish handles PATH specially and must be handled specially
                        # Handle : or ' ' seperation of paths as thats what people expect
                        set -l content ""
                        for arg in (string split " " $split[2])
                            # See if the argument starts with a "$" and remove it at the same time
                            if set -l varname (string replace -rf '^\$' '' -- $arg)
                                set content (echo -n "$content $$varname") # this expands it first to "$PATH", and then expands _that_, to leave the value of $PATH.
                            else
                                set content (echo -n "$content $arg")
                            end
                        end


                        # $PATH is : seperated so split it back to spaces.
                        string trim $content | string join ' ' | string replace -a ':' ' ' | read -l content
                        set -gx PATH (string split ' ' $content)
                    end
                else
                    echo "Invalid line not added to environment: $line"
                    set -l retVal 1
                end
            end
        ; end < $argv[1]
    end
    return $retVal
end

function __tacklebox_unload_env_file --no-scope-shadowing --description \
        'Clears all environment variables loaded in a env file'
    set -l retVal 0
    # Loop through lines of .env file
    if test -r $argv[1]
        while read line;
            # Strip all comments from lines
            string replace -r '#.*' '' $line | read -l line
            # Skip empty lines
            if test -n $line
                # Check that string contains either exactly 1 = or exactly 1 ' '
                if string match -q "*=*" $line
                    set -l split (string split -m 1 = $line)
                    set -e $split[1]
                else
                    echo "Invalid line not removed from environment: $line"
                    set -l retVal 1
                end
            end
        ; end < $argv[1]
    end
    return $retVal
end

function __tacklebox_load_env_files_in_dir --no-scope-shadowing --description \
        'Loads all the .env files in the directory passed in.'
    if test -d $argv[1]
        for env_file in $argv[1]/*.env
            __tacklebox_load_env_file $env_file
        end
    end
end

###
# Configuration
###

# Support Fish 2.x and 3.x data directories, respectively
set -l fish_data_dir $__fish_datadir $__fish_data_dir
# Standardize function path, to be restored later.
set -l user_function_path $fish_function_path
# Ensure the function path is global, not universal
set -g fish_function_path "$fish_data_dir/functions"

# Add all functions
for repository in $tacklebox_path[-1..1]
    __tacklebox_prepend_path $repository/functions fish_function_path
end

# Load Environment - This requires fish 2.3 with the string builtin
for repository in $tacklebox_path[-1..1]
    __tacklebox_load_env_files_in_dir $repository/environment
end

# Add all specified plugins
for plugin in $tacklebox_plugins
    __tacklebox_add_plugin $plugin
    __tacklebox_add_completion $plugin
    __tacklebox_source_plugin_load_file $plugin
end

# Add all specified modules
for module in $tacklebox_modules
    __tacklebox_add_module $module
end

# Load user-specified theme
if test -n "$tacklebox_theme"
    __tacklebox_load_theme $tacklebox_theme
end


# Add back the user and sysconf functions as appropriate
for path in $fish_function_path
    # don't append either system path
    if not contains -- "$path" "$__fish_sysconfdir/functions" "$fish_data_dir/functions"
        __tacklebox_append_path $path user_function_path
    end
end


if __tacklebox_strip_word "$__fish_sysconfdir/functions" user_function_path
    set user_function_path $user_function_path "$__fish_sysconfdir/functions"
end
__tacklebox_strip_word "$fish_data_dir/functions" user_function_path
set -ga fish_function_path $user_function_path "$fish_data_dir/functions"
