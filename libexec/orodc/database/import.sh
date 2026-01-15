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

# Parse flags for left/right separation
parse_compose_flags "$@"

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
  # Check database schema is configured
  if [[ -z "${DC_ORO_DATABASE_SCHEMA:-}" ]]; then
    msg_error "Database schema not configured"
    exit 1
  fi

  db_name="${DC_ORO_DATABASE_DBNAME:-app_db}"
  
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
  # Docker Compose doesn't support removing specific volumes directly
  # We need to use docker volume rm, but we'll use the volume name that docker compose creates
  if [[ "${DC_ORO_DATABASE_SCHEMA}" == "postgres" ]]; then
    volume_name="${DC_ORO_NAME:-}_postgresql-data"
    # Remove volume - docker compose doesn't have volume rm command, so we use docker directly
    # but with the volume name that docker compose creates
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
    # Wait for PostgreSQL to be ready and the specific database to exist
    # First wait for PostgreSQL server to be ready
    wait_server_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm database-cli bash -c \"until PGPASSWORD=\\\$DC_ORO_DATABASE_PASSWORD psql -h \\\$DC_ORO_DATABASE_HOST -p \\\$DC_ORO_DATABASE_PORT -U \\\$DC_ORO_DATABASE_USER -d postgres -c 'SELECT 1' >/dev/null 2>&1; do sleep 1; done\""
    run_with_spinner "Waiting for PostgreSQL server" "$wait_server_cmd" || exit $?
    # Then wait for the specific database to exist (created by POSTGRES_DB or initdb.d)
    wait_db_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm database-cli bash -c \"until PGPASSWORD=\\\$DC_ORO_DATABASE_PASSWORD psql -h \\\$DC_ORO_DATABASE_HOST -p \\\$DC_ORO_DATABASE_PORT -U \\\$DC_ORO_DATABASE_USER -d ${db_name} -c 'SELECT 1' >/dev/null 2>&1; do sleep 1; done\""
  elif [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]]; then
    # Wait for MySQL to be ready and the specific database to exist
    # First wait for MySQL server to be ready
    wait_server_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm database-cli bash -c \"until MYSQL_PWD=\\\$DC_ORO_DATABASE_PASSWORD mysqladmin -h \\\$DC_ORO_DATABASE_HOST -P \\\$DC_ORO_DATABASE_PORT -u \\\$DC_ORO_DATABASE_USER ping >/dev/null 2>&1; do sleep 1; done\""
    run_with_spinner "Waiting for MySQL server" "$wait_server_cmd" || exit $?
    # Then wait for the specific database to exist (created by MYSQL_DATABASE or initdb.d)
    wait_db_cmd="${DOCKER_COMPOSE_BIN_CMD} run --rm database-cli bash -c \"until MYSQL_PWD=\\\$DC_ORO_DATABASE_PASSWORD mysql -h \\\$DC_ORO_DATABASE_HOST -P \\\$DC_ORO_DATABASE_PORT -u \\\$DC_ORO_DATABASE_USER -e 'USE ${db_name}; SELECT 1' >/dev/null 2>&1; do sleep 1; done\""
  else
    msg_error "Unknown database schema: ${DC_ORO_DATABASE_SCHEMA}"
    exit 1
  fi

  run_with_spinner "Waiting for database '${db_name}'" "$wait_db_cmd" || exit $?
  
  msg_ok "Database container recreated successfully"
  echo "" >&2

  # Use project directory, fallback to current directory
  local project_dir="${DC_ORO_APPDIR:-$PWD}"
  local backup_dir="${project_dir}/var/backup"
  local var_dir="${project_dir}/var"
  local dumps=()
  local dump_files=()

  # Get dumps using list_database_dumps (checks var/backup/ first, then var/)
  while IFS= read -r file; do
    if [[ -n "$file" ]]; then
      dumps+=("$file")
      dump_files+=("$file")
    fi
  done < <(list_database_dumps 2>/dev/null || true)

  local selected_file=""

  if [[ ${#dumps[@]} -gt 0 ]]; then
    echo "" >&2
    msg_header "Available Database Dumps"
    echo "" >&2
    local i=1
    for dump in "${dumps[@]}"; do
      local basename_dump=$(basename "$dump")
      local size=$(du -h "$dump" 2>/dev/null | cut -f1)
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

  if [[ -z "$selected_file" ]] || [[ ! -r "$selected_file" ]]; then
    msg_error "Invalid file: $selected_file"
    return 1
  fi

  # Use existing importdb logic
  DB_DUMP="$selected_file"
  DB_DUMP_BASENAME=$(echo "${DB_DUMP##*/}")

  if [[ $DC_ORO_DATABASE_SCHEMA == "pdo_pgsql" ]] || [[ $DC_ORO_DATABASE_SCHEMA == "postgres" ]];then
    DB_IMPORT_CMD="sed -E 's/[Oo][Ww][Nn][Ee][Rr]:[[:space:]]*[a-zA-Z0-9_]+/Owner: '\$DC_ORO_DATABASE_USER'/g' | sed -E 's/[Oo][Ww][Nn][Ee][Rr][[:space:]]+[Tt][Oo][[:space:]]+[a-zA-Z0-9_]+/OWNER TO '\$DC_ORO_DATABASE_USER'/g' | sed -E 's/[Ff][Oo][Rr][[:space:]]+[Rr][Oo][Ll][Ee][[:space:]]+[a-zA-Z0-9_]+/FOR ROLE '\$DC_ORO_DATABASE_USER'/g' | sed -E 's/[Tt][Oo][[:space:]]+[a-zA-Z0-9_]+;/TO '\$DC_ORO_DATABASE_USER';/g' | sed -E '/^[[:space:]]*[Rr][Ee][Vv][Oo][Kk][Ee][[:space:]]+[Aa][Ll][Ll]/d' | sed -e '/SET transaction_timeout = 0;/d' | sed -E '/[\\]restrict|[\\]unrestrict/d' | PGPASSWORD=\$DC_ORO_DATABASE_PASSWORD psql --set ON_ERROR_STOP=on -h \$DC_ORO_DATABASE_HOST -p \$DC_ORO_DATABASE_PORT -U \$DC_ORO_DATABASE_USER -d \$DC_ORO_DATABASE_DBNAME -1 >/dev/null"
  elif [[ "${DC_ORO_DATABASE_SCHEMA}" == "pdo_mysql" ]] || [[ "${DC_ORO_DATABASE_SCHEMA}" == "mysql" ]];then
    DB_IMPORT_CMD="sed -E 's/[Dd][Ee][Ff][Ii][Nn][Ee][Rr][ ]*=[ ]*[^*]*\*/DEFINER=CURRENT_USER \*/' | MYSQL_PWD=\$DC_ORO_DATABASE_PASSWORD mysql -h\$DC_ORO_DATABASE_HOST -P\$DC_ORO_DATABASE_PORT -u\$DC_ORO_DATABASE_USER \$DC_ORO_DATABASE_DBNAME"
  fi

  if echo ${DB_DUMP_BASENAME} | grep -i 'sql\.gz$' > /dev/null; then
    DB_IMPORT_CMD="zcat ${DB_DUMP_BASENAME} | sed -E 's/^[[:space:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn]/CREATE OR REPLACE FUNCTION/g' | ${DB_IMPORT_CMD}"
  else
    DB_IMPORT_CMD="cat /${DB_DUMP_BASENAME} | sed -E 's/^[[:space:]]*[Cc][Rr][Ee][Aa][Tt][Ee][[:space:]]+[Ff][Uu][Nn][Cc][Tt][Ii][Oo][Nn]/CREATE OR REPLACE FUNCTION/g' | ${DB_IMPORT_CMD}"
  fi

  # Show import details (context information)
  msg_info "From: $DB_DUMP"
  msg_info "File size: $(du -h "$DB_DUMP" | cut -f1)"
  msg_info "Database: $DC_ORO_DATABASE_HOST:$DC_ORO_DATABASE_PORT/$DC_ORO_DATABASE_DBNAME"

  import_cmd="${DOCKER_COMPOSE_BIN_CMD} ${left_flags[*]} ${left_options[*]} run --quiet -i --rm -v \"${DB_DUMP}:/${DB_DUMP_BASENAME}\" database-cli bash -c \"$DB_IMPORT_CMD\""
  run_with_spinner "Importing database" "$import_cmd" || return $?

  msg_ok "Database imported successfully"
}

# Run import
import_database_interactive
exit $?
