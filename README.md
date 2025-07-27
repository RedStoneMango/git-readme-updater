# 📝 Git README Updater

### ❗ This repository is not finished yet. I'm actively developing this tool and will be done as soon as possible ❗

A collection of Bash scripts to **dynamically update sections in README files** with ease. Automate README updates across multiple (remote) repositories using a simple CLI toolchain.

---

## 🚀 Installation

> **Note:** These scripts are designed for **Unix-based systems** only.

### 🔧 Automatic Installation

Run the following one-liner to install the updater and all required dependencies:

```bash
curl -s https://raw.githubusercontent.com/redstonemango/git-readme-updater/main/install.sh | bash -s -- /DESIRED/INSTALLATION/PATH
```

📌 Replace `/DESIRED/INSTALLATION/PATH` with the directory where you’d like the scripts to be installed. Missing directories will be created automatically.

The installation script will:
- Install required dependencies (`jq`, `git`)
- Download the script files
- Create symbolic links in your `$PATH`

> ⚠️ You may need **elevated privileges** to install dependencies and create symlinks in system paths.

---

### 🛠 Manual Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/RedStoneMango/git-readme-updater.git
   ```
   If `git` is not installed yet, install it (required for script functionality and instalation process).

2. Ensure the target directory is writable, for the configuration files will be stored there.

3. Install `jq`, a lightweight and flexible JSON processor (required for script functionality).

4. Optionally, create symbolic links to the `.sh` script files in a directory listed in your `$PATH` to run them from anywhere.

> ⚠️ All scripts have to be located in the same directory. This directory has to be read-/writable when executing the script.

---

## ⚙️ Usage

### 📚 Overview

The Git README Updater (`gru`) is made up of modular command groups:

| Command Group | Description |
|---------------|-------------|
| `gru-target`  | Manage target repositories and files |
| `gru-writer`  | Write to or manage content in README sections |
| `gru-worker`  | Build and push updated README files |

---

### 📌 Commands

#### 🔹 `gru-target`
| Command | Description |
|--------|-------------|
| `add <IDENTIFIER> [<USER/REPO:BRANCH> <PATH/TO/FILE>]` | Registers a new target and optionally links it to a remote repository's file. |
| `remove <IDENTIFIER>` | Removes a registered target. |
| `link <IDENTIFIER> [<USER/REPO:BRANCH> <PATH/TO/FILE>]` | Links the target to a remote repository's file or removes the remote link. |
| `select [<IDENTIFIER>]` | Selects a default target for future commands. Unselects current target is none is specified. |
| `info <IDENTIFIER>` | Displays the target's linked repository and remote file. |
| `list` | Lists all registered targets. |
| `selected` | Displays the currently selected target. |

#### 🔹 `gru-writer`
| Command | Description |
|--------|-------------|
| `write <TEXT> <IDENTIFIER> <SECTION> [<TARGET_IDENTIFIER>]` | Adds or updates a line in a section. |
| `erase <IDENTIFIER> <SECTION> [<TARGET_IDENTIFIER>]` | Removes a line from a section. |
| `set-placeholder <PLACEHOLDER> <SECTION> [<TARGET_IDENTIFIER>]` | Sets a placeholder to be used if the section is empty. |
| `read [--section\|-s <SECTION>] [<TARGET_IDENTIFIER>]` | Displays existing sections or data inside a specific section. |
| `read-section <SECTION> [<TARGET_IDENTIFIER>]` | Shortcut for read --section. |

#### 🔹 `gru-worker`
| Command | Description |
|--------|-------------|
| `build <TEMPLATE_PATH> <OUTPUT_PATH> [<TARGET_IDENTIFIER>]` | Generates a new README using a template. |
| `remote-update <BUILT_FILE_PATH> [--message\|-m <COMMIT_MESSAGE>] [<TARGET_IDENTIFIER>]` | Pulls the repository and commits & pushes the new README to GitHub. |

---

### 💡 Example Workflow

**Goal:** Automatically update the "Current Projects" section in a GitHub profile README.

1. **Register the README file as a target:**
   ```bash
   gru-target add "JohnDoe/JohnDoe:main" "/README.md" "ProfileRm"
   ```

2. **Select the target:**
   ```bash
   gru-target select "ProfileRm"
   ```

3. **Write a new project entry:**
   ```bash
   gru-writer write "- Personal website" "Website" "Projects"
   ```

4. **Create a README template:**

   `template.md`:
   ```
   # John Doe

   I'm a fictional programmer for explaining "gru"

   *My current projects are:*
   {@Projects}
   ```

5. **Build the new README:**
   ```bash
   gru-worker build "./template.md" "./builtReadme.md"
   ```

   Output `(builtReadme.md)`:
   ```
   # John Doe

   I'm a fictional programmer for explaining "gru"

   *My current projects are:*
   - Personal website
   ```

6. **Update the linked remote repository:**
   ```bash
   gru-worker remote-update "./builtReadme.md" --message "Updated project list"
   ```

---

## 📖 Key Concepts

| Term | Description |
|------|-------------|
| **Target** | A reference to a specific file in a GitHub repository (user/repo:branch + path). Commands operate on these targets. |
| **Writer** | Manages section content. Changes are stored in configuration until a build is triggered. |
| **Section** | Logical segments of a README (e.g., “Projects”, “Tech Stack”) to be dynamically populated. |
| **Template** | A file with placeholders like `{@Projects}` that get replaced with actual data during the build. |
| **Build** | The process of rendering a README by replacing placeholders in a template with content from the `writer`. |

---

## ✅ Benefits

- Keeps READMEs up-to-date **automatically**
- Ideal for **GitHub profiles, project dashboards, portfolio READMEs**
- Clean and minimal interface using only Bash, `jq` and `git`
- Supports **remote repositories and branches**

---

## 🧰 Requirements

- Unix-based OS
- `bash`
- [`jq`](https://stedolan.github.io/jq/)
- [`git`](https://git-scm.com/)

---

## 📎 License

MIT — see [LICENSE](https://github.com/RedStoneMango/git-readme-updater/blob/main/LICENSE) for details.
