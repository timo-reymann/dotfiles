# bash completion for pack                                 -*- shell-script -*-

__pack_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__pack_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__pack_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__pack_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__pack_handle_go_custom_completion()
{
    __pack_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly pack allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __pack_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __pack_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __pack_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __pack_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __pack_debug "${FUNCNAME[0]}: the completions are: ${out[*]}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __pack_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __pack_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __pack_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out[*]}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __pack_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subDir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out[0]}")
        if [ -n "$subdir" ]; then
            __pack_debug "Listing directories in $subdir"
            __pack_handle_subdirs_in_dir_flag "$subdir"
        else
            __pack_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out[*]}" -- "$cur")
    fi
}

__pack_handle_reply()
{
    __pack_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __pack_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __pack_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __pack_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
		if declare -F __pack_custom_func >/dev/null; then
			# try command name qualified custom func
			__pack_custom_func
		else
			# otherwise fall back to unqualified for compatibility
			declare -F __custom_func >/dev/null && __custom_func
		fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__pack_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__pack_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__pack_handle_flag()
{
    __pack_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __pack_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __pack_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __pack_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __pack_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __pack_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__pack_handle_noun()
{
    __pack_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __pack_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __pack_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__pack_handle_command()
{
    __pack_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_pack_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __pack_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__pack_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __pack_handle_reply
        return
    fi
    __pack_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __pack_handle_flag
    elif __pack_contains_word "${words[c]}" "${commands[@]}"; then
        __pack_handle_command
    elif [[ $c -eq 0 ]]; then
        __pack_handle_command
    elif __pack_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __pack_handle_command
        else
            __pack_handle_noun
        fi
    else
        __pack_handle_noun
    fi
    __pack_handle_word
}

_pack_build()
{
    last_command="pack_build"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--builder=")
    two_word_flags+=("--builder")
    two_word_flags+=("-B")
    local_nonpersistent_flags+=("--builder")
    local_nonpersistent_flags+=("--builder=")
    local_nonpersistent_flags+=("-B")
    flags+=("--buildpack=")
    two_word_flags+=("--buildpack")
    two_word_flags+=("-b")
    local_nonpersistent_flags+=("--buildpack")
    local_nonpersistent_flags+=("--buildpack=")
    local_nonpersistent_flags+=("-b")
    flags+=("--buildpack-registry=")
    two_word_flags+=("--buildpack-registry")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--buildpack-registry")
    local_nonpersistent_flags+=("--buildpack-registry=")
    local_nonpersistent_flags+=("-r")
    flags+=("--cache-image=")
    two_word_flags+=("--cache-image")
    local_nonpersistent_flags+=("--cache-image")
    local_nonpersistent_flags+=("--cache-image=")
    flags+=("--clear-cache")
    local_nonpersistent_flags+=("--clear-cache")
    flags+=("--default-process=")
    two_word_flags+=("--default-process")
    two_word_flags+=("-D")
    local_nonpersistent_flags+=("--default-process")
    local_nonpersistent_flags+=("--default-process=")
    local_nonpersistent_flags+=("-D")
    flags+=("--descriptor=")
    two_word_flags+=("--descriptor")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--descriptor")
    local_nonpersistent_flags+=("--descriptor=")
    local_nonpersistent_flags+=("-d")
    flags+=("--docker-host=")
    two_word_flags+=("--docker-host")
    local_nonpersistent_flags+=("--docker-host")
    local_nonpersistent_flags+=("--docker-host=")
    flags+=("--env=")
    two_word_flags+=("--env")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--env")
    local_nonpersistent_flags+=("--env=")
    local_nonpersistent_flags+=("-e")
    flags+=("--env-file=")
    two_word_flags+=("--env-file")
    local_nonpersistent_flags+=("--env-file")
    local_nonpersistent_flags+=("--env-file=")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--lifecycle-image=")
    two_word_flags+=("--lifecycle-image")
    local_nonpersistent_flags+=("--lifecycle-image")
    local_nonpersistent_flags+=("--lifecycle-image=")
    flags+=("--network=")
    two_word_flags+=("--network")
    local_nonpersistent_flags+=("--network")
    local_nonpersistent_flags+=("--network=")
    flags+=("--path=")
    two_word_flags+=("--path")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    local_nonpersistent_flags+=("-p")
    flags+=("--publish")
    local_nonpersistent_flags+=("--publish")
    flags+=("--pull-policy=")
    two_word_flags+=("--pull-policy")
    local_nonpersistent_flags+=("--pull-policy")
    local_nonpersistent_flags+=("--pull-policy=")
    flags+=("--run-image=")
    two_word_flags+=("--run-image")
    local_nonpersistent_flags+=("--run-image")
    local_nonpersistent_flags+=("--run-image=")
    flags+=("--tag=")
    two_word_flags+=("--tag")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--tag")
    local_nonpersistent_flags+=("--tag=")
    local_nonpersistent_flags+=("-t")
    flags+=("--trust-builder")
    local_nonpersistent_flags+=("--trust-builder")
    flags+=("--volume=")
    two_word_flags+=("--volume")
    local_nonpersistent_flags+=("--volume")
    local_nonpersistent_flags+=("--volume=")
    flags+=("--workspace=")
    two_word_flags+=("--workspace")
    local_nonpersistent_flags+=("--workspace")
    local_nonpersistent_flags+=("--workspace=")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_builder_create()
{
    last_command="pack_builder_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--config")
    local_nonpersistent_flags+=("--config=")
    local_nonpersistent_flags+=("-c")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--publish")
    local_nonpersistent_flags+=("--publish")
    flags+=("--pull-policy=")
    two_word_flags+=("--pull-policy")
    local_nonpersistent_flags+=("--pull-policy")
    local_nonpersistent_flags+=("--pull-policy=")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_builder_inspect()
{
    last_command="pack_builder_inspect"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--depth=")
    two_word_flags+=("--depth")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--depth")
    local_nonpersistent_flags+=("--depth=")
    local_nonpersistent_flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_builder_suggest()
{
    last_command="pack_builder_suggest"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_builder()
{
    last_command="pack_builder"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("inspect")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("inspect-builder")
        aliashash["inspect-builder"]="inspect"
    fi
    commands+=("suggest")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_buildpack_inspect()
{
    last_command="pack_buildpack_inspect"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--depth=")
    two_word_flags+=("--depth")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--depth")
    local_nonpersistent_flags+=("--depth=")
    local_nonpersistent_flags+=("-d")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--registry=")
    two_word_flags+=("--registry")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--registry")
    local_nonpersistent_flags+=("--registry=")
    local_nonpersistent_flags+=("-r")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_buildpack_package()
{
    last_command="pack_buildpack_package"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--buildpack-registry=")
    two_word_flags+=("--buildpack-registry")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--buildpack-registry")
    local_nonpersistent_flags+=("--buildpack-registry=")
    local_nonpersistent_flags+=("-r")
    flags+=("--config=")
    two_word_flags+=("--config")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--config")
    local_nonpersistent_flags+=("--config=")
    local_nonpersistent_flags+=("-c")
    flags+=("--format=")
    two_word_flags+=("--format")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    local_nonpersistent_flags+=("-f")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--path=")
    two_word_flags+=("--path")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    local_nonpersistent_flags+=("-p")
    flags+=("--publish")
    local_nonpersistent_flags+=("--publish")
    flags+=("--pull-policy=")
    two_word_flags+=("--pull-policy")
    local_nonpersistent_flags+=("--pull-policy")
    local_nonpersistent_flags+=("--pull-policy=")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_buildpack_new()
{
    last_command="pack_buildpack_new"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--api=")
    two_word_flags+=("--api")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--api")
    local_nonpersistent_flags+=("--api=")
    local_nonpersistent_flags+=("-a")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--path=")
    two_word_flags+=("--path")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    local_nonpersistent_flags+=("-p")
    flags+=("--stacks=")
    two_word_flags+=("--stacks")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--stacks")
    local_nonpersistent_flags+=("--stacks=")
    local_nonpersistent_flags+=("-s")
    flags+=("--version=")
    two_word_flags+=("--version")
    two_word_flags+=("-V")
    local_nonpersistent_flags+=("--version")
    local_nonpersistent_flags+=("--version=")
    local_nonpersistent_flags+=("-V")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_buildpack_pull()
{
    last_command="pack_buildpack_pull"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--buildpack-registry=")
    two_word_flags+=("--buildpack-registry")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--buildpack-registry")
    local_nonpersistent_flags+=("--buildpack-registry=")
    local_nonpersistent_flags+=("-r")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_buildpack_register()
{
    last_command="pack_buildpack_register"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--buildpack-registry=")
    two_word_flags+=("--buildpack-registry")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--buildpack-registry")
    local_nonpersistent_flags+=("--buildpack-registry=")
    local_nonpersistent_flags+=("-r")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_buildpack_yank()
{
    last_command="pack_buildpack_yank"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--buildpack-registry=")
    two_word_flags+=("--buildpack-registry")
    two_word_flags+=("-r")
    local_nonpersistent_flags+=("--buildpack-registry")
    local_nonpersistent_flags+=("--buildpack-registry=")
    local_nonpersistent_flags+=("-r")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--undo")
    flags+=("-u")
    local_nonpersistent_flags+=("--undo")
    local_nonpersistent_flags+=("-u")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_buildpack()
{
    last_command="pack_buildpack"

    command_aliases=()

    commands=()
    commands+=("inspect")
    commands+=("package")
    commands+=("new")
    commands+=("pull")
    commands+=("register")
    commands+=("yank")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_default-builder()
{
    last_command="pack_config_default-builder"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--unset")
    flags+=("-u")
    local_nonpersistent_flags+=("--unset")
    local_nonpersistent_flags+=("-u")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_experimental()
{
    last_command="pack_config_experimental"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_pull-policy()
{
    last_command="pack_config_pull-policy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--unset")
    flags+=("-u")
    local_nonpersistent_flags+=("--unset")
    local_nonpersistent_flags+=("-u")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_registries_list()
{
    last_command="pack_config_registries_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_registries_add()
{
    last_command="pack_config_registries_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--default")
    local_nonpersistent_flags+=("--default")
    flags+=("--type=")
    two_word_flags+=("--type")
    local_nonpersistent_flags+=("--type")
    local_nonpersistent_flags+=("--type=")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_registries_remove()
{
    last_command="pack_config_registries_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_registries_default()
{
    last_command="pack_config_registries_default"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--unset")
    flags+=("-u")
    local_nonpersistent_flags+=("--unset")
    local_nonpersistent_flags+=("-u")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_registries()
{
    last_command="pack_config_registries"

    command_aliases=()

    commands=()
    commands+=("list")
    commands+=("add")
    commands+=("remove")
    commands+=("default")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_run-image-mirrors_list()
{
    last_command="pack_config_run-image-mirrors_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_run-image-mirrors_add()
{
    last_command="pack_config_run-image-mirrors_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--mirror=")
    two_word_flags+=("--mirror")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--mirror")
    local_nonpersistent_flags+=("--mirror=")
    local_nonpersistent_flags+=("-m")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_run-image-mirrors_remove()
{
    last_command="pack_config_run-image-mirrors_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--mirror=")
    two_word_flags+=("--mirror")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--mirror")
    local_nonpersistent_flags+=("--mirror=")
    local_nonpersistent_flags+=("-m")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_run-image-mirrors()
{
    last_command="pack_config_run-image-mirrors"

    command_aliases=()

    commands=()
    commands+=("list")
    commands+=("add")
    commands+=("remove")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_trusted-builders_list()
{
    last_command="pack_config_trusted-builders_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_trusted-builders_add()
{
    last_command="pack_config_trusted-builders_add"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_trusted-builders_remove()
{
    last_command="pack_config_trusted-builders_remove"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_trusted-builders()
{
    last_command="pack_config_trusted-builders"

    command_aliases=()

    commands=()
    commands+=("list")
    commands+=("add")
    commands+=("remove")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config_lifecycle-image()
{
    last_command="pack_config_lifecycle-image"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--unset")
    flags+=("-u")
    local_nonpersistent_flags+=("--unset")
    local_nonpersistent_flags+=("-u")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_config()
{
    last_command="pack_config"

    command_aliases=()

    commands=()
    commands+=("default-builder")
    commands+=("experimental")
    commands+=("pull-policy")
    commands+=("registries")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("registreis")
        aliashash["registreis"]="registries"
        command_aliases+=("registry")
        aliashash["registry"]="registries"
    fi
    commands+=("run-image-mirrors")
    commands+=("trusted-builders")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("trust-builder")
        aliashash["trust-builder"]="trusted-builders"
        command_aliases+=("trust-builders")
        aliashash["trust-builders"]="trusted-builders"
        command_aliases+=("trusted-builder")
        aliashash["trusted-builder"]="trusted-builders"
    fi
    commands+=("lifecycle-image")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_inspect()
{
    last_command="pack_inspect"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--bom")
    local_nonpersistent_flags+=("--bom")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_stack_suggest()
{
    last_command="pack_stack_suggest"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_stack()
{
    last_command="pack_stack"

    command_aliases=()

    commands=()
    commands+=("suggest")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_rebase()
{
    last_command="pack_rebase"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--publish")
    local_nonpersistent_flags+=("--publish")
    flags+=("--pull-policy=")
    two_word_flags+=("--pull-policy")
    local_nonpersistent_flags+=("--pull-policy")
    local_nonpersistent_flags+=("--pull-policy=")
    flags+=("--run-image=")
    two_word_flags+=("--run-image")
    local_nonpersistent_flags+=("--run-image")
    local_nonpersistent_flags+=("--run-image=")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_completion()
{
    last_command="pack_completion"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--shell=")
    two_word_flags+=("--shell")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--shell")
    local_nonpersistent_flags+=("--shell=")
    local_nonpersistent_flags+=("-s")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_report()
{
    last_command="pack_report"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--explicit")
    flags+=("-e")
    local_nonpersistent_flags+=("--explicit")
    local_nonpersistent_flags+=("-e")
    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_version()
{
    last_command="pack_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_pack_help()
{
    last_command="pack_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_pack_root_command()
{
    last_command="pack"

    command_aliases=()

    commands=()
    commands+=("build")
    commands+=("builder")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("builders")
        aliashash["builders"]="builder"
    fi
    commands+=("buildpack")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("buildpacks")
        aliashash["buildpacks"]="buildpack"
    fi
    commands+=("config")
    commands+=("inspect")
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        command_aliases+=("inspect-image")
        aliashash["inspect-image"]="inspect"
    fi
    commands+=("stack")
    commands+=("rebase")
    commands+=("completion")
    commands+=("report")
    commands+=("version")
    commands+=("help")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--no-color")
    flags+=("--quiet")
    flags+=("-q")
    flags+=("--timestamps")
    flags+=("--verbose")
    flags+=("-v")
    flags+=("--version")
    local_nonpersistent_flags+=("--version")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_pack()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __pack_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("pack")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function
    local last_command
    local nouns=()

    __pack_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_pack pack
else
    complete -o default -o nospace -F __start_pack pack
fi

# ex: ts=4 sw=4 et filetype=sh
