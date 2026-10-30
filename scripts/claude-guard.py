#!/usr/bin/env python3
# Claude Code PreToolUse hook for Bash: blocks Git commands that skip the
# repository's Git hooks (--no-verify, -n on git commit, or a -c override
# of core.hooksPath), so AGENTS.md#git-workflow stays enforced. Configured
# in .claude/settings.json. Python because the repo has no Node, and
# macOS ships python3 with the Xcode command line tools.
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


def skips_hooks(words):
    program = next((i for i, w in enumerate(words) if re.search(r"(^|/)git$", w)), -1)
    if program == -1:
        return shell_command_skips_hooks(words)

    index = program + 1
    while index < len(words) and words[index].startswith("-"):
        option = words[index]
        nxt = words[index + 1] if index + 1 < len(words) else ""
        if option == "-c" and re.match(r"core\.hookspath=", nxt, re.I):
            return True
        if option in GIT_VALUE_OPTIONS:
            index += 1
        index += 1
    subcommand = words[index] if index < len(words) else None
    args = words[index + 1:]
    if subcommand != "commit":
        return "--no-verify" in args

    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--":
            return False
        if arg == "--no-verify":
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
    """Checks the script of `sh -c`, `bash -c` or `zsh -c`."""
    if not words or not re.search(r"(^|/)(ba|z)?sh$", words[0]) or "-c" not in words:
        return False
    position = words.index("-c") + 1
    return position < len(words) and any(map(skips_hooks, simple_commands(words[position])))


if any(map(skips_hooks, simple_commands(command))):
    print(
        "Blocked: this Git command skips the repository's Git hooks (--no-verify, "
        "-n on git commit, or a core.hooksPath override), which enforce "
        "AGENTS.md#git-workflow. Run it without that option.",
        file=sys.stderr,
    )
    sys.exit(2)
