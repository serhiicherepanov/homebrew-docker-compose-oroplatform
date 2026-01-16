#!/bin/bash
set -e
if [ "$DEBUG" ]; then set -x; fi

# Determine script directory and source libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
source "${SCRIPT_DIR}/../lib/ui.sh"
source "${SCRIPT_DIR}/../lib/environment.sh"

# Check that we're in a project
# Note: initialize_environment is called by router (bin/orodc) before routing to this script
check_in_project || exit 1

# Parse domain replacement flags
FROM_DOMAIN=""
TO_DOMAIN=""
REMAINING_ARGS=()

# Parse arguments for --from-domain and --to-domain
i=1
while [[ $i -le $# ]]; do
  arg="${!i}"
  next_i=$((i + 1))
  next_arg="${!next_i:-}"
  
  if [[ "$arg" == "--from-domain" ]] && [[ -n "$next_arg" ]]; then
    FROM_DOMAIN="$next_arg"
    i=$((i + 2))
  elif [[ "$arg" == "--to-domain" ]] && [[ -n "$next_arg" ]]; then
    TO_DOMAIN="$next_arg"
    i=$((i + 2))
  elif [[ "$arg" == --from-domain=* ]]; then
    FROM_DOMAIN="${arg#--from-domain=}"
    i=$((i + 1))
  elif [[ "$arg" == --to-domain=* ]]; then
    TO_DOMAIN="${arg#--to-domain=}"
    i=$((i + 1))
  else
    REMAINING_ARGS+=("$arg")
    i=$((i + 1))
  fi
done

# Parse remaining flags for left/right separation
parse_compose_flags "${REMAINING_ARGS[@]}"

# List available database dumps
list_database_dumps() {
  local project_dir="${DC_ORO_APPDIR:-$PWD}"
  local backup_dir="${project_dir}/var/backup"
  local var_dir="${project_dir}/var"

  local dumps=()

  # Check backup directory first
  if [[ -d "$backup_dir" ]]; then
    while IFS= read -r -d '' file; do
      dumps+=("$file")
    done < <(find "$backup_dir" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.sql.gz" \) -print0 2>/dev/null | sort -z)
  fi

  # Fallback to var/ directory if backup is empty
  if [[ ${#dumps[@]} -eq 0 ]] && [[ -d "$var_dir" ]]; then
    while IFS= read -r -d '' file; do
      dumps+=("$file")
    done < <(find "$var_dir" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.sql.gz" \) -print0 2>/dev/null | sort -z)
  fi

  if [[ ${#dumps[@]} -eq 0 ]]; then
    return 1
  fi

  printf '%s\n' "${dumps[@]}"
}

# Import database from var/backup/ folder or file path
import_database_interactive() {
  # Get first positional argument (dump file path)
  local dump_file_arg="${REMAINING_ARGS[0]:-}"
  
  # Check database schema is configured
  if [[ -z "${DC_ORO_DATABASE_SCHEMA:-}" ]]; then
    msg_error "Database schema not configured"
    echo "" >&2
    msg_info "To fix this issue, you can:" >&2
    echo "  1. Set DC_ORO_DATABASE_SCHEMA in .env.orodc (e.g., DC_ORO_DATABASE_SCHEMA=postgres or DC_ORO_DATABASE_SCHEMA=mysql)" >&2
    echo "  2. Set DC_ORO_DATABASE_PORT in .env.orodc (e.g., DC_ORO_DATABASE_PORT=5432 for PostgreSQL or 3306 for MySQL)" >&2
    echo "  3. Set ORO_DB_URL in .env-app or .env-app.local (e.g., postgres://user:pass@host:5432/db)" >&2
    echo "" >&2
    msg_info "Current configuration:" >&2
    echo "  DC_ORO_DATABASE_SCHEMA: ${DC_ORO_DATABASE_SCHEMA:-not set}" >&2
    echo "  DC_ORO_DATABASE_PORT: ${DC_ORO_DATABASE_PORT:-not set}" >&2
    echo "  ORO_DB_URL: ${ORO_DB_URL:-not set}" >&2
    echo "" >&2
    exit 1
  fi

  db_name="${DC_ORO_DATABASE_DBNAME:-oro_db}"
  
  # Require user to confirm dropping existing database before import
  echo "" >&2
  msg_danger "This will DELETE ALL DATA in database '${db_name}'!"
  if ! confirm_yes_no "Continue?"; then
    msg_info "Import cancelled" >&2
    exit 0
  fi
  
  # Stop and remove database container using docker compose
  stop_rm_cmd="${DOCKER_COMPOSE_BIN_CMD} stop database >/dev/null 2>&1 && ${DOCKER_COMPOSE_BIN_CMD} rm -f database >/dev/null 2>&1 || true"
  run_with_spinner "Stopping and removing database container" "$stop_rm_cmd" || true

  # Remove database volumes
  if [[ "${DC_ORO_DATABASE_SCHEMA}" == "postgres" ]]; then
    volume_name="${DC_ORO_NAME:-}_postgresql-data"
    run_with_spinner "Removing database volumes" "docker volume rm \"${volume_name}\" 2>/dev/null || true" || true
  elif [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]]; then
    volume_name="${DC_ORO_NAME:-}_mysql-data"
    run_with_spinner "Removing database volumes" "docker volume rm \"${volume_name}\" 2>/dev/null || true" || true
  fi

  # Recreate database container
  recreate_db_cmd="${DOCKER_COMPOSE_BIN_CMD} up -d database"
  run_with_spinner "Recreating database container" "$recreate_db_cmd" || exit $?

  # Wait for database to be ready and the specific database to exist
  if [[ "${DC_ORO_DATABASE_SCHEMA}" == "postgres" ]]; then
    wait_server_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm database-cli bash -c \"until PGPASSWORD=\\\$DC_ORO_DATABASE_PASSWORD psql -h \\\$DC_ORO_DATABASE_HOST -p \\\$DC_ORO_DATABASE_PORT -U \\\$DC_ORO_DATABASE_USER -d postgres -c 'SELECT 1' >/dev/null 2>&1; do sleep 1; done\""
    run_with_spinner "Waiting for PostgreSQL server" "$wait_server_cmd" || exit $?
    wait_db_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm database-cli bash -c \"until PGPASSWORD=\\\$DC_ORO_DATABASE_PASSWORD psql -h \\\$DC_ORO_DATABASE_HOST -p \\\$DC_ORO_DATABASE_PORT -U \\\$DC_ORO_DATABASE_USER -d ${db_name} -c 'SELECT 1' >/dev/null 2>&1; do sleep 1; done\""
  elif [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]]; then
    wait_server_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm database-cli bash -c \"until MYSQL_PWD=\\\$DC_ORO_DATABASE_PASSWORD mysqladmin -h \\\$DC_ORO_DATABASE_HOST -P \\\$DC_ORO_DATABASE_PORT -u \\\$DC_ORO_DATABASE_USER ping >/dev/null 2>&1; do sleep 1; done\""
    run_with_spinner "Waiting for MySQL server" "$wait_server_cmd" || exit $?
    wait_db_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm database-cli bash -c \"until MYSQL_PWD=\\\$DC_ORO_DATABASE_PASSWORD mysql -h \\\$DC_ORO_DATABASE_HOST -P \\\$DC_ORO_DATABASE_PORT -u \\\$DC_ORO_DATABASE_USER -e 'USE ${db_name}; SELECT 1' >/dev/null 2>&1; do sleep 1; done\""
  else
    msg_error "Unknown database schema: ${DC_ORO_DATABASE_SCHEMA}"
    exit 1
  fi
  
  run_with_spinner "Waiting for database '${db_name}'" "$wait_db_cmd" || exit $?
  
  msg_ok "Database container recreated successfully"
  echo "" >&2
  
  # Build domain replacement sed command
  build_domain_replace_sed
  
  # Use existing importdb logic
  DB_DUMP="$selected_file"
  DB_DUMP_BASENAME=$(echo "${DB_DUMP##*/}")

  if [[ $DC_ORO_DATABASE_SCHEMA == "pdo_pgsql" ]] || [[ $DC_ORO_DATABASE_SCHEMA == "postgres" ]];then
    DB_IMPORT_CMD="sed -E 's/[Oo][Ww][Nn][Ee][Rr]:[[:space:]]*[a-zA-Z0-9_]+/Owner: '\$DC_ORO_DATABASE_USER'/g' | sed -E 's/[Oo][Ww][Nn][Ee][Rr][[:space:]]+[Tt][Oo][[:space:]]+[a-zA-Z0-9_]+/OWNER TO '\$DC_ORO_DATABASE_USER'/g' | sed -E 's/[Ff][Oo][Rr][[:space:]]+[Rr][Oo][Ll][Ee][[:space:]]+[a-zA-Z0-9_]+/FOR ROLE '\$DC_ORO_DATABASE_USER'/g' | sed -E 's/[Tt][Oo][[:space:]]+[a-zA-Z0-9_]+;/TO '\$DC_ORO_DATABASE_USER';/g' | sed -E '/^[[:space:]]*[Rr][Ee][Vv][Oo][Kk][Ee][[:space:]]+[Aa][Ll][Ll]/d' | sed -e '/SET transaction_timeout = 0;/d' | sed -E '/[\\]restrict|[\\]unrestrict/d' | PGPASSWORD=\$DC_ORO_DATABASE_PASSWORD psql --set ON_ERROR_STOP=on -h \$DC_ORO_DATABASE_HOST -p \$DC_ORO_DATABASE_PORT -U \$DC_ORO_DATABASE_USER -d \$DC_ORO_DATABASE_DBNAME -1 >/dev/null"
  elif [[ "${DC_ORO_DATABASE_SCHEMA}" == "pdo_mysql" ]] || [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]];then
    DB_IMPORT_CMD="sed -E 's/[Dd][Ee][Ff][Ii][Nn][Ee][Rr][ ]*=[ ]*[^*]*\*/DEFINER=CURRENT_USER \*/' | MYSQL_PWD=\$DC_ORO_DATABASE_PASSWORD mysql -h\$DC_ORO_DATABASE_HOST -P\$DC_ORO_DATABASE_PORT -u\$DC_ORO_DATABASE_USER \$DC_ORO_DATABASE_DBNAME"
  fi

  if echo ${DB_DUMP_BASENAME} | grep -i 'sql\.gz$' > /dev/null; then
    DB_IMPORT_CMD="zcat ${DB_DUMP_BASENAME} | ${DOMAIN_REPLACE_SED} sed -E 's/^[[:space:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn]/CREATE OR REPLACE FUNCTION/g' | ${DB_IMPORT_CMD}"
  else
    DB_IMPORT_CMD="cat /${DB_DUMP_BASENAME} | ${DOMAIN_REPLACE_SED} sed -E 's/^[[:space:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn]/CREATE OR REPLACE FUNCTION/g' | ${DB_IMPORT_CMD}"
  fi

  # Show import details (context information)
  msg_info "From: $DB_DUMP"
  msg_info "File size: $(du -h "$DB_DUMP" | cut -f1)"
  msg_info "Database: $DC_ORO_DATABASE_HOST:$DC_ORO_DATABASE_PORT/$DC_ORO_DATABASE_DBNAME"

  import_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} run --quiet -i --rm -v \"${DB_DUMP}:/${DB_DUMP_BASENAME}\" database-cli bash -c \"$DB_IMPORT_CMD\""
  run_with_spinner "Importing database" "$import_cmd" || return $?

  msg_ok "Database imported successfully"
}

# Import database from var/backup/ folder or file path (interactive mode)
import_database_interactive() {
  # Prompt for domain replacement (interactive mode)
  prompt_domain_replacement "true"
  
  # Use project directory, fallback to current directory
  local project_dir="${DC_ORO_APPDIR:-$PWD}"
  local backup_dir="${project_dir}/var/backup"
  local var_dir="${project_dir}/var"
  local dumps=()
  local dump_files=()

  local selected_file=""

  # If file path provided as argument, use it directly
  if [[ -n "$dump_file_arg" ]]; then
    if [[ -r "$dump_file_arg" ]]; then
      selected_file=$(realpath "$dump_file_arg")
    elif [[ -r "${project_dir}/${dump_file_arg}" ]]; then
      selected_file=$(realpath "${project_dir}/${dump_file_arg}")
    elif [[ -r "${backup_dir}/${dump_file_arg}" ]]; then
      selected_file=$(realpath "${backup_dir}/${dump_file_arg}")
    elif [[ -r "${var_dir}/${dump_file_arg}" ]]; then
      selected_file=$(realpath "${var_dir}/${dump_file_arg}")
    else
      msg_error "File not found or not readable: $dump_file_arg"
      return 1
    fi
  fi

  # If no file selected yet, try to find dumps and show interactive menu
  if [[ -z "$selected_file" ]]; then
    # Get dumps using list_database_dumps (checks var/backup/ first, then var/)
    while IFS= read -r file; do
      if [[ -n "$file" ]]; then
        dumps+=("$file")
        dump_files+=("$file")
      fi
    done < <(list_database_dumps 2>/dev/null || true)

    if [[ ${#dumps[@]} -gt 0 ]]; then
    echo "" >&2
    msg_header "Available Database Dumps"
    echo "" >&2
    local i=1
    for dump in "${dumps[@]}"; do
      local basename_dump
      basename_dump=$(basename "$dump")
      local size
      size=$(du -h "$dump" 2>/dev/null | cut -f1)
      printf "  %2d) %s (%s)\n" "$i" "$basename_dump" "$size" >&2
      i=$((i + 1))
    done
    echo "" >&2
    echo -n "Select dump number or enter file path: " >&2
    read -r input

    if [[ "$input" =~ ^[0-9]+$ ]] && [[ $input -ge 1 ]] && [[ $input -le ${#dumps[@]} ]]; then
      selected_file="${dumps[$((input - 1))]}"
    elif [[ -n "$input" ]]; then
      # Try as file path
      if [[ -r "$input" ]]; then
        selected_file=$(realpath "$input")
      elif [[ -r "${project_dir}/${input}" ]]; then
        selected_file=$(realpath "${project_dir}/${input}")
      elif [[ -r "${backup_dir}/${input}" ]]; then
        selected_file=$(realpath "${backup_dir}/${input}")
      elif [[ -r "${var_dir}/${input}" ]]; then
        selected_file=$(realpath "${var_dir}/${input}")
      else
        msg_error "File not found or not readable: $input"
        return 1
      fi
    else
      msg_error "No selection made"
      return 1
    fi
    else
      echo -n "Enter database dump file path: " >&2
      read -r input

      if [[ -z "$input" ]]; then
        msg_error "No file provided"
        return 1
      fi

      if [[ -r "$input" ]]; then
        selected_file=$(realpath "$input")
      elif [[ -r "${backup_dir}/${input}" ]]; then
        selected_file=$(realpath "${backup_dir}/${input}")
      elif [[ -r "${var_dir}/${input}" ]]; then
        selected_file=$(realpath "${var_dir}/${input}")
      elif [[ -r "${project_dir}/${input}" ]]; then
        selected_file=$(realpath "${project_dir}/${input}")
      else
        msg_error "File not found or not readable: $input"
        return 1
      fi
    fi
  fi

  if [[ -z "$selected_file" ]] || [[ ! -r "$selected_file" ]]; then
    msg_error "Invalid file: $selected_file"
    return 1
  fi

  # Use existing importdb logic
  DB_DUMP="$selected_file"
  DB_DUMP_BASENAME="${DB_DUMP##*/}"

  # Get database connection parameters
  # Use values from environment variables (set by parse_dsn_uri or .env files)
  # Fallback to defaults only if not set
  local db_host="${DC_ORO_DATABASE_HOST:-database}"
  local db_user="${DC_ORO_DATABASE_USER:-oro_db_user}"
  local db_password="${DC_ORO_DATABASE_PASSWORD:-oro_db_pass}"
  local db_name="${DC_ORO_DATABASE_DBNAME:-oro_db}"
  
  # Determine port based on schema (with fallback)
  local db_port="${DC_ORO_DATABASE_PORT:-}"
  if [[ -z "$db_port" ]]; then
    if [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]] || [[ "${DC_ORO_DATABASE_SCHEMA}" == "pdo_mysql" ]]; then
      db_port="3306"
    else
      db_port="5432"  # Default to PostgreSQL
    fi
  fi

  # Validate domain format (alphanumeric, dots, hyphens, underscores only)
  validate_domain() {
    local domain="$1"
    # Check if domain contains only allowed characters: letters, numbers, dots, hyphens, underscores
    # Also check it doesn't contain dangerous characters like quotes, semicolons, etc.
    if [[ ! "$domain" =~ ^[a-zA-Z0-9._-]+$ ]]; then
      return 1
    fi
    # Check domain has at least one dot (for TLD) or is a valid local domain
    if [[ ! "$domain" =~ \. ]] && [[ ! "$domain" =~ \.local$ ]] && [[ ! "$domain" =~ ^localhost$ ]]; then
      return 1
    fi
    # Check domain doesn't start or end with dot or hyphen
    if [[ "$domain" =~ ^\. ]] || [[ "$domain" =~ \.$ ]] || [[ "$domain" =~ ^- ]] || [[ "$domain" =~ -$ ]]; then
      return 1
    fi
    return 0
  }

  # Interactive domain replacement if not specified via flags
  if [[ -z "$FROM_DOMAIN" ]] || [[ -z "$TO_DOMAIN" ]]; then
    echo "" >&2
    if confirm_yes_no "Replace domain names in database dump?"; then
      # Get source domain with validation
      while true; do
        echo -n "Enter source domain (e.g., www.example.com): " >&2
        read -r FROM_DOMAIN
        if [[ -z "$FROM_DOMAIN" ]]; then
          msg_warning "No source domain specified, skipping domain replacement" >&2
          FROM_DOMAIN=""
          TO_DOMAIN=""
          break
        elif validate_domain "$FROM_DOMAIN"; then
          break
        else
          msg_error "Invalid domain format. Use only letters, numbers, dots, hyphens, and underscores." >&2
          msg_info "Example: www.example.com" >&2
        fi
      done
      
      # Get target domain with validation (if source domain was provided)
      if [[ -n "$FROM_DOMAIN" ]]; then
        local default_target_domain="${DC_ORO_NAME:-unnamed}.docker.local"
        while true; do
          echo -n "Enter target domain [${default_target_domain}]: " >&2
          read -r TO_DOMAIN
          # Use default if empty
          if [[ -z "$TO_DOMAIN" ]]; then
            TO_DOMAIN="$default_target_domain"
            msg_info "Using default target domain: ${TO_DOMAIN}" >&2
            break
          elif validate_domain "$TO_DOMAIN"; then
            break
          else
            msg_error "Invalid domain format. Use only letters, numbers, dots, hyphens, and underscores." >&2
            msg_info "Example: ${default_target_domain}" >&2
          fi
        done
      fi
    fi
  else
    # Validate domains provided via flags
    if ! validate_domain "$FROM_DOMAIN"; then
      msg_error "Invalid source domain format: ${FROM_DOMAIN}" >&2
      msg_info "Use only letters, numbers, dots, hyphens, and underscores." >&2
      FROM_DOMAIN=""
      TO_DOMAIN=""
    elif ! validate_domain "$TO_DOMAIN"; then
      msg_error "Invalid target domain format: ${TO_DOMAIN}" >&2
      msg_info "Use only letters, numbers, dots, hyphens, and underscores." >&2
      FROM_DOMAIN=""
      TO_DOMAIN=""
    fi
  fi

  # Build domain replacement sed command if domains are specified
  DOMAIN_REPLACE_SED=""
  if [[ -n "$FROM_DOMAIN" ]] && [[ -n "$TO_DOMAIN" ]]; then
    # Escape special characters for sed (escape dot, slash, etc.)
    FROM_DOMAIN_ESC=$(printf '%s\n' "$FROM_DOMAIN" | sed 's/[[\.*^$()+?{|]/\\&/g')
    TO_DOMAIN_ESC=$(printf '%s\n' "$TO_DOMAIN" | sed 's/[[\.*^$()+?{|]/\\&/g')
    # Replace domain only in safe contexts:
    # 1. URLs: http://domain or https://domain
    # 2. String values in SQL: 'domain' or "domain" (inside quotes)
    # 3. Domain as standalone value (surrounded by spaces, quotes, or end of line)
    # Avoid replacing in: #!/bin/bash, comments starting with --, etc.
    # Remove lines starting with #!/ (shebang lines) - these are not valid SQL
    # Then skip lines starting with # or ! (comments), then apply domain replacement
    DOMAIN_REPLACE_SED="sed -E '/^[[:space:]]*#!/d' | sed -E '/^[[:space:]]*[#!]/! { s|https://${FROM_DOMAIN_ESC}|https://${TO_DOMAIN_ESC}|g; s|http://${FROM_DOMAIN_ESC}|http://${TO_DOMAIN_ESC}|g; s|${FROM_DOMAIN_ESC}|${TO_DOMAIN_ESC}|g; }' |"
    msg_info "Domain replacement: ${FROM_DOMAIN} -> ${TO_DOMAIN}"
  fi

  # Build import command with explicit values (like export.sh)
  if [[ $DC_ORO_DATABASE_SCHEMA == "pdo_pgsql" ]] || [[ $DC_ORO_DATABASE_SCHEMA == "postgres" ]];then
    # PostgreSQL import command
    if echo ${DB_DUMP_BASENAME} | grep -i 'sql\.gz$' > /dev/null; then
      DB_IMPORT_CMD="zcat /dump.sql.gz | ${DOMAIN_REPLACE_SED} sed -E 's/^[[:space:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn]/CREATE OR REPLACE FUNCTION/g' | sed -E 's/[Oo][Ww][Nn][Ee][Rr]:[[:space:]]*[a-zA-Z0-9_]+/Owner: ${db_user}/g' | sed -E 's/[Oo][Ww][Nn][Ee][Rr][[:space:]]+[Tt][Oo][[:space:]]+[a-zA-Z0-9_]+/OWNER TO ${db_user}/g' | sed -E 's/[Ff][Oo][Rr][[:space:]]+[Rr][Oo][Ll][Ee][[:space:]]+[a-zA-Z0-9_]+/FOR ROLE ${db_user}/g' | sed -E 's/[Tt][Oo][[:space:]]+[a-zA-Z0-9_]+;/TO ${db_user};/g' | sed -E '/^[[:space:]]*[Rr][Ee][Vv][Oo][Kk][Ee][[:space:]]+[Aa][Ll][Ll]/d' | sed -e '/SET transaction_timeout = 0;/d' | sed -E '/[\\]restrict|[\\]unrestrict/d' | PGPASSWORD='${db_password}' psql --set ON_ERROR_STOP=on -h '${db_host}' -p '${db_port}' -U '${db_user}' -d '${db_name}' -1 >/dev/null"
    else
      DB_IMPORT_CMD="cat /dump.sql | ${DOMAIN_REPLACE_SED} sed -E 's/^[[:space:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn]/CREATE OR REPLACE FUNCTION/g' | sed -E 's/[Oo][Ww][Nn][Ee][Rr]:[[:space:]]*[a-zA-Z0-9_]+/Owner: ${db_user}/g' | sed -E 's/[Oo][Ww][Nn][Ee][Rr][[:space:]]+[Tt][Oo][[:space:]]+[a-zA-Z0-9_]+/OWNER TO ${db_user}/g' | sed -E 's/[Ff][Oo][Rr][[:space:]]+[Rr][Oo][Ll][Ee][[:space:]]+[a-zA-Z0-9_]+/FOR ROLE ${db_user}/g' | sed -E 's/[Tt][Oo][[:space:]]+[a-zA-Z0-9_]+;/TO ${db_user};/g' | sed -E '/^[[:space:]]*[Rr][Ee][Vv][Oo][Kk][Ee][[:space:]]+[Aa][Ll][Ll]/d' | sed -e '/SET transaction_timeout = 0;/d' | sed -E '/[\\]restrict|[\\]unrestrict/d' | PGPASSWORD='${db_password}' psql --set ON_ERROR_STOP=on -h '${db_host}' -p '${db_port}' -U '${db_user}' -d '${db_name}' -1 >/dev/null"
    fi
  elif [[ "${DC_ORO_DATABASE_SCHEMA}" == "pdo_mysql" ]] || [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]];then
    # MySQL import command
    if echo ${DB_DUMP_BASENAME} | grep -i 'sql\.gz$' > /dev/null; then
      DB_IMPORT_CMD="zcat /dump.sql.gz | ${DOMAIN_REPLACE_SED} sed -E 's/[Dd][Ee][Ff][Ii][Nn][Ee][Rr][ ]*=[ ]*[^*]*\*/DEFINER=CURRENT_USER \*/' | MYSQL_PWD='${db_password}' mysql -h'${db_host}' -P'${db_port}' -u'${db_user}' '${db_name}'"
    else
      DB_IMPORT_CMD="cat /dump.sql | ${DOMAIN_REPLACE_SED} sed -E 's/[Dd][Ee][Ff][Ii][Nn][Ee][Rr][ ]*=[ ]*[^*]*\*/DEFINER=CURRENT_USER \*/' | MYSQL_PWD='${db_password}' mysql -h'${db_host}' -P'${db_port}' -u'${db_user}' '${db_name}'"
    fi
  else
    msg_error "Unknown database schema: ${DC_ORO_DATABASE_SCHEMA}"
    return 1
  fi

  # Show import details (context information)
  msg_info "From: $DB_DUMP"
  msg_info "File size: $(du -h "$DB_DUMP" | cut -f1)"
  msg_info "Database: ${db_host}:${db_port}/${db_name}"

  # Mount SQL dump file to /dump.sql or /dump.sql.gz in container
  local dump_mount_path="/dump.sql"
  if echo ${DB_DUMP_BASENAME} | grep -i 'sql\.gz$' > /dev/null; then
    dump_mount_path="/dump.sql.gz"
  fi
  
  import_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} run --quiet -i --rm -v \"${DB_DUMP}:${dump_mount_path}\" database-cli bash -c \"$DB_IMPORT_CMD\""
  run_with_spinner "Importing database" "$import_cmd" || return $?

  msg_ok "Database imported successfully"
}

# Run import with parsed arguments
import_database_interactive
exit $?
