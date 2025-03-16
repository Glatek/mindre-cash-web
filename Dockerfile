# Use the official Elixir image as the base image
FROM elixir:1.18.2-alpine AS build

# Install build dependencies
RUN apk add --no-cache build-base git

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./

# Copy config files
COPY config config

# Get dependencies
RUN mix deps.get --only prod

# Copy the rest of the application
COPY lib lib
COPY priv priv

# Compile the application
RUN MIX_ENV=prod mix compile

# Build release
RUN MIX_ENV=prod mix release

# Start a new stage for the runtime
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache libstdc++ ncurses-libs

# Set working directory
WORKDIR /app

# Copy the release from the build stage
COPY --from=build /app/_build/prod/rel/mindre_cash ./

# Set environment variables
ENV PORT=4000 \
    MIX_ENV=prod \
    LANG=C.UTF-8

# Expose the port
EXPOSE 4000

# Start the application
CMD ["bin/mindre_cash", "start"]
