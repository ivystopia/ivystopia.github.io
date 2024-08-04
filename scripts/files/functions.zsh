# Let me use docker-compose command instead of "docker compose"
function docker-compose() {
    if [[ "$1" == "--version" || "$1" == "-v" ]]; then
        docker compose version
    else
        docker compose "$@"
    fi
}

# Function to change to the docker-compose directory and export environment variables
function prepare_docker_compose() {
    local compose_dir="$HOME/repos/personal/ivystopia.github.io/scripts/files/docker-compose"
    cd "$compose_dir" || return 1
    export $(grep -v '^#' .env | xargs)
}

# Function to run docker-compose up -d from anywhere
function docker-compose-up() {
    prepare_docker_compose || return
    docker-compose up -d
}

# Function to forcibly re-create docker-compose
function docker-compose-recreate() {
    prepare_docker_compose || return
    docker-compose down --remove-orphans && docker-compose up -d --wait
}
