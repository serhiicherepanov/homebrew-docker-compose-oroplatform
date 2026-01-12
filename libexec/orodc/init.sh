#!/bin/bash
set -e
if [ "$DEBUG" ]; then set -x; fi

# Determine script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/ui.sh"

msg_header "OroDC Interactive Configuration"
msg_info "This will help you configure services for your project"
echo ""

ENV_FILE=".env.orodc"

# Load existing configuration if available
EXISTING_PHP_VERSION=""
EXISTING_NODE_VERSION=""
EXISTING_COMPOSER_VERSION=""
EXISTING_PHP_IMAGE=""
EXISTING_DB_SCHEMA=""
EXISTING_DB_VERSION=""
EXISTING_DB_IMAGE=""
EXISTING_SEARCH_ENGINE=""
EXISTING_SEARCH_VERSION=""
EXISTING_SEARCH_IMAGE=""
EXISTING_CACHE_ENGINE=""
EXISTING_CACHE_VERSION=""
EXISTING_CACHE_IMAGE=""
EXISTING_RABBITMQ_VERSION=""
EXISTING_RABBITMQ_IMAGE=""

if [[ -f "$ENV_FILE" ]]; then
  msg_info "Found existing configuration, loading current values..."
  
  # Source the file to load variables
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    
    # Remove quotes if present
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    
    case "$key" in
      DC_ORO_PHP_VERSION) EXISTING_PHP_VERSION="$value" ;;
      DC_ORO_NODE_VERSION) EXISTING_NODE_VERSION="$value" ;;
      DC_ORO_COMPOSER_VERSION) EXISTING_COMPOSER_VERSION="$value" ;;
      DC_ORO_PHP_IMAGE) EXISTING_PHP_IMAGE="$value" ;;
      DC_ORO_DATABASE_SCHEMA) EXISTING_DB_SCHEMA="$value" ;;
      DC_ORO_DATABASE_VERSION) EXISTING_DB_VERSION="$value" ;;
      DC_ORO_DATABASE_IMAGE) EXISTING_DB_IMAGE="$value" ;;
      DC_ORO_SEARCH_ENGINE) EXISTING_SEARCH_ENGINE="$value" ;;
      DC_ORO_SEARCH_VERSION) EXISTING_SEARCH_VERSION="$value" ;;
      DC_ORO_SEARCH_IMAGE) EXISTING_SEARCH_IMAGE="$value" ;;
      DC_ORO_CACHE_ENGINE) EXISTING_CACHE_ENGINE="$value" ;;
      DC_ORO_CACHE_VERSION) EXISTING_CACHE_VERSION="$value" ;;
      DC_ORO_CACHE_IMAGE) EXISTING_CACHE_IMAGE="$value" ;;
      DC_ORO_RABBITMQ_VERSION) EXISTING_RABBITMQ_VERSION="$value" ;;
      DC_ORO_RABBITMQ_IMAGE) EXISTING_RABBITMQ_IMAGE="$value" ;;
    esac
  done < "$ENV_FILE"
  
  echo ""
fi

# 1. PHP Configuration
echo ""
msg_header "1. PHP Configuration"

# Determine if using custom image
USE_CUSTOM_PHP=false
if [[ -n "$EXISTING_PHP_IMAGE" ]] && [[ ! "$EXISTING_PHP_IMAGE" =~ ^ghcr\.io/digitalspacestdio/orodc-php-node-symfony: ]]; then
  USE_CUSTOM_PHP=true
fi

if prompt_yes_no "Use custom PHP image?" "$([ "$USE_CUSTOM_PHP" = true ] && echo yes || echo no)"; then
  >&2 echo -n "Enter custom PHP image$([ -n "$EXISTING_PHP_IMAGE" ] && echo " [current: $EXISTING_PHP_IMAGE]" || echo ""): "
  read SELECTED_PHP_IMAGE </dev/tty
  # If empty, keep existing
  if [[ -z "$SELECTED_PHP_IMAGE" ]] && [[ -n "$EXISTING_PHP_IMAGE" ]]; then
    SELECTED_PHP_IMAGE="$EXISTING_PHP_IMAGE"
  fi
  # Extract versions from custom image if possible (or use defaults/existing)
  SELECTED_PHP="${EXISTING_PHP_VERSION:-8.4}"
  SELECTED_NODE="${EXISTING_NODE_VERSION:-22}"
  SELECTED_COMPOSER="${EXISTING_COMPOSER_VERSION:-2}"
else
  # Select PHP version (sorted newest to oldest)
  PHP_VERSIONS=("8.5" "8.4" "8.3" "8.2" "8.1" "7.4" "7.3")
  DEFAULT_PHP="${EXISTING_PHP_VERSION:-8.4}"
  SELECTED_PHP=$(prompt_select "Select PHP version:" "$DEFAULT_PHP" "${PHP_VERSIONS[@]}")
  
  if [[ -n "${DEBUG:-}" ]]; then
    >&2 echo "DEBUG: Selected PHP: '$SELECTED_PHP'"
  fi
  
  # Select Node.js version (based on PHP compatibility)
  read -ra COMPATIBLE_NODE_VERSIONS <<< "$(get_compatible_node_versions "$SELECTED_PHP")"
  
  # Determine default Node.js version based on PHP or existing config
  if [[ -n "$EXISTING_NODE_VERSION" ]] && [[ " ${COMPATIBLE_NODE_VERSIONS[*]} " =~ " ${EXISTING_NODE_VERSION} " ]]; then
    DEFAULT_NODE="$EXISTING_NODE_VERSION"
  else
    case "$SELECTED_PHP" in
      8.5) DEFAULT_NODE="24" ;;
      8.4) DEFAULT_NODE="22" ;;
      8.1|8.2|8.3) DEFAULT_NODE="20" ;;
      7.3|7.4) DEFAULT_NODE="16" ;;
      *) DEFAULT_NODE="22" ;;
    esac
    
    # Ensure default is in compatible versions list
    if [[ ! " ${COMPATIBLE_NODE_VERSIONS[*]} " =~ " ${DEFAULT_NODE} " ]]; then
      DEFAULT_NODE="${COMPATIBLE_NODE_VERSIONS[0]}"
    fi
  fi
  
  SELECTED_NODE=$(prompt_select "Select Node.js version (compatible with PHP $SELECTED_PHP):" "$DEFAULT_NODE" "${COMPATIBLE_NODE_VERSIONS[@]}")
  
  if [[ -n "${DEBUG:-}" ]]; then
    >&2 echo "DEBUG: Selected Node.js: '$SELECTED_NODE'"
  fi
  
  # Select Composer version (only for PHP 7.3, others use Composer 2 automatically)
  if [[ "$SELECTED_PHP" == "7.3" ]]; then
    COMPOSER_VERSIONS=("1" "2")
    # Default Composer version for PHP 7.3
    if [[ -n "$EXISTING_COMPOSER_VERSION" ]]; then
      DEFAULT_COMPOSER="$EXISTING_COMPOSER_VERSION"
    else
      DEFAULT_COMPOSER="1"
    fi
    
    SELECTED_COMPOSER=$(prompt_select "Select Composer version:" "$DEFAULT_COMPOSER" "${COMPOSER_VERSIONS[@]}")
    
    if [[ -n "${DEBUG:-}" ]]; then
      >&2 echo "DEBUG: Selected Composer: '$SELECTED_COMPOSER'"
    fi
  else
    # PHP 7.4+ always uses Composer 2
    SELECTED_COMPOSER="2"
    if [[ -n "${DEBUG:-}" ]]; then
      >&2 echo "DEBUG: Using Composer 2 (automatic for PHP $SELECTED_PHP)"
    fi
  fi
  
  # Build default image name
  SELECTED_PHP_IMAGE="ghcr.io/digitalspacestdio/orodc-php-node-symfony:${SELECTED_PHP}-node${SELECTED_NODE}-composer${SELECTED_COMPOSER}-alpine"
fi

msg_info "PHP Image: $SELECTED_PHP_IMAGE"

# 2. Database Configuration
echo ""
msg_header "2. Database Configuration"

# Determine if using custom database image
USE_CUSTOM_DB=false
if [[ -n "$EXISTING_DB_IMAGE" ]] && [[ ! "$EXISTING_DB_IMAGE" =~ ^(ghcr\.io/digitalspacestdio/orodc-pgsql:|mysql:) ]]; then
  USE_CUSTOM_DB=true
fi

if prompt_yes_no "Use custom database image?" "$([ "$USE_CUSTOM_DB" = true ] && echo yes || echo no)"; then
  >&2 echo -n "Enter custom database image$([ -n "$EXISTING_DB_IMAGE" ] && echo " [current: $EXISTING_DB_IMAGE]" || echo ""): "
  read SELECTED_DB_IMAGE </dev/tty
  # If empty, keep existing
  if [[ -z "$SELECTED_DB_IMAGE" ]] && [[ -n "$EXISTING_DB_IMAGE" ]]; then
    SELECTED_DB_IMAGE="$EXISTING_DB_IMAGE"
  fi
  SELECTED_DB_SCHEMA="${EXISTING_DB_SCHEMA:-pgsql}"
  SELECTED_DB_VERSION="${EXISTING_DB_VERSION:-custom}"
else
  # Select database type based on existing or default
  DB_TYPES=("PostgreSQL" "MySQL")
  if [[ "$EXISTING_DB_SCHEMA" == "mysql" ]]; then
    DEFAULT_DB_TYPE="MySQL"
  else
    DEFAULT_DB_TYPE="PostgreSQL"
  fi
  SELECTED_DB_TYPE=$(prompt_select "Select database type:" "$DEFAULT_DB_TYPE" "${DB_TYPES[@]}")
  
  if [[ -n "${DEBUG:-}" ]]; then
    >&2 echo "DEBUG: Selected DB type: '$SELECTED_DB_TYPE'"
  fi
  
  # Select version based on type (sorted newest to oldest)
  if [[ "$SELECTED_DB_TYPE" == "PostgreSQL" ]]; then
    PGSQL_VERSIONS=("17.4" "16.6" "15.1")
    # Only use existing version if it's valid for PostgreSQL and schema hasn't changed
    if [[ "$EXISTING_DB_SCHEMA" == "pgsql" ]] && [[ " ${PGSQL_VERSIONS[*]} " =~ " ${EXISTING_DB_VERSION} " ]]; then
      DEFAULT_PGSQL_VERSION="$EXISTING_DB_VERSION"
    else
      DEFAULT_PGSQL_VERSION="17.4"
    fi
    SELECTED_DB_VERSION=$(prompt_select "Select PostgreSQL version:" "$DEFAULT_PGSQL_VERSION" "${PGSQL_VERSIONS[@]}")
    SELECTED_DB_SCHEMA="pgsql"
    SELECTED_DB_IMAGE="ghcr.io/digitalspacestdio/orodc-pgsql:${SELECTED_DB_VERSION}"
  else
    MYSQL_VERSIONS=("9.0" "8.4" "8.0" "5.7")
    # Only use existing version if it's valid for MySQL and schema hasn't changed
    if [[ "$EXISTING_DB_SCHEMA" == "mysql" ]] && [[ " ${MYSQL_VERSIONS[*]} " =~ " ${EXISTING_DB_VERSION} " ]]; then
      DEFAULT_MYSQL_VERSION="$EXISTING_DB_VERSION"
    else
      DEFAULT_MYSQL_VERSION="9.0"
    fi
    SELECTED_DB_VERSION=$(prompt_select "Select MySQL version:" "$DEFAULT_MYSQL_VERSION" "${MYSQL_VERSIONS[@]}")
    SELECTED_DB_SCHEMA="mysql"
    SELECTED_DB_IMAGE="mysql:${SELECTED_DB_VERSION}"
  fi
fi

msg_info "Database Image: $SELECTED_DB_IMAGE"

# 3. Search Engine Configuration
echo ""
msg_header "3. Search Engine Configuration"

# Determine if using custom search image
USE_CUSTOM_SEARCH=false
if [[ -n "$EXISTING_SEARCH_IMAGE" ]] && [[ ! "$EXISTING_SEARCH_IMAGE" =~ ^(docker\.elastic\.co/elasticsearch/elasticsearch:|opensearchproject/opensearch:) ]]; then
  USE_CUSTOM_SEARCH=true
fi

if prompt_yes_no "Use custom search engine image?" "$([ "$USE_CUSTOM_SEARCH" = true ] && echo yes || echo no)"; then
  >&2 echo -n "Enter custom search image$([ -n "$EXISTING_SEARCH_IMAGE" ] && echo " [current: $EXISTING_SEARCH_IMAGE]" || echo ""): "
  read SELECTED_SEARCH_IMAGE </dev/tty
  # If empty, keep existing
  if [[ -z "$SELECTED_SEARCH_IMAGE" ]] && [[ -n "$EXISTING_SEARCH_IMAGE" ]]; then
    SELECTED_SEARCH_IMAGE="$EXISTING_SEARCH_IMAGE"
  fi
  SELECTED_SEARCH_TYPE="${EXISTING_SEARCH_ENGINE:-Custom}"
  SELECTED_SEARCH_VERSION="${EXISTING_SEARCH_VERSION:-custom}"
else
  # Select search engine type based on existing or default
  SEARCH_TYPES=("Elasticsearch" "OpenSearch")
  DEFAULT_SEARCH_TYPE="${EXISTING_SEARCH_ENGINE:-Elasticsearch}"
  SELECTED_SEARCH_TYPE=$(prompt_select "Select search engine:" "$DEFAULT_SEARCH_TYPE" "${SEARCH_TYPES[@]}")
  
  # Select version based on type (sorted newest to oldest)
  if [[ "$SELECTED_SEARCH_TYPE" == "Elasticsearch" ]]; then
    ELASTIC_VERSIONS=("8.15.0" "8.10.3" "7.17.0")
    # Only use existing version if it's valid for Elasticsearch and type hasn't changed
    if [[ "$EXISTING_SEARCH_ENGINE" == "Elasticsearch" ]] && [[ " ${ELASTIC_VERSIONS[*]} " =~ " ${EXISTING_SEARCH_VERSION} " ]]; then
      DEFAULT_ELASTIC_VERSION="$EXISTING_SEARCH_VERSION"
    else
      DEFAULT_ELASTIC_VERSION="8.15.0"
    fi
    SELECTED_SEARCH_VERSION=$(prompt_select "Select Elasticsearch version:" "$DEFAULT_ELASTIC_VERSION" "${ELASTIC_VERSIONS[@]}")
    SELECTED_SEARCH_IMAGE="docker.elastic.co/elasticsearch/elasticsearch:${SELECTED_SEARCH_VERSION}"
  else
    OPENSEARCH_VERSIONS=("2.15.0" "2.11.0" "1.3.0")
    # Only use existing version if it's valid for OpenSearch and type hasn't changed
    if [[ "$EXISTING_SEARCH_ENGINE" == "OpenSearch" ]] && [[ " ${OPENSEARCH_VERSIONS[*]} " =~ " ${EXISTING_SEARCH_VERSION} " ]]; then
      DEFAULT_OPENSEARCH_VERSION="$EXISTING_SEARCH_VERSION"
    else
      DEFAULT_OPENSEARCH_VERSION="2.15.0"
    fi
    SELECTED_SEARCH_VERSION=$(prompt_select "Select OpenSearch version:" "$DEFAULT_OPENSEARCH_VERSION" "${OPENSEARCH_VERSIONS[@]}")
    SELECTED_SEARCH_IMAGE="opensearchproject/opensearch:${SELECTED_SEARCH_VERSION}"
  fi
fi

msg_info "Search Image: $SELECTED_SEARCH_IMAGE"

# 4. Cache Configuration
echo ""
msg_header "4. Cache Configuration"

# Determine if using custom cache image
USE_CUSTOM_CACHE=false
if [[ -n "$EXISTING_CACHE_IMAGE" ]] && [[ ! "$EXISTING_CACHE_IMAGE" =~ ^(redis:|eqalpha/keydb:) ]]; then
  USE_CUSTOM_CACHE=true
fi

if prompt_yes_no "Use custom cache image?" "$([ "$USE_CUSTOM_CACHE" = true ] && echo yes || echo no)"; then
  >&2 echo -n "Enter custom cache image$([ -n "$EXISTING_CACHE_IMAGE" ] && echo " [current: $EXISTING_CACHE_IMAGE]" || echo ""): "
  read SELECTED_CACHE_IMAGE </dev/tty
  # If empty, keep existing
  if [[ -z "$SELECTED_CACHE_IMAGE" ]] && [[ -n "$EXISTING_CACHE_IMAGE" ]]; then
    SELECTED_CACHE_IMAGE="$EXISTING_CACHE_IMAGE"
  fi
  SELECTED_CACHE_TYPE="${EXISTING_CACHE_ENGINE:-Custom}"
  SELECTED_CACHE_VERSION="${EXISTING_CACHE_VERSION:-custom}"
else
  # Select cache engine type based on existing or default
  CACHE_TYPES=("Redis" "KeyDB")
  DEFAULT_CACHE_TYPE="${EXISTING_CACHE_ENGINE:-Redis}"
  SELECTED_CACHE_TYPE=$(prompt_select "Select cache engine:" "$DEFAULT_CACHE_TYPE" "${CACHE_TYPES[@]}")
  
  # Select version based on type (sorted newest to oldest)
  if [[ "$SELECTED_CACHE_TYPE" == "Redis" ]]; then
    REDIS_VERSIONS=("7.4" "7.2" "6.2")
    # Only use existing version if it's valid for Redis and type hasn't changed
    if [[ "$EXISTING_CACHE_ENGINE" == "Redis" ]] && [[ " ${REDIS_VERSIONS[*]} " =~ " ${EXISTING_CACHE_VERSION} " ]]; then
      DEFAULT_REDIS_VERSION="$EXISTING_CACHE_VERSION"
    else
      DEFAULT_REDIS_VERSION="7.4"
    fi
    SELECTED_CACHE_VERSION=$(prompt_select "Select Redis version:" "$DEFAULT_REDIS_VERSION" "${REDIS_VERSIONS[@]}")
    SELECTED_CACHE_IMAGE="redis:${SELECTED_CACHE_VERSION}-alpine"
  else
    KEYDB_VERSIONS=("6.3.4" "6.3.3")
    # Only use existing version if it's valid for KeyDB and type hasn't changed
    if [[ "$EXISTING_CACHE_ENGINE" == "KeyDB" ]] && [[ " ${KEYDB_VERSIONS[*]} " =~ " ${EXISTING_CACHE_VERSION} " ]]; then
      DEFAULT_KEYDB_VERSION="$EXISTING_CACHE_VERSION"
    else
      DEFAULT_KEYDB_VERSION="6.3.4"
    fi
    SELECTED_CACHE_VERSION=$(prompt_select "Select KeyDB version:" "$DEFAULT_KEYDB_VERSION" "${KEYDB_VERSIONS[@]}")
    SELECTED_CACHE_IMAGE="eqalpha/keydb:alpine_x86_64_v${SELECTED_CACHE_VERSION}"
  fi
fi

msg_info "Cache Image: $SELECTED_CACHE_IMAGE"

# 5. RabbitMQ Configuration
echo ""
msg_header "5. RabbitMQ Configuration"

# Determine if using custom RabbitMQ image
USE_CUSTOM_RABBITMQ=false
if [[ -n "$EXISTING_RABBITMQ_IMAGE" ]] && [[ ! "$EXISTING_RABBITMQ_IMAGE" =~ ^rabbitmq: ]]; then
  USE_CUSTOM_RABBITMQ=true
fi

if prompt_yes_no "Use custom RabbitMQ image?" "$([ "$USE_CUSTOM_RABBITMQ" = true ] && echo yes || echo no)"; then
  >&2 echo -n "Enter custom RabbitMQ image$([ -n "$EXISTING_RABBITMQ_IMAGE" ] && echo " [current: $EXISTING_RABBITMQ_IMAGE]" || echo ""): "
  read SELECTED_RABBITMQ_IMAGE </dev/tty
  # If empty, keep existing
  if [[ -z "$SELECTED_RABBITMQ_IMAGE" ]] && [[ -n "$EXISTING_RABBITMQ_IMAGE" ]]; then
    SELECTED_RABBITMQ_IMAGE="$EXISTING_RABBITMQ_IMAGE"
  fi
  SELECTED_RABBITMQ_VERSION="${EXISTING_RABBITMQ_VERSION:-custom}"
else
  # Select RabbitMQ version based on existing or default
  RABBITMQ_VERSIONS=("3.13" "3.12" "3.11")
  DEFAULT_RABBITMQ_VERSION="${EXISTING_RABBITMQ_VERSION:-3.13}"
  SELECTED_RABBITMQ_VERSION=$(prompt_select "Select RabbitMQ version:" "$DEFAULT_RABBITMQ_VERSION" "${RABBITMQ_VERSIONS[@]}")
  SELECTED_RABBITMQ_IMAGE="rabbitmq:${SELECTED_RABBITMQ_VERSION}-management-alpine"
fi

msg_info "RabbitMQ Image: $SELECTED_RABBITMQ_IMAGE"

# Summary
echo ""
msg_header "Configuration Summary"
echo "PHP Version: $SELECTED_PHP"
echo "Node.js Version: $SELECTED_NODE"
echo "Composer Version: $SELECTED_COMPOSER"
echo "PHP Image: $SELECTED_PHP_IMAGE"
echo "Database: $SELECTED_DB_TYPE $SELECTED_DB_VERSION"
echo "Database Image: $SELECTED_DB_IMAGE"
echo "Search Engine: $SELECTED_SEARCH_TYPE $SELECTED_SEARCH_VERSION"
echo "Search Image: $SELECTED_SEARCH_IMAGE"
echo "Cache: $SELECTED_CACHE_TYPE $SELECTED_CACHE_VERSION"
echo "Cache Image: $SELECTED_CACHE_IMAGE"
echo "RabbitMQ: $SELECTED_RABBITMQ_VERSION"
echo "RabbitMQ Image: $SELECTED_RABBITMQ_IMAGE"
echo ""

if prompt_yes_no "Save configuration to $ENV_FILE?" "yes"; then
  # Create backup if file exists
  if [[ -f "$ENV_FILE" ]]; then
    cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    msg_info "Backup created: ${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
  else
    # Create new file with header
    cat > "$ENV_FILE" << EOF
# OroDC Configuration
# Generated by 'orodc init' on $(date)

EOF
  fi
  
  # Update configuration variables (preserves other variables)
  msg_info "Updating configuration..."
  
  # Update header comment if this is a new init
  if ! grep -q "# Last updated:" "$ENV_FILE" 2>/dev/null; then
    sed -i.tmp "1i# Last updated: $(date)" "$ENV_FILE"
    rm -f "${ENV_FILE}.tmp"
  else
    sed -i.tmp "s|^# Last updated:.*|# Last updated: $(date)|" "$ENV_FILE"
    rm -f "${ENV_FILE}.tmp"
  fi
  
  # PHP Configuration
  update_env_var "$ENV_FILE" "DC_ORO_PHP_VERSION" "$SELECTED_PHP"
  update_env_var "$ENV_FILE" "DC_ORO_NODE_VERSION" "$SELECTED_NODE"
  update_env_var "$ENV_FILE" "DC_ORO_COMPOSER_VERSION" "$SELECTED_COMPOSER"
  update_env_var "$ENV_FILE" "DC_ORO_PHP_IMAGE" "$SELECTED_PHP_IMAGE"
  
  # Database Configuration
  update_env_var "$ENV_FILE" "DC_ORO_DATABASE_SCHEMA" "$SELECTED_DB_SCHEMA"
  update_env_var "$ENV_FILE" "DC_ORO_DATABASE_VERSION" "$SELECTED_DB_VERSION"
  update_env_var "$ENV_FILE" "DC_ORO_DATABASE_IMAGE" "$SELECTED_DB_IMAGE"
  
  # Search Engine Configuration
  update_env_var "$ENV_FILE" "DC_ORO_SEARCH_ENGINE" "$SELECTED_SEARCH_TYPE"
  update_env_var "$ENV_FILE" "DC_ORO_SEARCH_VERSION" "$SELECTED_SEARCH_VERSION"
  update_env_var "$ENV_FILE" "DC_ORO_SEARCH_IMAGE" "$SELECTED_SEARCH_IMAGE"
  
  # Cache Configuration
  update_env_var "$ENV_FILE" "DC_ORO_CACHE_ENGINE" "$SELECTED_CACHE_TYPE"
  update_env_var "$ENV_FILE" "DC_ORO_CACHE_VERSION" "$SELECTED_CACHE_VERSION"
  update_env_var "$ENV_FILE" "DC_ORO_CACHE_IMAGE" "$SELECTED_CACHE_IMAGE"
  
  # RabbitMQ Configuration
  update_env_var "$ENV_FILE" "DC_ORO_RABBITMQ_VERSION" "$SELECTED_RABBITMQ_VERSION"
  update_env_var "$ENV_FILE" "DC_ORO_RABBITMQ_IMAGE" "$SELECTED_RABBITMQ_IMAGE"
  
  msg_ok "Configuration saved to $ENV_FILE"
  msg_info "All other variables in the file were preserved"
  msg_info "You can now run 'orodc install' to set up your environment"
else
  msg_info "Configuration not saved"
fi
