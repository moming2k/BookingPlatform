.PHONY: help setup install dev test clean docker-up docker-down docker-rebuild db-reset

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

setup: ## Initial project setup
	./bin/setup

install: ## Install dependencies
	bundle install
	yarn install

dev: ## Start all development services
	@echo "Starting development services..."
	@trap 'kill %1 %2 %3 %4' INT; \
	redis-server & \
	bundle exec sidekiq & \
	rails server & \
	rails tailwindcss:watch & \
	wait

server: ## Start Rails server only
	rails server

sidekiq: ## Start Sidekiq background jobs
	bundle exec sidekiq

tailwind: ## Watch Tailwind CSS changes
	rails tailwindcss:watch

console: ## Open Rails console
	rails console

migrate: ## Run database migrations
	rails db:migrate

seed: ## Seed the database
	rails db:seed

db-reset: ## Reset database (drop, create, migrate, seed)
	rails db:drop db:create db:migrate db:seed

test: ## Run test suite
	bundle exec rspec

lint: ## Run code linters
	bundle exec rubocop

security: ## Run security checks
	bundle exec brakeman

routes: ## Show application routes
	rails routes

docker-up: ## Start Docker containers
	docker-compose up -d

docker-down: ## Stop Docker containers
	docker-compose down

docker-rebuild: ## Rebuild Docker containers
	docker-compose down
	docker-compose build
	docker-compose up -d

docker-logs: ## Show Docker logs
	docker-compose logs -f

docker-shell: ## Open shell in web container
	docker-compose exec web /bin/sh

docker-console: ## Open Rails console in Docker
	docker-compose exec web rails console

clean: ## Clean temporary files and logs
	rails log:clear tmp:clear
	rm -rf node_modules
	rm -rf public/packs
	rm -rf tmp/cache