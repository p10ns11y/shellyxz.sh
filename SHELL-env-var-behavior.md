# Understanding the `$SHELL` Environment Variable

This document explains why `chsh` + `exec` often does **not** update `echo $SHELL`, why a full reboot usually does, and how environment variables actually flow in Unix-like systems.

It is written from the perspective of a user who has just changed their shell and is confused why `$SHELL` still lies.

---

## TL;DR


| Concept                                  | What it represents                                 | Updated by `chsh`? | Updated by `exec zsh`? | Fresh terminal after reboot? |
| ---------------------------------------- | -------------------------------------------------- | ------------------ | ---------------------- | ---------------------------- |
| **passwd shell** (`getent passwd $USER`) | Your configured login shell                        | Yes                | No                     | Yes                          |
| **Current process** (`$0`, `ps -p $$`)   | The binary actually running right now              | No                 | Yes                    | Yes                          |
| `**$SHELL` env var**                     | Usually the value set when this *session* was born | No                 | No (inherits)          | Yes (new session)            |


`**chsh` only updates the database.**  
`**$SHELL` is set at session *birth* by the terminal/login process and then inherited.**  
`**exec` replaces the process but keeps the old environment.**

---

## The Three Different "Shells"

When debugging shell changes, people mix up three different things:

1. **Login shell (from passwd)**
  ```bash
   getent passwd $USER | cut -d: -f7
  ```
   This is what `chsh` changes.
2. **Currently executing process**
  ```bash
   echo $0
   ps -p $$ -o comm=
   echo ${ZSH_VERSION:+zsh} ${BASH_VERSION:+bash}
  ```
3. `**$SHELL` environment variable**
  ```bash
   echo $SHELL
  ```

These three are allowed to disagree, and the system makes no attempt to keep them in sync.

---

## What `chsh` Actually Does

`chsh -s /usr/bin/zsh` performs **one** action:

- Writes the new path into your entry in `/etc/passwd` (or the system user database).

It does **nothing** to:

- Running processes
- Environment variables
- Already open terminal tabs
- The kernel

```mermaid
flowchart TD
    A[chsh -s /usr/bin/zsh] --> B[Updates only /etc/passwd<br/>for this user]
    B --> C[Future sessions will read this value]
    C --> D[Existing processes and env vars are unaffected]
```



---

## How a Brand New Terminal Session Is Born

When you reboot (or log out and open a completely fresh terminal), this is the normal sequence:

```mermaid
sequenceDiagram
    participant User
    participant Terminal as Terminal Emulator<br/>(kitty, foot, etc.)
    participant Launcher as Session Manager / login
    participant Passwd as /etc/passwd
    participant NewShell as New Shell Process<br/>(zsh or bash)

    User->>Terminal: Opens new terminal tab/window
    Terminal->>Launcher: "Start a shell for this user"
    Launcher->>Passwd: getpwuid(getuid()) or getent
    Passwd-->>Launcher: shell = /usr/bin/zsh
    Launcher->>NewShell: setenv("SHELL", "/usr/bin/zsh")<br/>execve("/usr/bin/zsh", ..., env)
    NewShell-->>User: Prompt appears with SHELL=/usr/bin/zsh in environment
```



At this point `$SHELL` is set **before** the shell binary even starts running. The value comes from the database at session creation time.

---

## Environment Variable Inheritance (The Core Mechanism)

Unix processes do not share memory. When one process starts another, it uses `execve(2)` (or `posix_spawn`, etc.).

The kernel simply copies the **environment block** (a list of `KEY=VALUE` strings) from the parent to the child.

```mermaid
flowchart LR
    subgraph Parent["Parent Process<br/>(original bash)"]
        E1["Environment Block<br/>SHELL=/usr/bin/bash<br/>PATH=...<br/>..."]
    end

    subgraph Child["Child Process<br/>(after exec zsh)"]
        E2["Environment Block<br/>(exact copy)<br/>SHELL=/usr/bin/bash<br/>PATH=...<br/>..."]
    end

    Parent -- "execve(zsh, argv, envp)" --> Child
    E1 -.->|copied by kernel| E2
```



There is **no** kernel magic that rewrites `SHELL` when you change your passwd entry or replace the process image.

---

## Why `exec /usr/bin/zsh -l` Usually Does **Not** Update `$SHELL`

```mermaid
flowchart TD
    A[Terminal starts with bash<br/>SHELL=/usr/bin/bash is set in env] --> B[You run: exec /usr/bin/zsh -l]
    B --> C[zsh replaces the bash process image]
    C --> D[zsh inherits the entire environment block<br/>including the old SHELL value]
    D --> E[echo $SHELL<br/>→ /usr/bin/bash]
    E --> F[Prompt may look like zsh<br/>ZSH_VERSION may be set<br/>But $SHELL is still lying]
```



This is exactly what happened in the user's sessions. The process changed, but the environment did not.

---

## When `$SHELL` **Does** Get the Correct Value

A completely new session must be created after the `chsh` change:

```mermaid
flowchart TD
    subgraph OldSession["Old Terminal Session"]
        O1[Started before or with old passwd value]
        O2[SHELL=/usr/bin/bash inherited forever]
    end

    subgraph Reboot["Full System Reboot<br/>or logout + new login"]
        R1[New session created]
        R2[Terminal / login reads current passwd]
        R3[setenv SHELL=/usr/bin/zsh]
        R4[exec zsh]
    end

    OldSession -.->|stale| Reboot
    R1 --> R2 --> R3 --> R4
```



After reboot + opening a terminal:

- `getent passwd $USER` → `/usr/bin/zsh`
- `echo $SHELL` → `/usr/bin/zsh` (set at birth of this session)
- Current process is also zsh

---

## Your Custom "Truth Seeker" Code

Because stale `$SHELL` is so common during development and debugging, this repo adds overrides in two places:

- `~/.zshenv` (runs for **every** zsh, very early)
- `~/.config/shell/env.sh` (sourced by bash, zsh, and fish via bass)

```mermaid
flowchart TD
    ZSHENV["~/.zshenv<br/>(every zsh)"] -->|export SHELL=.../zsh| CorrectZSH["$SHELL now truthful"]
    ENVSH["env.sh<br/>(bash + zsh)"] -->|if ZSH_VERSION → set zsh<br/>elif BASH_VERSION → set bash| CorrectBoth["Corrects even after exec<br/>or when sourced from wrong shell"]
```



These overrides are **not** standard behavior. They are a deliberate local policy to make `$SHELL` reflect reality in your day-to-day use.

---

## Recommended Commands (Always Tell the Truth)

```bash
# The three values that matter
echo "passwd (what chsh controls):   $(getent passwd $USER | cut -d: -f7)"
echo "current process:               $(ps -p $$ -o comm=)  ($0)"
echo "SHELL env var:                 $SHELL"

# Convenience helper (provided by this repo)
shell_debug
```

---

## Common Gotchas

- **Reopening the terminal app** is not always enough — some emulators remember the shell used for existing profiles.
- **tmux / screen / zellij** reattach old sessions and keep their original environment.
- **Terminal emulators** sometimes have their own "default shell" setting that can override or ignore `chsh`.
- **Agents and wrappers** (build tools, remote development servers, etc.) often start under whatever shell the parent had.
- `$SHELL` is **not** "the shell I am currently in." It is "the shell that was given to this session when it started."

---

## Summary

- `chsh` updates only the database.
- `$SHELL` is set by the **session creator** (terminal / login) at birth and then inherited.
- `exec` gives you a new process but the same environment.
- A full reboot (or clean new login session) is the only reliable way to get a fresh `$SHELL` value from passwd without custom overrides.
- The "truth seeker" logic in this repo exists precisely because the above behavior is surprising and inconvenient in practice.

This document lives in the shell config repo so future you (or collaborators) can understand why things behave the way they do.