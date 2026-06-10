# CLI Reference — `oomg`

The `oomg` command-line tool is installed automatically when you add
`odoo_model_generator` as a dependency and provides five commands.

---

## Installation

```bash
# Global activation (recommended)
dart pub global activate odoo_model_generator

# Or run directly without activation
dart run odoo_model_generator:oomg <command> [options]
```

---

## Global help

```bash
oomg --help
oomg <command> --help
```

---

## Commands

### `generate` (aliases: `gen`, `g`)

Generates a full Odoo module from either a JSON schema file or a model name,
and writes the output files to disk.

```
oomg generate [options]
```

#### Options

| Flag / Option | Abbr | Default | Description |
|---------------|------|---------|-------------|
| `--schema FILE` | `-s` | — | Path to a JSON schema file describing the model. |
| `--model MODEL` | `-m` | — | Odoo model name (e.g. `x_product_custom`). Creates a minimal model with `NameField` only. |
| `--output DIR` | `-o` | `./generated` | Output directory for the generated module. |
| `--author TEXT` | | `'Your Company'` | Author name in `__manifest__.py`. |
| `--version TEXT` | | `'1.0.0'` | Module version in `__manifest__.py`. |
| `--license TEXT` | | `'LGPL-3'` | License identifier. |
| `--no-security` | | `false` | Skip generating `security/ir.model.access.csv`. |
| `--demo` | | `false` | Generate a `data/demo.xml` stub. |
| `--open` | | `false` | Open the output folder after generation. |
| `--verbose` / `-v` | `-v` | `false` | Enable verbose (DEBUG-level) logging. |

#### Examples

```bash
# Generate from model name (minimal — adds NameField automatically)
oomg generate --model x_product_custom --output ./modules/x_product_custom

# Generate from JSON schema with author and version
oomg generate --schema schema.json --output ./out --author "Acme Corp" --version 2.0.0

# Generate without security file, with demo stub
oomg generate --model x_demo --no-security --demo

# Verbose output
oomg gen -m x_task -o ./out --verbose
```

#### JSON schema format

```json
{
  "modelName": "x_project_task",
  "docstring": "Project Task",
  "stringField": "name",
  "dependencies": ["project"],
  "inherits": ["mail.thread", "mail.activity.mixin"],
  "fields": [
    { "type": "Char",      "name": "name",        "required": true, "inTree": true  },
    { "type": "Many2one",  "name": "project_id",  "relation": "project.project", "required": true },
    { "type": "Date",      "name": "deadline" },
    { "type": "Selection", "name": "state",        "options": ["draft", "done"] },
    { "type": "Float",     "name": "hours",        "digits": [10, 2] },
    { "type": "Text",      "name": "description" }
  ]
}
```

Supported `type` values (case-insensitive):
`char`, `text`, `html`, `integer`, `float`, `monetary`, `boolean`,
`date`, `datetime`, `binary`, `image`, `selection`,
`many2one`, `one2many`, `many2many`.

---

### `validate` (alias: `check`)

Validates a model definition **without** writing any files.  Exits `0` on
success, `1` on validation failure.

```
oomg validate [options]
```

#### Options

| Flag / Option | Abbr | Default | Description |
|---------------|------|---------|-------------|
| `--schema FILE` | `-s` | — | Path to a JSON schema to validate fully. |
| `--model MODEL` | `-m` | — | Model name to validate (name rules only). |

#### Examples

```bash
# Validate a JSON schema
oomg validate --schema schema.json

# Validate a model name only
oomg check --model x_product_custom
```

#### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Validation passed. |
| `1` | Validation failed (error printed to stderr). |
| `64` | Usage error (missing required options). |

---

### `dry-run` (alias: `preview`)

Validates the model and prints the **would-be generated file contents** to
stdout, without writing anything to disk.

```
oomg dry-run [options]
```

#### Options

| Flag / Option | Abbr | Default | Description |
|---------------|------|---------|-------------|
| `--schema FILE` | `-s` | — | JSON schema file. |
| `--model MODEL` | `-m` | — | Model name (generates minimal model). |
| `--file TARGET` | `-f` | `all` | Show only a specific section. Allowed: `models`, `manifest`, `views`, `security`, `all`. |

#### Examples

```bash
# Preview everything
oomg dry-run --model x_task

# Preview only the Python model file
oomg dry-run --schema task.json --file models

# Preview only the manifest
oomg preview --model x_invoice --file manifest
```

---

### `export`

Packages an already-generated module directory into a ZIP or TAR.GZ archive
ready for deployment to an Odoo server.

```
oomg export --module DIR --zip FILE [--format zip|tar]
```

#### Options

| Flag / Option | Abbr | Required | Description |
|---------------|------|----------|-------------|
| `--module DIR` | `-m` | ✓ | Path to the generated module directory. |
| `--zip FILE` | `-z` | ✓ | Output archive file path (include `.zip` or `.tar.gz` extension). |
| `--format FORMAT` | | `zip` | Archive format: `zip` or `tar`. |

#### Examples

```bash
# Export to ZIP
oomg export --module ./my_module --zip ./my_module.zip

# Export to TAR.GZ
oomg export -m ./my_module -z ./my_module.tar.gz --format tar
```

---

### `version` (aliases: `--version`, `-V`)

Prints the installed package version and Dart SDK version.

```bash
oomg version
# odoo_model_generator v2.0.0
# Dart SDK: 3.x.y (stable) ...
```

---

## Typical workflow

```bash
# 1. Write your schema
cat > task.json << 'EOF'
{
  "modelName": "x_project_task",
  "docstring": "Project Task",
  "dependencies": ["project"],
  "fields": [
    { "type": "Char",     "name": "name",       "required": true },
    { "type": "Many2one", "name": "project_id", "relation": "project.project" },
    { "type": "Date",     "name": "deadline" },
    { "type": "Float",    "name": "hours" }
  ]
}
EOF

# 2. Validate
oomg validate --schema task.json

# 3. Preview
oomg dry-run --schema task.json --file models

# 4. Generate
oomg generate --schema task.json --output ./x_project_task --author "My Corp"

# 5. Export
oomg export --module ./x_project_task --zip ./x_project_task.zip

# 6. Deploy to Odoo (requires odoo-bin on PATH)
cp x_project_task.zip /path/to/odoo/addons/
# Then upgrade: odoo-bin -u x_project_task -d mydb --stop-after-init
```

---

## Logging

By default the CLI logs at `INFO` level to **stderr** (so stdout can be
piped cleanly).  Pass `--verbose` / `-v` to any command to switch to
`ALL` level and see detailed debug messages.

Log prefixes:

| Prefix | Level |
|--------|-------|
| `ℹ️` | INFO |
| `⚠️` | WARNING |
| `❌` | SEVERE / ERROR |
