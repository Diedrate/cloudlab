#!/bin/bash

copy_files_to_servers() {
    local file_list
    local server_list
    local destination_dir
    read -e -p "Enter the path to the file containing the list of files to be copied: " file_list
    read -e -p "Enter the path to the file containing the list of servers where files will be copied: " server_list
    read -e -p "Enter the destination directory on the server where files will be copied: " destination_dir

    if [[ ! -f "$file_list" || ! -f "$server_list" ]]; then
        echo "Error: One or both input files do not exist."
        return 1
    fi

    while IFS= read -r file; do
        while IFS= read -r server; do
            if scp "$file" "$server":"$destination_dir"; then
                echo "Successfully copied $file to $server:$destination_dir"
            else
                echo "Failed to copy $file to $server:$destination_dir"
            fi
        done < "$server_list"
    done < "$file_list"
}

import_file_list_to_postgres() {
    local db_name
    local table_name
    local file_list
    local server_list

    read -p "Enter the database name: " db_name
    read -p "Enter the table name where the data will be imported: " table_name
    read -e -p "Enter the path to the file containing the list of files to be imported: " file_list
    read -e -p "Enter the path to the file containing the list of servers where the import will run: " server_list

    if [[ ! -f "$file_list" || ! -f "$server_list" ]]; then
        echo "Error: One or both input files do not exist."
        return 1
    fi

    while IFS= read -r server; do
        echo "Processing server: $server"
        scp "$file_list" "$server:/tmp/import_file_list.txt"
        ssh "$server" "bash -s" <<EOF
        while IFS= read -r file; do
            if [[ ! -f "\$file" ]]; then
                echo "Error: File \$file does not exist on $server. Skipping."
                continue
            fi
            if psql -d "$db_name" -c "\\copy $table_name FROM '\$file' WITH CSV HEADER"; then
                echo "Successfully imported \$file into $db_name.$table_name on $server"
            else
                echo "Failed to import \$file into $db_name.$table_name on $server"
            fi
        done < /tmp/import_file_list.txt
        rm /tmp/import_file_list.txt
EOF
    done < "$server_list"
}

# Check the number of arguments and the specific command provided
if [[ "$#" -eq 1 && "$1" == "copy" ]]; then
    # If the command is 'copy', call the function to copy files to servers
    copy_files_to_servers
elif [[ "$#" -eq 1 && "$1" == "import" ]]; then
    # If the command is 'import', call the function to import files into a PostgreSQL database
    import_file_list_to_postgres
else
    # If neither condition is met, print the usage instructions and exit with an error status
    echo "Usage: $0 copy|import"
    exit 1
fi