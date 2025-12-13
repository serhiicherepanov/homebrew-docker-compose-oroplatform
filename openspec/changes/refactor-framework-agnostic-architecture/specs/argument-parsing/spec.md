## ADDED Requirements

### Requirement: Smart Argument Parsing
The system SHALL intelligently parse command-line arguments to distinguish between Docker Compose flags, commands, and container command arguments.

#### Scenario: Parse Docker Compose flags before command
- **WHEN** user executes `dcx --profile=test up -d`
- **THEN** it SHALL identify `--profile=test` as Docker Compose flag (left)
- **AND** it SHALL identify `up` as Docker Compose command
- **AND** it SHALL identify `-d` as Docker Compose flag (right)
- **AND** it SHALL build: `docker compose --profile=test up -d`

#### Scenario: Parse complex run command with container arguments
- **WHEN** user executes `dcx --profile=test run --rm cli php bin/console cache:clear --env=prod`
- **THEN** it SHALL parse into:
  - left_flags: `[--profile=test]`
  - command: `run`
  - args: `[--rm, cli, php, bin/console, cache:clear]`
  - right_flags: `[--env=prod]`
- **AND** it SHALL preserve exact argument order
- **AND** it SHALL handle quoted arguments correctly

#### Scenario: Distinguish Docker Compose options from container command options
- **WHEN** user executes `dcx --file=custom.yml run cli composer install --dev`
- **THEN** it SHALL identify `--file=custom.yml` belongs to Docker Compose
- **AND** it SHALL identify `--dev` belongs to composer command
- **AND** it SHALL not confuse the two

#### Scenario: Handle flags with values (long and short forms)
- **WHEN** parsing arguments with option values
- **THEN** it SHALL handle:
  - Long form with equals: `--profile=test`
  - Long form with space: `--profile test`
  - Short form: `-p test`
- **AND** it SHALL keep paired options together
- **AND** it SHALL detect first non-flag as command boundary

### Requirement: Argument Bucket Organization
The system SHALL organize parsed arguments into distinct buckets for correct command construction.

#### Scenario: Organize flags into left and right buckets
- **WHEN** parsing command with flags before and after service name
- **THEN** it SHALL maintain:
  - left_flags: flags before Docker Compose command
  - left_options: options with values before command
  - right_flags: flags after service name (go to container command)
  - right_options: options with values after service name
- **AND** boundaries SHALL be clear and consistent

#### Scenario: Build Docker Compose command from buckets
- **WHEN** constructing final Docker Compose command
- **THEN** it SHALL assemble in order:
  1. `docker compose`
  2. left_flags and left_options
  3. command (up, run, exec, etc.)
  4. service-specific args
  5. right_flags and right_options
- **AND** all arguments SHALL be properly quoted

#### Scenario: Handle empty buckets gracefully
- **WHEN** no left or right flags present
- **THEN** it SHALL work correctly with minimal arguments
- **AND** it SHALL not add empty strings to command
- **AND** simple commands like `dcx up` SHALL work

### Requirement: Docker Compose Command Detection
The system SHALL automatically detect Docker Compose native commands to determine argument parsing strategy.

#### Scenario: Detect Docker Compose native commands
- **WHEN** first non-flag argument is checked
- **THEN** it SHALL recognize Docker Compose commands:
  - up, down, start, stop, restart
  - ps, logs, exec, run
  - build, pull, push
  - config, version, ls
- **AND** if command is Docker Compose native, it SHALL parse accordingly
- **AND** if command is NOT Docker Compose native, it SHALL treat as container command

#### Scenario: Handle commands that don't need argument parsing
- **WHEN** command is simple Docker Compose command (up, down, ps)
- **THEN** it SHALL skip complex parsing
- **AND** it SHALL pass all arguments directly to Docker Compose
- **AND** performance SHALL be optimal

#### Scenario: Handle non-Docker Compose commands
- **WHEN** command is NOT Docker Compose native (install, platformupdate, php, etc.)
- **THEN** it SHALL treat entire command as container execution
- **AND** it SHALL route to appropriate handler (plugin or core)
- **AND** it SHALL NOT attempt Docker Compose argument parsing

### Requirement: Argument Preservation
The system SHALL preserve exact argument values, quoting, and spacing when passing to containers.

#### Scenario: Preserve arguments with spaces
- **WHEN** user executes `dcx run cli php -r "echo 'hello world';"`
- **THEN** it SHALL preserve quoted string exactly
- **AND** spaces inside quotes SHALL be maintained
- **AND** command in container SHALL receive correct string

#### Scenario: Preserve special characters
- **WHEN** arguments contain special bash characters
- **THEN** it SHALL properly escape:
  - Dollar signs ($)
  - Backticks (`)
  - Exclamation marks (!)
  - Pipes (|)
  - Semicolons (;)
- **AND** these SHALL reach container command unchanged

#### Scenario: Handle array arguments in bash
- **WHEN** building command from argument array
- **THEN** it SHALL use proper bash array expansion: `"${args[@]}"`
- **AND** it SHALL NOT use `$*` which breaks on spaces
- **AND** each argument SHALL remain as separate parameter

### Requirement: Transparent Binary Redirection
The system SHALL transparently redirect to appropriate binary when called without explicit command.

#### Scenario: Detect call as symlink with different name
- **WHEN** dcx is called via symlink named `php`
- **THEN** it SHALL detect the calling name
- **AND** it SHALL redirect to PHP in container: `dcx run cli php "$@"`
- **AND** all arguments SHALL be passed through

#### Scenario: Detect PHP-specific flags
- **WHEN** first argument is PHP flag (`-v`, `--version`, `-r`, `-l`, `-m`, `-i`)
- **THEN** it SHALL automatically redirect to PHP
- **AND** no explicit `php` command SHALL be needed
- **AND** `dcx -v` SHALL work like `php -v` in container

#### Scenario: Detect PHP file as argument
- **WHEN** first argument ends with `.php`
- **THEN** it SHALL automatically execute via PHP in container
- **AND** `dcx script.php` SHALL work like `php script.php` in container
- **AND** external PHP files SHALL be mounted if outside project

#### Scenario: Detect Symfony console commands
- **WHEN** first argument is `bin/console` or matches pattern `cache:*`, `oro:*`, etc.
- **THEN** it SHALL automatically execute in CLI container
- **AND** `dcx bin/console cache:clear` SHALL work without explicit container

### Requirement: Configurable Binary Redirection
The system SHALL allow per-project configuration of default binary for transparent redirection.

#### Scenario: Configure default binary via environment variable
- **WHEN** DC_DEFAULT_BINARY environment variable is set
- **THEN** it SHALL use that binary for transparent redirection
- **AND** values SHALL include: `php`, `node`, `python`, `ruby`, `make`, `none`
- **AND** `none` SHALL disable transparent redirection

#### Scenario: Framework plugin sets default binary
- **WHEN** framework plugin is loaded (e.g., Oro plugin)
- **THEN** plugin MAY set default binary: `DC_DEFAULT_BINARY=php`
- **AND** this SHALL affect transparent redirection behavior
- **AND** user's explicit setting SHALL override plugin default

#### Scenario: Node.js project redirection
- **WHEN** DC_DEFAULT_BINARY=node
- **AND** user executes `dcx --version`
- **THEN** it SHALL execute: `docker compose run cli node --version`
- **AND** it SHALL work transparently like node binary

#### Scenario: Python project redirection
- **WHEN** DC_DEFAULT_BINARY=python
- **AND** user executes `dcx script.py`
- **THEN** it SHALL execute: `docker compose run cli python script.py`
- **AND** .py files SHALL be detected automatically

#### Scenario: Disable transparent redirection
- **WHEN** DC_DEFAULT_BINARY=none
- **THEN** transparent redirection SHALL be disabled
- **AND** user MUST explicitly specify commands
- **AND** `dcx -v` SHALL show dcx version, not container binary version

### Requirement: Argument Parsing Performance
The system SHALL parse arguments efficiently without impacting startup time.

#### Scenario: Fast parsing for simple commands
- **WHEN** command is simple (e.g., `dcx up -d`)
- **THEN** parsing SHALL complete in <10ms
- **AND** no unnecessary complexity SHALL be added
- **AND** direct passthrough to Docker Compose SHALL be used

#### Scenario: Parse only when necessary
- **WHEN** command clearly doesn't need parsing
- **THEN** system SHALL skip parsing logic
- **AND** arguments SHALL pass through directly
- **AND** startup time target (<100ms) SHALL be maintained

### Requirement: Debug Mode for Argument Parsing
The system SHALL provide debug output showing how arguments were parsed and routed.

#### Scenario: Show argument parsing in debug mode
- **WHEN** DEBUG=1 environment variable is set
- **THEN** system SHALL output:
  - Original arguments
  - Parsed buckets (left_flags, right_flags, etc.)
  - Detected command type
  - Final Docker Compose command
  - Redirection decisions
- **AND** output SHALL go to stderr (not interfere with stdout)

#### Scenario: Debug transparent redirection
- **WHEN** DEBUG=1 and transparent redirection occurs
- **THEN** system SHALL output:
  - "Detected: PHP flag (-v)"
  - "Redirecting to: docker compose run cli php -v"
  - Default binary configuration
- **AND** this SHALL help troubleshoot redirection issues

