## ADDED Requirements

### Requirement: Plugin Discovery via JSON Manifest
The system SHALL discover plugins from Homebrew formulas and load their JSON manifests to determine detection rules.

#### Scenario: Scan for plugin formulas
- **WHEN** DCX initializes
- **THEN** it SHALL scan for Homebrew formulas matching pattern `dcx-plugin-*`
- **AND** for each formula it SHALL look for `plugin.json` in share directory
- **AND** it SHALL validate JSON syntax before loading
- **AND** invalid manifests SHALL be logged and skipped

#### Scenario: Plugin search paths
- **WHEN** searching for plugins
- **THEN** it SHALL search in priority order:
  1. `${PWD}/.dcx/plugins/` (project-local plugins)
  2. `${HOME}/.dcx/plugins/` (user plugins)
  3. `${HOMEBREW_PREFIX}/share/dcx-plugin-*/` (Homebrew plugins)
  4. `${DCX_SHARE_DIR}/plugins/` (built-in plugins)
- **AND** first valid manifest found SHALL be used

#### Scenario: Load plugin manifest
- **WHEN** plugin directory is found
- **THEN** it SHALL read `plugin.json` file
- **AND** it SHALL extract: name, version, description, detection rules
- **AND** it SHALL validate required fields exist
- **AND** invalid manifests SHALL fail gracefully with error message

### Requirement: Framework Detection via Dependencies File
The system SHALL detect frameworks by analyzing dependency files (composer.json, package.json, requirements.txt).

#### Scenario: Detect by Composer packages
- **WHEN** plugin manifest specifies `detection.rules.type="composer_packages"`
- **THEN** it SHALL check if `composer.json` exists in project
- **AND** it SHALL parse JSON and extract `require` and `require-dev` sections
- **AND** it SHALL match against packages list from manifest
- **AND** if match mode is "any", one match is sufficient
- **AND** if match mode is "all", all packages must be present

#### Scenario: Detect by npm packages
- **WHEN** plugin manifest specifies `detection.rules.type="npm_packages"`
- **THEN** it SHALL check if `package.json` exists
- **AND** it SHALL parse JSON and extract `dependencies` and `devDependencies`
- **AND** it SHALL match against packages list from manifest

#### Scenario: Detect by Python requirements
- **WHEN** plugin manifest specifies `detection.rules.type="pip_packages"`
- **THEN** it SHALL check if `requirements.txt` exists
- **AND** it SHALL parse file line by line
- **AND** it SHALL match package names against manifest list
- **AND** version constraints SHALL be ignored for detection

### Requirement: Framework Detection via File Structure
The system SHALL detect frameworks by checking for existence of specific files and directories.

#### Scenario: Detect by file existence
- **WHEN** plugin manifest specifies `detection.rules.type="file_exists"`
- **THEN** it SHALL check if all listed files exist in project
- **AND** files SHALL be relative to project root
- **AND** both files and directories SHALL be supported
- **AND** if mode is "any", one existing file is sufficient
- **AND** if mode is "all", all files must exist

#### Scenario: Detect by directory structure
- **WHEN** plugin manifest specifies `detection.rules.type="directory_structure"`
- **THEN** it SHALL validate expected directory tree exists
- **AND** it SHALL check directories exist with correct paths
- **AND** missing directories SHALL result in no match

#### Scenario: Multiple file checks combined
- **WHEN** multiple file existence rules are specified
- **THEN** all rules SHALL be evaluated
- **AND** rules SHALL be combined with AND logic by default
- **AND** plugin SHALL match only if all file rules pass

### Requirement: Framework Detection via File Content
The system SHALL detect frameworks by analyzing content of specific files using patterns.

#### Scenario: Detect by pattern match in file
- **WHEN** plugin manifest specifies `detection.rules.type="file_content"`
- **THEN** it SHALL read specified file from project
- **AND** it SHALL search for patterns using grep
- **AND** patterns SHALL support regex syntax
- **AND** if mode is "any", one pattern match is sufficient
- **AND** if mode is "all", all patterns must match

#### Scenario: Detect by JSON field value
- **WHEN** plugin manifest specifies `detection.rules.type="json_field"`
- **THEN** it SHALL parse JSON file using jq
- **AND** it SHALL extract value at specified JSON path
- **AND** it SHALL compare value against expected value or pattern
- **AND** comparison SHALL support: equals, contains, regex

#### Scenario: Multiple content checks
- **WHEN** multiple file content rules are specified
- **THEN** each file SHALL be checked independently
- **AND** results SHALL be combined with AND logic
- **AND** plugin SHALL match only if all content rules pass

### Requirement: Detection Rule Priority and Scoring
The system SHALL use priority values to select the best matching plugin when multiple plugins match.

#### Scenario: Plugin priority ordering
- **WHEN** multiple plugins match current project
- **THEN** it SHALL use `detection.priority` value from manifest
- **AND** higher priority number SHALL be preferred
- **AND** if priorities are equal, first discovered SHALL be used
- **AND** priority SHALL be integer from 0 to 100

#### Scenario: No plugin matches
- **WHEN** no plugins match current project
- **THEN** it SHALL use "generic" fallback plugin
- **AND** generic plugin SHALL provide basic PHP/Node functionality
- **AND** warning SHALL be logged about no specific plugin detected

#### Scenario: Explicit plugin selection
- **WHEN** DCX_PLUGIN environment variable is set
- **THEN** it SHALL skip auto-detection
- **AND** it SHALL load specified plugin directly
- **AND** if specified plugin doesn't exist, it SHALL error
- **AND** this SHALL allow overriding auto-detection

### Requirement: Plugin Manifest Validation
The system SHALL validate plugin manifests to ensure they are well-formed and contain required information.

#### Scenario: Validate required manifest fields
- **WHEN** loading plugin manifest
- **THEN** it SHALL verify these required fields exist:
  - name (string, valid identifier)
  - version (string, semver format)
  - description (string, non-empty)
  - detection.rules (array, at least one rule)
- **AND** missing required fields SHALL cause validation error

#### Scenario: Validate detection rules structure
- **WHEN** validating detection rules
- **THEN** each rule SHALL have `type` field
- **AND** type SHALL be one of: composer_packages, npm_packages, pip_packages, file_exists, directory_structure, file_content, json_field
- **AND** each rule SHALL have required fields for its type
- **AND** invalid rule types SHALL cause validation error

#### Scenario: Validate plugin dependencies
- **WHEN** manifest specifies requirements
- **THEN** it SHALL check DCX version compatibility
- **AND** if DCX version < required version, plugin SHALL be skipped
- **AND** warning SHALL be logged about version incompatibility

### Requirement: Plugin Detection Commands
The system SHALL provide CLI commands to inspect plugin detection and troubleshoot issues.

#### Scenario: List all installed plugins
- **WHEN** user runs `dcx plugins list`
- **THEN** it SHALL show all discovered plugins with:
  - Plugin name
  - Version
  - Description
  - Installation path
  - Detection priority
- **AND** currently active plugin SHALL be marked

#### Scenario: Show plugin information
- **WHEN** user runs `dcx plugins info <name>`
- **THEN** it SHALL display full plugin manifest
- **AND** it SHALL show detection rules in human-readable format
- **AND** it SHALL show provided commands and services
- **AND** it SHALL show requirements (DCX, PHP, Node versions)

#### Scenario: Detect framework for current project
- **WHEN** user runs `dcx plugins detect`
- **THEN** it SHALL run detection logic for all plugins
- **AND** it SHALL show which plugins matched
- **AND** it SHALL show which detection rules triggered
- **AND** it SHALL show selected plugin with reasoning
- **AND** this SHALL help troubleshoot detection issues

#### Scenario: Validate plugin manifest
- **WHEN** user runs `dcx plugins validate <name>`
- **THEN** it SHALL load plugin manifest
- **AND** it SHALL validate JSON syntax
- **AND** it SHALL validate required fields
- **AND** it SHALL validate detection rules structure
- **AND** it SHALL validate command scripts exist
- **AND** it SHALL report validation results


