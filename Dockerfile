FROM ruby:3.2.0-alpine AS base

# Install runtime dependencies
RUN apk add --no-cache \
    postgresql-client \
    nodejs \
    yarn \
    tzdata \
    gcompat

# Set working directory
WORKDIR /app

# Install bundler
RUN gem install bundler:2.4.0

FROM base AS dependencies

# Install build dependencies
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    postgresql-dev \
    git

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3 && \
    rm -rf /usr/local/bundle/cache/*.gem && \
    find /usr/local/bundle/gems/ -name "*.c" -delete && \
    find /usr/local/bundle/gems/ -name "*.o" -delete

# Copy package.json and install node dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --production

# Remove build dependencies
RUN apk del .build-deps

FROM base AS development

# Install development dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    git \
    vim \
    less

# Copy Gemfile and install all gems (including dev/test)
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3

# Copy package.json and install all node dependencies
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY . .

# Create required directories
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log

# Expose port
EXPOSE 3000

# Start server
CMD ["rails", "server", "-b", "0.0.0.0"]

FROM base AS production

# Copy installed gems from dependencies stage
COPY --from=dependencies /usr/local/bundle /usr/local/bundle

# Copy installed node modules from dependencies stage
COPY --from=dependencies /app/node_modules ./node_modules

# Copy application code
COPY . .

# Compile assets
RUN SECRET_KEY_BASE=dummy rails assets:precompile && \
    rails tailwindcss:build

# Create non-root user
RUN addgroup -g 1000 -S rails && \
    adduser -u 1000 -S rails -G rails && \
    chown -R rails:rails /app

# Create required directories
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log && \
    chown -R rails:rails tmp log

USER rails

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD rails runner "exit 0"

# Expose port
EXPOSE 3000

# Start server
CMD ["rails", "server", "-b", "0.0.0.0"]