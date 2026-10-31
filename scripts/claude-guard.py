#!/usr/bin/env python3
# Claude Code PreToolUse hook for Bash: blocks Git commands that skip the
# repository's Git hooks (--no-verify or an abbreviation of it, -n on git
# commit, or pointing core.hooksPath elsewhere through -c, --config-env,
# GIT_CONFIG_* or git config), so AGENTS.md#git-workflow stays enforced.
# Configured in .claude/settings.json. Python because the repo has no Node,
# and macOS ships python3 with the Xcode command line tools.
import json
import re
import sys

command = (json.load(sys.stdin).get("tool_input") or {}).get("command") or ""

TOKEN = re.compile(
    r"""(&&|\|\||[;|&\n])|(?:'[^']*'|"(?:\\.|[^"\\])*"|[^\s;&|'"])+"""
)
QUOTED = re.compile(r"""'([^']*)'|"((?:\\.|[^"\\])*)\"""")


def unquote(word):
    def strip(match):
        single, double = match.group(1), match.group(2)
        return single if single is not None else re.sub(r"\\(.)", r"\1", double)

    return QUOTED.sub(strip, word)


def simple_commands(text):
    """Splits a command into simple commands of words, with shell quotes removed."""
    commands = [[]]
    for match in TOKEN.finditer(text):
        if match.group(1):
            commands.append([])
        else:
            commands[-1].append(unquote(match.group(0)))
    return commands


# Global git options that take the next word as their value.
GIT_VALUE_OPTIONS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}
# git commit options that take the next word, or the rest of a short
# option cluster, as their value.
COMMIT_SHORT_VALUE_OPTIONS = "mFCcSt"
COMMIT_LONG_VALUE_OPTIONS = {
    "--message", "--file", "--reuse-message", "--reedit-message", "--template",
    "--author", "--date", "--fixup", "--squash", "--trailer",
}


def program(word):
    """A command word with any subshell or substitution opener removed."""
    return word.lstrip("($`{")


def is_no_verify(arg):
    """--no-verify, or an abbreviation of it that git still accepts."""
    return len(arg) >= len("--no-ver") and "--no-verify".startswith(arg)


def sets_hooks_path(option, value):
    """A global option that overrides core.hooksPath for one command."""
    if option == "-c" or option == "--config-env":
        return bool(re.match(r"core\.hookspath=", value, re.I))
    return bool(re.match(r"(-c|--config-env=)core\.hookspath=", option, re.I))


def changes_hooks_path(args):
    """`git config` pointing core.hooksPath anywhere but .githooks, or unsetting it."""
    key = next((i for i, a in enumerate(args) if a.lower() == "core.hookspath"), None)
    if key is None:
        return False
    if any(a in ("--unset", "--unset-all", "unset") for a in args[:key]):
        return True
    if any(a in ("--get", "--get-all", "get") for a in args[:key]):
        return False
    rest = [a for a in args[key + 1:] if not a.startswith("-")]
    return bool(rest) and rest[0] != ".githooks"


def skips_hooks(words):
    start = next((i for i, w in enumerate(words) if re.search(r"(^|/)git$", program(w))), -1)
    if start == -1:
        return shell_command_skips_hooks(words)

    index = start + 1
    while index < len(words) and words[index].startswith("-"):
        option = words[index]
        nxt = words[index + 1] if index + 1 < len(words) else ""
        if sets_hooks_path(option, nxt):
            return True
        if option in GIT_VALUE_OPTIONS:
            index += 1
        index += 1
    subcommand = words[index] if index < len(words) else None
    args = words[index + 1:]
    if subcommand == "config":
        return changes_hooks_path(args)
    if subcommand != "commit":
        return any(map(is_no_verify, args))

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--":
            return False
        if is_no_verify(arg):
            return True
        if arg in COMMIT_LONG_VALUE_OPTIONS:
            i += 1
        elif re.match(r"-[^-]", arg):
            flags = arg[1:]
            for position, flag in enumerate(flags):
                if flag == "n":
                    return True
                if flag in COMMIT_SHORT_VALUE_OPTIONS:
                    if position == len(flags) - 1:
                        i += 1
                    break
        i += 1
    return False


def shell_command_skips_hooks(words):
    """Checks the script of `sh -c`, `bash -lc`, `zsh -c` and the like."""
    if not words or not re.search(r"(^|/)(ba|z)?sh$", program(words[0])):
        return False
    flag = next((i for i, w in enumerate(words) if re.fullmatch(r"-[A-Za-z]*c[A-Za-z]*", w)), None)
    if flag is None or flag + 1 >= len(words):
        return False
    return any(map(skips_hooks, simple_commands(words[flag + 1])))


# Environment configuration git reads for every command, set inline or exported.
ENV_HOOKS_PATH = re.compile(
    r"""GIT_CONFIG_(?:KEY_\d+|PARAMETERS)=['"]*\S*core\.hookspath""", re.I
)


if ENV_HOOKS_PATH.search(command) or any(map(skips_hooks, simple_commands(command))):
    print(
        "Blocked: this Git command skips the repository's Git hooks (--no-verify, "
        "-n on git commit, or a core.hooksPath change), which enforce "
        "AGENTS.md#git-workflow. Run it without that option.",
        file=sys.stderr,
    )
    sys.exit(2)
