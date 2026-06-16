# Motivation

This project was inspired by a post from [@tetsuoai](https://x.com/tetsuoai) that encouraged moving away from heavy IDE reliance and returning to a more deliberate terminal-based workflow. While tools like Emacs, Vim, and various CLI utilities were already familiar, they were mostly used in an unstructured way during academic and early professional work.

The lack of consistent discipline, repeatable processes, and a clear human-in-the-loop approach became increasingly limiting as agent-assisted development grew. This led to the development of a structured verification workflow — centered around `ab` (agent build) and `av` (agent verify), tiered tmux layouts, and the `.agents/verification/` directory structure — designed to make reviewing and validating agent output faster, more reliable, and more intentional.

The goal is not to reject modern tooling, but to build a focused, terminal-native system that keeps the human firmly in control.

**Reference:** [This post by @tetsuoai](https://x.com/tetsuoai/status/2001686988961755438?s=20) nudged the direction. The verification cockpit and workflow design are original to this project (developed while iterating with Grok); the post motivated action, not the architecture.

See [arch-design/VERIFICATION.md](arch-design/VERIFICATION.md) for the operational workflow.
