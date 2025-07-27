# 📝 Git README Updater

### ❗ This repository is still in active development. Features may change, and bugs may exist. ❗

Git README Updater (`gru`) is a collection of Bash scripts that let you **dynamically build and update README files locally**, and optionally **link them to remote Git repositories for automatic pushing and updating**. Whether you want to generate up-to-date README sections on your machine or automate updates directly in remote repositories, this tool provides a simple CLI workflow for both.

---

## ⚙️ What It Does

- **Build your README locally** by defining editable sections and inserting dynamic content using templates.  
- **Link your local setup to a remote Git repository** so you can commit and push README changes automatically.  
- Manage multiple README targets and repositories with ease.  

This makes it perfect for maintaining your profile README, project dashboards, or any documentation that changes frequently.

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
   If `git` is not installed yet, install it (required for script functionality and installation process).

2. Ensure the target directory is writable, for the configuration files will be stored there.

3. Install `jq`, a lightweight and flexible JSON processor (required for script functionality).

4. Optionally, create symbolic links to the `.sh` script files in a directory listed in your `$PATH` to run them from anywhere.

> ⚠️ All scripts have to be located in the same directory. This directory has to be read-/writable when executing the script.

---

## ⚙️ Usage

### Overview

`gru` has modular commands to manage targets (local or remote), write section content, and build/push your README files.

| Command Group | Purpose |
|---------------|---------|
| `gru-target`  | Manage local README files and link remote repositories for automatic updates |
| `gru-writer`  | Add, update, or erase content in logical README sections |
| `gru-worker`  | Build README from templates locally, and push updates to remote repositories |

---

### How to Use

1. **Set up a target:**

   - To **work locally only**, register a README file without linking a remote repository.  
   - To **automatically update a remote Git repository**, register a target and link it to the repository and branch.

2. **Write or update content sections** in the README.

3. **Build your README locally** from a template file, which will replace placeholders with your dynamic content.

4. (Optional) **Push your updated README automatically** to the linked remote repository.

---

### 📌 Commands

#### 🔹 `gru-target`
| Command | Description |
|--------|-------------|
| `add <IDENTIFIER> [<REPOSITORY LINK> <BRANCH> <PATH/TO/FILE>]` | Registers a new target and optionally links it to a remote repository's file. |
| `remove <IDENTIFIER>` | Removes a registered target. |
| `link <IDENTIFIER> [<REPOSITORY LINK> <BRANCH> <PATH/TO/FILE>]` | Links the target to a remote repository's file or removes the remote link. |
| `select [<IDENTIFIER>]` | Selects a default target for future commands. Unselects current target if none is specified. |
| `info <IDENTIFIER>` | Displays the target's section count and remote configuration. |
| `list` | Lists all registered targets. |
| `selected` | Displays the currently selected target's information (`info <IDENTIFIER>`). |

#### 🔹 `gru-writer`
| Command | Description |
|--------|-------------|
| `write <TEXT> <IDENTIFIER> <SECTION> [<TARGET_IDENTIFIER>]` | Adds or updates a line in a section. |
| `erase <IDENTIFIER> <SECTION> [<TARGET_IDENTIFIER>]` | Removes a line from a section. |
| `set-placeholder <PLACEHOLDER> <SECTION> [<TARGET_IDENTIFIER>]` | Sets a placeholder to be used if the section is empty. |
| `read [--section\|-s <SECTION>] [<TARGET_IDENTIFIER>]` | Displays existing sections or data inside a specific section. |
| `read-section <SECTION> [<TARGET_IDENTIFIER>]` | Shortcut for `read --section`. |

#### 🔹 `gru-worker`
| Command | Description |
|--------|-------------|
| `build <TEMPLATE_PATH> <OUTPUT_PATH> [<TARGET_IDENTIFIER>]` | Generates a new README using a template. |
| `remote-update <BUILT_FILE_PATH> [--message\|-m <COMMIT_MESSAGE>] [<TARGET_IDENTIFIER>]` | Pulls the repository and commits & pushes the new README to the remote repository. |

---

### 💡 Example Workflow for Remote Auto-Update

**Goal:** Automatically update the "Current Projects" section in a remote repository's README.

1. **Register the remote README file as a target:**
   ```bash
   gru-target add "johnDoe/johnDoe:main" "/README.md" "ProfileRm"
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

5. **Build the new README locally:**
   ```bash
   gru-worker build "./template.md" "./builtReadme.md"
   ```

   Output (`builtReadme.md`):
   ```
   # John Doe

   I'm a fictional programmer for explaining "gru"

   *My current projects are:*
   - Personal website
   ```

6. **Push the updated README automatically to the remote repository:**
   ```bash
   gru-worker remote-update "./builtReadme.md" --message "Updated project list"
   ```

---

### 💡 Example Workflow for Local-Only Build

**Goal:** Build and update a README locally without linking to a remote repository.

1. **Register a local README file as a target (no remote repo linked):**
   ```bash
   gru-target add "local-readme" "/path/to/README.md"
   ```

2. **Select the target:**
   ```bash
   gru-target select "local-readme"
   ```

3. **Write a new section entry:**
   ```bash
   gru-writer write "- Local project" "LocalProject" "Projects"
   ```

4. **Build the README locally:**
   ```bash
   gru-worker build "./template.md" "./builtReadme.md"
   ```

In this workflow, no remote push occurs—you manually manage the README file after building.

---

## 📖 Key Concepts

| Term | Description |
|------|-------------|
| **Target** | A reference to a specific file in a Git repository (user/repo:branch + path). Commands operate on these targets. |
| **Writer** | Manages section content. Changes are stored in configuration until a build is triggered. |
| **Section** | Logical segments of a README (e.g., “Projects”, “Tech Stack”) to be dynamically populated. |
| **Template** | A file with placeholders like `{@Projects}` that get replaced with actual data during the build. |
| **Build** | The process of rendering a README by replacing placeholders in a template with content from the `writer`. |

---

## ✅ Benefits

- Keeps READMEs up-to-date **automatically** or manually
- Ideal for **profile READMEs, project dashboards, portfolios, and more**
- Clean and minimal interface using only Bash, `jq`, and `git`
- Supports **local files, remote repositories on any Git host and Git branches**

---

## 🧰 Requirements

- Unix-based OS  
- `bash`  
- [`jq`](https://stedolan.github.io/jq/)  
- [`git`](https://git-scm.com/)  

---

## 📎 License

MIT — see [LICENSE](https://github.com/RedStoneMango/git-readme-updater/blob/main/LICENSE) for details.

