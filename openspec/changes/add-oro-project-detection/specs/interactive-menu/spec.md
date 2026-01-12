## MODIFIED Requirements

### Requirement: Interactive Menu Display When No Arguments Provided

The system SHALL display an interactive menu when `orodc` is executed without any arguments in an interactive terminal. Menu items SHALL be conditionally displayed based on whether the project is an Oro Platform application. Menu SHALL support arrow key navigation and verbose mode toggle.

#### Scenario: Display menu when no arguments provided
- **WHEN** user runs `orodc` without any arguments
- **AND** terminal is interactive (TTY)
- **THEN** an interactive menu SHALL be displayed
- **AND** current environment context SHALL be shown (name, status, directory)
- **AND** user SHALL be prompted: "Use ↑↓ arrows to navigate, or type number [1-21], 'v' for VERBOSE, 'q' to quit"

#### Scenario: Navigate with arrow keys
- **WHEN** menu is displayed
- **AND** user presses ↑ (up arrow)
- **THEN** selection SHALL move to previous menu item
- **AND** selected item SHALL be highlighted
- **WHEN** user presses ↓ (down arrow)
- **THEN** selection SHALL move to next menu item
- **AND** selected item SHALL be highlighted
- **WHEN** user presses Enter
- **THEN** highlighted option SHALL be executed

#### Scenario: Toggle VERBOSE mode
- **WHEN** menu is displayed
- **AND** user presses 'v' key
- **THEN** VERBOSE mode SHALL toggle on/off
- **AND** menu SHALL be redrawn with VERBOSE status indicator
- **WHEN** VERBOSE mode is enabled
- **THEN** subsequent commands SHALL run with VERBOSE=1 environment variable
- **AND** spinners SHALL be disabled
- **AND** full command output SHALL be displayed

#### Scenario: Display full menu for Oro projects
- **WHEN** menu is displayed
- **AND** project is detected as Oro project (via `is_oro_project()` or `DC_ORO_IS_ORO_PROJECT=1`)
- **THEN** all menu options (1-21) SHALL be displayed including Oro-specific items:
  - 15) Clear cache
  - 16) Platform update (Oro-only)
  - 17) Install with demo data (Oro-only)
  - 18) Install without demo data (Oro-only)
  - 19) Install dependencies (Oro-only)

#### Scenario: Display reduced menu for non-Oro projects
- **WHEN** menu is displayed
- **AND** project is NOT detected as Oro project
- **THEN** Oro-specific menu items SHALL be hidden:
  - Platform update SHALL NOT be displayed
  - Install with demo data SHALL NOT be displayed
  - Install without demo data SHALL NOT be displayed
  - Install dependencies SHALL NOT be displayed
- **AND** remaining menu items SHALL be renumbered to fill gaps
- **AND** menu numbering SHALL remain sequential without gaps

#### Scenario: Display grouped menu in single column
- **WHEN** menu is displayed in terminals narrower than 100 columns
- **THEN** menu options SHALL be grouped under headings with these options:
  - Environment Management (1-5): List, Initialize, Start, Stop, Delete
  - Build & Maintenance (6-8): Re-build Images, Run doctor, Connect SSH
  - CLI & Database (9-12): Connect CLI, Export DB, Import DB, Purge DB
  - Configuration (13-14): Add/Manage domains, Configure URL
  - Oro Operations (15-19, conditional): Clear cache, Platform update, Install with demo, Install without demo, Install dependencies
  - Proxy (20-21): Start proxy, Stop proxy
- **AND** each option number SHALL align with its heading and description

#### Scenario: Display grouped menu in two columns
- **WHEN** menu is displayed in terminals 100 columns wide or more
- **THEN** menu SHALL render a two-column layout with paired headings
- **AND** Oro-specific sections SHALL be omitted for non-Oro projects

#### Scenario: Skip menu in non-interactive mode
- **WHEN** user runs `orodc` without arguments
- **AND** terminal is not interactive (piped input, script execution)
- **THEN** menu SHALL be skipped
- **AND** system SHALL fall through to default Docker Compose behavior

#### Scenario: Skip menu when arguments provided
- **WHEN** user runs `orodc` with any arguments (e.g., `orodc up -d`)
- **THEN** menu SHALL be skipped
- **AND** command SHALL execute normally

#### Scenario: Skip menu with environment variable
- **WHEN** `ORODC_NO_MENU=1` environment variable is set
- **THEN** menu SHALL be skipped even in interactive mode

### Requirement: Menu Option: Platform Update

The system SHALL provide a menu option to perform platform update, visible only for Oro projects.

#### Scenario: Platform update visible for Oro projects
- **WHEN** menu is displayed
- **AND** project is detected as Oro project
- **THEN** "Platform update" option SHALL be visible in Maintenance section

#### Scenario: Platform update hidden for non-Oro projects
- **WHEN** menu is displayed
- **AND** project is NOT detected as Oro project
- **THEN** "Platform update" option SHALL NOT be displayed

#### Scenario: Platform update stops services and runs CLI only
- **WHEN** user selects "Platform update" option
- **THEN** system SHALL stop all application services (FPM, Nginx, WebSocket, Consumer)
- **AND** system SHALL keep dependency services running (Database, Redis, Elasticsearch, RabbitMQ)
- **AND** system SHALL execute `docker compose run --rm cli php bin/console oro:platform:update --force`
- **AND** progress SHALL be displayed during update
- **AND** after completion, success message SHALL be displayed

### Requirement: Menu Option: Install With Demo Data

The system SHALL provide a menu option to install with demo data, visible only for Oro projects.

#### Scenario: Install with demo visible for Oro projects
- **WHEN** menu is displayed
- **AND** project is detected as Oro project
- **THEN** "Install with demo data" option SHALL be visible in Installation section

#### Scenario: Install with demo hidden for non-Oro projects
- **WHEN** menu is displayed
- **AND** project is NOT detected as Oro project
- **THEN** "Install with demo data" option SHALL NOT be displayed

### Requirement: Menu Option: Install Without Demo Data

The system SHALL provide a menu option to install without demo data, visible only for Oro projects.

#### Scenario: Install without demo visible for Oro projects
- **WHEN** menu is displayed
- **AND** project is detected as Oro project
- **THEN** "Install without demo data" option SHALL be visible in Installation section

#### Scenario: Install without demo hidden for non-Oro projects
- **WHEN** menu is displayed
- **AND** project is NOT detected as Oro project
- **THEN** "Install without demo data" option SHALL NOT be displayed

## ADDED Requirements

### Requirement: Menu Option: Re-build/Re-download Images

The system SHALL provide a menu option to rebuild or re-download application Docker images.

#### Scenario: Rebuild images from menu
- **WHEN** user selects option "6) Re-build/Re-download Images"
- **THEN** system SHALL execute `orodc image build` command
- **AND** user SHALL be prompted for cache usage
- **AND** after completion, menu SHALL return to main menu

### Requirement: Menu Option: Connect via CLI

The system SHALL provide a menu option to connect to the CLI container directly.

#### Scenario: Connect to CLI container
- **WHEN** user selects option "9) Connect via CLI"
- **AND** CLI service is running
- **THEN** system SHALL execute `orodc cli` command
- **AND** interactive CLI session SHALL be opened
- **WHEN** user exits CLI session
- **THEN** menu SHALL return to main menu

#### Scenario: Error when CLI service not running
- **WHEN** user selects option "9) Connect via CLI"
- **AND** CLI service is not running
- **THEN** error message SHALL be displayed
- **AND** menu SHALL return to main menu

### Requirement: Menu Option: Purge Database

The system SHALL provide a menu option to purge (drop and recreate) the database.

#### Scenario: Purge database with confirmation
- **WHEN** user selects option "12) Purge database"
- **THEN** warning message SHALL be displayed: "This will drop and recreate the database. All data will be lost."
- **AND** confirmation prompt SHALL be shown
- **WHEN** user confirms
- **THEN** system SHALL execute `orodc database purge`
- **AND** after completion, menu SHALL return to main menu
- **WHEN** user cancels
- **THEN** operation SHALL be cancelled
- **AND** menu SHALL return to main menu

### Requirement: Menu Option: Install Dependencies

The system SHALL provide a menu option to install application dependencies (composer and npm), visible only for Oro projects.

#### Scenario: Install dependencies visible for Oro projects
- **WHEN** menu is displayed
- **AND** project is detected as Oro project
- **THEN** "Install dependencies" option SHALL be visible

#### Scenario: Install dependencies hidden for non-Oro projects
- **WHEN** menu is displayed
- **AND** project is NOT detected as Oro project
- **THEN** "Install dependencies" option SHALL NOT be displayed

#### Scenario: Install dependencies executes composer and npm
- **WHEN** user selects option "19) Install dependencies"
- **THEN** system SHALL execute `composer install` via `orodc composer install`
- **AND** system SHALL execute `npm install` if `package.json` exists
- **AND** progress SHALL be displayed during installation
- **AND** after completion, menu SHALL return to main menu

### Requirement: Menu Input with Arrow Keys and Verbose Toggle

The system SHALL accept input via numbered selection, arrow key navigation, verbose toggle, and quit command.

#### Scenario: Accept number input
- **WHEN** user types a number between 1-21
- **AND** presses Enter
- **THEN** corresponding option SHALL be executed

#### Scenario: Accept arrow key navigation
- **WHEN** user presses ↑ or ↓ arrow keys
- **THEN** menu selection SHALL move accordingly
- **AND** menu SHALL be redrawn with highlighted selection
- **WHEN** user presses Enter
- **THEN** highlighted option SHALL be executed

#### Scenario: Toggle verbose mode
- **WHEN** user presses 'v' key
- **THEN** VERBOSE flag SHALL toggle between enabled/disabled
- **AND** menu SHALL display VERBOSE status in header
- **AND** subsequent commands SHALL respect VERBOSE setting

#### Scenario: Quit menu
- **WHEN** user presses 'q' or 'Q'
- **THEN** menu SHALL exit immediately
- **AND** program SHALL terminate with exit code 0

#### Scenario: Handle invalid input
- **WHEN** user enters invalid input (not 1-21, not v, not q)
- **THEN** menu SHALL be redrawn without error message
- **AND** user SHALL be prompted again
